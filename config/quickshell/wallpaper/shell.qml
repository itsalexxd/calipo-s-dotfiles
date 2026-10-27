import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Selector de fondos de pantalla (backend: awww)
// Abrir/cerrar:  qs ipc -p ~/.config/quickshell/wallpaper/shell.qml call wallpaper toggle

Scope {
    id: root

    // ================= AJUSTES =================
    readonly property string folder: Quickshell.env("HOME") + "/02_Imagenes/Wallpapers"
    readonly property string fontName: "SF Pro Text"

    // Miniaturas
    readonly property int thumbW: 360
    readonly property int thumbH: 202
    readonly property real selectedScale: 1.25
    readonly property int gap: 48

    // Transición de awww
    readonly property string transition: "grow"     // simple, fade, left, right, top, bottom, wipe, wave, grow, center, outer, any, random
    readonly property string transitionDuration: "0.8"
    readonly property string transitionFps: "60"

    // Generar colores con pywal al elegir (tú ya usas "wal -R" al arrancar)
    readonly property bool useWal: true
    // ===========================================

    property bool open: false

    IpcHandler {
        target: "wallpaper"
        function toggle(): void { root.open = !root.open }
        function show(): void { root.open = true }
        function hide(): void { root.open = false }
    }

    ListModel { id: wallpapers }

    Process {
        id: lister
        running: false
        command: ["sh", "-c",
            "find \"$1\" -maxdepth 1 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \\) | sort",
            "sh", root.folder]
        stdout: SplitParser {
            onRead: line => { if (line !== "") wallpapers.append({ path: line }) }
        }
    }

    function reload() {
        if (lister.running) return
        wallpapers.clear()
        lister.running = true
    }

    onOpenChanged: if (open) reload()

    function apply(path) {
        Quickshell.execDetached([
            "awww", "img", path,
            "--transition-type", root.transition,
            "--transition-duration", root.transitionDuration,
            "--transition-fps", root.transitionFps
        ])
        // Mantener sincronizado el fondo del login (greetd) con este wallpaper
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/quickshell/scripts/wallpaper-state.sh", path])
               if (root.useWal) Quickshell.execDetached(["sh", "-c", "wal -i \"" + path + "\" -n -q && qs ipc call main-bar reloadColors && qs ipc call main-bar reloadColors && qs ipc -p ~/.config/quickshell/launcher/shell.qml call launcher reloadColors && hyprctl reload"])
        root.open = false
    }

    function pick() {
        if (list.currentIndex >= 0 && list.currentIndex < wallpapers.count)
            root.apply(wallpapers.get(list.currentIndex).path)
    }

    PanelWindow {
        id: win
        visible: root.open
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "wallpaper-picker"

        onVisibleChanged: if (visible) list.forceActiveFocus()

        // Fondo oscurecido; clic fuera = cerrar
        Rectangle {
            anchors.fill: parent
            color: "#b3000000"
            MouseArea {
                anchors.fill: parent
                onClicked: root.open = false
            }
        }

        ListView {
            id: list
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.thumbH * root.selectedScale + 90

            model: wallpapers
            orientation: ListView.Horizontal
            spacing: root.gap
            focus: true
            keyNavigationEnabled: true
            keyNavigationWraps: true

            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: width / 2 - root.thumbW / 2
            preferredHighlightEnd: width / 2 + root.thumbW / 2
            highlightMoveDuration: 220

            onCountChanged: if (count > 0 && currentIndex < 0) currentIndex = 0

            Keys.onReturnPressed: root.pick()
            Keys.onEnterPressed: root.pick()
            Keys.onEscapePressed: root.open = false

            delegate: Item {
                id: card
                required property int index
                required property string path
                readonly property bool current: ListView.isCurrentItem

                width: root.thumbW
                height: list.height

                Item {
                    id: thumb
                    anchors.centerIn: parent
                    width: root.thumbW
                    height: root.thumbH
                    scale: card.current ? root.selectedScale : 1.0
                    opacity: card.current ? 1.0 : 0.55
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 160 } }

                    Rectangle { anchors.fill: parent; color: "#1e1e2e" }
                    Image {
                        anchors.fill: parent
                        source: "file://" + card.path
                        sourceSize: Qt.size(root.thumbW * 2, root.thumbH * 2)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.width: card.current ? 3 : 0
                        border.color: "white"
                    }
                }

                Text {
                    visible: card.current
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height / 2 + root.thumbH * root.selectedScale / 2 + 16
                    width: 600
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideMiddle
                    text: card.path.split("/").pop()
                    color: "white"
                    font.family: root.fontName
                    font.pixelSize: 16
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (card.current) root.pick()
                        else list.currentIndex = card.index
                    }
                }
            }
        }

        Text {
            visible: wallpapers.count === 0
            anchors.centerIn: parent
            text: "No hay imágenes en " + root.folder
            color: "white"
            font.family: root.fontName
            font.pixelSize: 20
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 40
            text: (wallpapers.count > 0 ? (list.currentIndex + 1) + " / " + wallpapers.count + "      " : "")
                  + "←  →  mover      Enter  elegir      Esc  cerrar"
            color: "#99ffffff"
            font.family: root.fontName
            font.pixelSize: 15
        }
    }
}
