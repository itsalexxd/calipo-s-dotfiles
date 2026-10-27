import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import QtQuick.Effects

ShellRoot {
    id: root

    // ================= AJUSTES (edita aquí) =================
    readonly property string user: "alexg"
    readonly property string fontName: "SF Pro Text"
    readonly property int avatarSize: 100

    // Fondo dinámico: ruta del wallpaper actual de la sesión de alexg.
    // La actualiza ~/.config/quickshell/scripts/wallpaper-state.sh en cada cambio.
    readonly property string wallpaperStateFile: "/home/alexg/02_Imagenes/Wallpapers/.current-wallpaper"
    readonly property string fallbackWallpaper: "file:///etc/greetd/quickshell/wallpaper"
    property string currentWallpaper: ""
    readonly property string wallpaper: currentWallpaper !== "" ? currentWallpaper : fallbackWallpaper
    readonly property real dimOpacity: 0.35        // 0 = sin oscurecer, 1 = negro

    // Colores
    readonly property color textColor: "#cdd6f4"
    readonly property color mutedColor: "#a6adc8"
    readonly property color accentColor: "#89b4fa"
    readonly property color errorColor: "#f38ba8"

    // Reloj
    readonly property string clockFormat: "hh:mm"                  // "HH:mm:ss", "h:mm AP"...
    readonly property int clockSize: 120
    readonly property int clockWeight: Font.Bold                  // Font.Bold, Font.Normal...
    readonly property string dateFormat: "dddd, d 'de' MMMM"       // "" para ocultar la fecha
    readonly property int dateSize: 22
    readonly property real clockTopFraction: 0.12                  // 0 = arriba del todo, 0.5 = centro
    readonly property bool clockCentered: false                    // true = reloj en el centro de la pantalla

    // Caja de login
    readonly property int fieldWidth: 340
    readonly property int fieldHeight: 54
    readonly property int fieldRadius: 16
    readonly property color fieldColor: "#1fffffff"
    readonly property bool showAvatar: true
    readonly property bool showUserName: true
    readonly property real loginBottomFraction: 0.14
    // =========================================================

    property string typed: ""
    property string password: ""
    property string status: ""
    property bool busy: false

    function submitPassword() {
        if (root.busy || root.typed.length === 0) return
        root.password = root.typed
        root.typed = ""
        root.busy = true
        root.status = ""
        Greetd.createSession(root.user)
    }

    SystemClock { id: clock; precision: SystemClock.Seconds }

    FileView {
        id: wallpaperState
        path: root.wallpaperStateFile
        preload: true
        watchChanges: true
        printErrors: false

        onLoaded: root.updateWallpaper()
        onFileChanged: root.updateWallpaper()
        Component.onCompleted: root.updateWallpaper()
    }

    function updateWallpaper() {
        const p = wallpaperState.text().trim()
        if (p !== "") root.currentWallpaper = "file://" + p
    }

    function runPowerAction(action) {
        if (action === "poweroff") {
            root.status = "Apagando..."
            Quickshell.execDetached(["systemctl", "poweroff"])
        } else if (action === "reboot") {
            root.status = "Reiniciando..."
            Quickshell.execDetached(["systemctl", "reboot"])
        } else if (action === "suspend") {
            root.status = "Suspendiendo..."
            Quickshell.execDetached(["systemctl", "suspend"])
        }
    }

    Connections {
        target: Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) Greetd.respond(root.password)
        }
        function onAuthFailure(message) {
            root.status = "Contraseña incorrecta"
            root.password = ""
            root.busy = false
            shake.restart()
        }
        function onReadyToLaunch() {
            root.password = ""
            Greetd.launch(["/usr/local/bin/start-hyprland-quiet"], [], true)
        }
    }

    FloatingWindow {
        visible: true
        color: "#11111b"

        Item {
            anchors.fill: parent
            focus: true

            Image {
                id: greeterBg
                anchors.fill: parent
                source: root.wallpaper
                fillMode: Image.PreserveAspectCrop
                cache: false
                visible: false
            }
            // Fondo desenfocado, igual que la pantalla de bloqueo.
            MultiEffect {
                anchors.fill: parent
                source: greeterBg
                autoPaddingEnabled: false
                blurEnabled: true
                blurMax: 64
                blur: 1.0
            }
            Rectangle { anchors.fill: parent; color: "black"; opacity: root.dimOpacity }

            Keys.onPressed: event => {
                if (root.busy) return
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.submitPassword()
                } else if (event.key === Qt.Key_Backspace) {
                    root.typed = root.typed.slice(0, -1)
                } else if (event.text.length > 0 && event.key !== Qt.Key_Escape) {
                    root.status = ""
                    root.typed += event.text
                }
            }

            // Reloj y fecha
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.clockCentered ? (parent.height - height) / 2
                                      : parent.height * root.clockTopFraction
                spacing: 4

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(clock.date, root.clockFormat)
                    color: root.textColor
                    font.family: root.fontName
                    font.pixelSize: root.clockSize
                    font.weight: root.clockWeight
                }
                Text {
                    visible: root.dateFormat !== ""
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.locale("es_ES").toString(clock.date, root.dateFormat)
                    color: root.mutedColor
                    font.family: root.fontName
                    font.pixelSize: root.dateSize
                }
            }

            // Login
            Column {
                id: loginBox
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height * root.loginBottomFraction
                spacing: 18

                SequentialAnimation {
                    id: shake
                    PropertyAnimation { target: loginBox; property: "anchors.horizontalCenterOffset"; to: -14; duration: 50 }
                    PropertyAnimation { target: loginBox; property: "anchors.horizontalCenterOffset"; to: 14;  duration: 80 }
                    PropertyAnimation { target: loginBox; property: "anchors.horizontalCenterOffset"; to: -8;  duration: 70 }
                    PropertyAnimation { target: loginBox; property: "anchors.horizontalCenterOffset"; to: 0;   duration: 50 }
                }

                Item {
                    visible: root.showAvatar
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.avatarSize
                    height: root.avatarSize

                    Image {
                        id: avatarImg
                        anchors.fill: parent
                        source: "file:///etc/greetd/quickshell/avatar.png"
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(root.avatarSize * 3, root.avatarSize * 3)
                        visible: false
                    }

                    Rectangle {
                        id: avatarMask
                        anchors.fill: parent
                        radius: width / 2
                        visible: false
                        layer.enabled: true
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: avatarImg
                        maskEnabled: true
                        maskSource: avatarMask
                    }
                }

                Text {
                    visible: root.showUserName
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.user
                    color: root.textColor
                    font.family: root.fontName
                    font.pixelSize: 24
                }

                Rectangle {
                    id: passwordField
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.fieldWidth; height: root.fieldHeight; radius: root.fieldRadius
                    color: "transparent"
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: "#3dffffff" }
                        GradientStop { position: 1.0; color: root.fieldColor }
                    }
                    border.width: 1
                    border.color: root.status !== "" ? root.errorColor
                                : root.typed.length > 0 ? root.accentColor : "#66ffffff"
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        visible: root.typed.length === 0 && !root.busy
                        text: "Introduce la contraseña"
                        color: "#e6ffffff"
                        font.family: root.fontName
                        font.pixelSize: 17
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: root.busy
                        text: "Entrando..."
                        color: "#f2ffffff"
                        font.family: root.fontName
                        font.pixelSize: 17
                    }
                    Row {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: root.typed.length > 0 && !root.busy ? -18 : 0
                        spacing: 7
                        visible: !root.busy
                        Repeater {
                            model: Math.min(root.typed.length, 16)
                            Rectangle { width: 10; height: 10; radius: 5; color: "#ffffff" }
                        }
                    }

                    Rectangle {
                        id: submitButton
                        width: 34; height: 34; radius: 17
                        anchors.right: parent.right
                        anchors.rightMargin: 9
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !root.busy
                        opacity: root.typed.length > 0 ? 1.0 : 0.45
                        color: submitMouse.containsMouse && root.typed.length > 0 ? "#33ffffff" : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on opacity { NumberAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: "→"
                            color: "#ffffff"
                            font.family: root.fontName
                            font.pixelSize: 20
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            id: submitMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: root.typed.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: root.submitPassword()
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 18

                    Repeater {
                        model: [
                            { icon: "⏻", label: "Apagar", action: "poweroff" },
                            { icon: "󰜉", label: "Reiniciar", action: "reboot" },
                            { icon: "󰤄", label: "Suspender", action: "suspend" }
                        ]

                        delegate: Item {
                            width: 48
                            height: 48

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: powerMouse.containsMouse ? "#1affffff" : "transparent"
                                border.width: 1.5
                                border.color: powerMouse.containsMouse ? "#ffffff" : "#ccffffff"
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Behavior on border.color { ColorAnimation { duration: 120 } }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.icon
                                color: "white"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 22
                            }

                            MouseArea {
                                id: powerMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.runPowerAction(modelData.action)
                            }
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 20
                    text: root.status
                    color: root.errorColor
                    font.family: root.fontName
                    font.pixelSize: 16
                }
            }
        }
    }
}
