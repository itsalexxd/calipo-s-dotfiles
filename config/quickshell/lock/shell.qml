import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

Scope {
    id: root

    // ===== AJUSTES =====
    readonly property real blurAmount: 1.0       // 0 a 1
    readonly property real dim: -0.15            // brillo del fondo (negativo = más oscuro)
    readonly property int clockSize: 120
    readonly property string clockFormat: "hh:mm"
    readonly property string fontName: "SF Pro Text"
    readonly property int boxWidth: 340
    readonly property int boxHeight: 54
    readonly property int boxRadius: 16
    readonly property color boxColor: "#1fffffff"

    // Fondo: el mismo wallpaper que el escritorio. Se lee del archivo que
    // actualiza ~/.config/quickshell/scripts/wallpaper-state.sh.
    readonly property string wallpaperStateFile: "/home/alexg/02_Imagenes/Wallpapers/.current-wallpaper"
    readonly property string fallbackWallpaper: "file:///etc/greetd/quickshell/wallpaper"
    property string currentWallpaper: ""
    readonly property string lockWallpaper: currentWallpaper !== "" ? currentWallpaper : fallbackWallpaper
    // ===================

    property string typed: ""
    property bool failed: false

    IpcHandler {
        target: "lock"
        function lock(): void { sessionLock.locked = true }
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

    function submitPassword() {
        if (pam.active || root.typed.length === 0) return
        pam.start()
    }

    PamContext {
        id: pam
        config: "login"
        onResponseRequiredChanged: if (responseRequired) respond(root.typed)
        onCompleted: result => {
            if (result === PamResult.Success) {
                root.typed = ""
                root.failed = false
                sessionLock.locked = false
            } else {
                root.failed = true
                root.typed = ""
            }
        }
    }

    WlSessionLock {
        id: sessionLock
        // Arranca desbloqueado: el proceso se lanza al iniciar sesión y solo
        // debe bloquear cuando se pide por IPC (atajo Super+L o menú).
        locked: false

        WlSessionLockSurface {
            color: "black"

            // Fondo: wallpaper actual desenfocado. No captura el escritorio,
            // así funciona bien desde el arranque y no muestra ventanas.
            Image {
                id: lockBg
                anchors.fill: parent
                source: root.lockWallpaper
                fillMode: Image.PreserveAspectCrop
                cache: false
                visible: false
            }
            MultiEffect {
                anchors.fill: parent
                source: lockBg
                autoPaddingEnabled: false
                blurEnabled: true
                blurMax: 64
                blur: root.blurAmount
                brightness: root.dim
            }

            Item {
                anchors.fill: parent
                focus: true

                Keys.onPressed: event => {
                    if (pam.active) return
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.submitPassword()
                    } else if (event.key === Qt.Key_Backspace) {
                        root.typed = root.typed.slice(0, -1)
                    } else if (event.key === Qt.Key_Escape) {
                        root.typed = ""
                    } else if (event.text.length > 0) {
                        root.failed = false
                        root.typed += event.text
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 28

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatTime(clock.date, root.clockFormat)
                        color: "white"
                        font.family: root.fontName
                        font.pixelSize: root.clockSize
                        font.weight: Font.Bold
                    }

                    Rectangle {
                        id: passwordField
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.boxWidth
                        height: root.boxHeight
                        radius: root.boxRadius
                        color: "transparent"
                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop { position: 0.0; color: "#3dffffff" }
                            GradientStop { position: 1.0; color: root.boxColor }
                        }
                        border.width: 1
                        border.color: root.failed ? "#f38ba8"
                                    : root.typed.length > 0 ? "#89b4fa" : "#66ffffff"
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            visible: root.typed.length === 0
                            text: root.failed ? "Contraseña incorrecta" : "Introduce la contraseña"
                            color: root.failed ? "#f38ba8" : "#e6ffffff"
                            font.family: root.fontName
                            font.pixelSize: 17
                        }
                        Row {
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: root.typed.length > 0 && !pam.active ? -18 : 0
                            spacing: 7
                            Repeater {
                                model: Math.min(root.typed.length, 16)
                                Rectangle { width: 10; height: 10; radius: 5; color: "white" }
                            }
                        }

                        Rectangle {
                            id: submitButton
                            width: 34; height: 34; radius: 17
                            anchors.right: parent.right
                            anchors.rightMargin: 9
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !pam.active
                            opacity: root.typed.length > 0 ? 1.0 : 0.45
                            color: submitMouse.containsMouse && root.typed.length > 0 ? "#33ffffff" : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on opacity { NumberAnimation { duration: 120 } }

                            Text {
                                anchors.centerIn: parent
                                text: "→"
                                color: "white"
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
                }
            }
        }
    }
}
