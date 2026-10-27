import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.UPower
import Quickshell.Io
import QtQuick.Controls.Basic
import Quickshell.Bluetooth
import Quickshell.Services.Notifications
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

ShellRoot {

    // ==========================================
    // COMPONENTES: DESTELLO BLANCO AL PASAR EL RATON
    // ==========================================
    // Las LETRAS e ICONOS del modulo se aclaran a blanco puro y dan un
    // pequeño punto de escala al pasar el raton por encima.
    // No dibuja ningun recuadro ni cuadrado de fondo.
    component BloomRow: Row {
        id: bloomRowRoot
        property bool lit: false
        // "destello" blanco: las letras/iconos se aclaran y dan un punto de luz
        // (sin recuadro ni cuadrado de fondo)
        transformOrigin: Item.Center
        opacity: lit ? 1.0 : 0.82
        scale: lit ? 1.06 : 1.0
        Behavior on opacity { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
    }

    component BloomText: Text {
        id: bloomTextRoot
        property bool lit: false
        // "destello" blanco: las letras/iconos se aclaran y dan un punto de luz
        // (sin recuadro ni cuadrado de fondo)
        transformOrigin: Item.Center
        opacity: lit ? 1.0 : 0.82
        scale: lit ? 1.06 : 1.0
        Behavior on opacity { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
    }

    // ==========================================
    // CONTROL MULTIMEDIA (MPRIS)
    // ==========================================
    // Compartido por el modulo de Spotify de la barra y por las teclas
    // multimedia (via `qs ipc call media ...`). No necesita playerctl.
    QtObject {
        id: mediaControl

        readonly property var players: Mpris.players.values

        // Reproductor de Spotify, si la app esta abierta (aunque este en pausa).
        function spotifyPlayer() {
            for (var i = 0; i < players.length; i++) {
                var p = players[i];
                var id = ((p.identity || "") + " " + (p.desktopEntry || "")).toLowerCase();
                if (id.indexOf("spotify") !== -1) return p;
            }
            return null;
        }

        // Para las teclas: lo que este sonando; si nada suena, Spotify abierto;
        // y si no, el primer reproductor disponible.
        function activePlayer() {
            var sp = spotifyPlayer();
            if (sp && sp.isPlaying) return sp;
            for (var i = 0; i < players.length; i++) {
                if (players[i].isPlaying) return players[i];
            }
            if (sp) return sp;
            return players.length > 0 ? players[0] : null;
        }

        function playPause() {
            var p = activePlayer();
            if (p && p.canTogglePlaying) p.togglePlaying();
        }

        function nextTrack() {
            var p = activePlayer();
            if (p && p.canGoNext) p.next();
        }

        function previousTrack() {
            var p = activePlayer();
            if (p && p.canGoPrevious) p.previous();
        }

        function stopPlayback() {
            var p = activePlayer();
            if (p) p.stop();
        }
    }

    // Hyprland llama aqui desde las teclas multimedia.
    IpcHandler {
        target: "media"

        function playPause(): void { mediaControl.playPause() }
        function nextTrack(): void { mediaControl.nextTrack() }
        function previousTrack(): void { mediaControl.previousTrack() }
        function stopPlayback(): void { mediaControl.stopPlayback() }

        // Para comprobar desde la terminal: qs ipc call media status
        function status(): string {
            var p = mediaControl.activePlayer();
            if (!p) return "none";
            return (p.isPlaying ? "playing" : "paused") + " | " + (p.trackTitle || "?") + " | " + (p.trackArtist || "?");
        }
    }

    // ==========================================
    // 0. SERVIDOR DE NOTIFICACIONES (reemplaza a swaync)
    // ==========================================
    NotificationServer {
        id: notifServer
        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true

        onNotification: notification => {
            notification.tracked = true;
            if (!ccModule.dnd) {
                notifModule.toast(notification);
                if (ccModule.notificationSound) {
                    Quickshell.execDetached(["sh", "-c", "command -v canberra-gtk-play >/dev/null 2>&1 && canberra-gtk-play -i message-new-instant >/dev/null 2>&1 || command -v paplay >/dev/null 2>&1 && paplay /usr/share/sounds/freedesktop/stereo/message.oga >/dev/null 2>&1 || command -v pw-play >/dev/null 2>&1 && pw-play /usr/share/sounds/freedesktop/stereo/message.oga >/dev/null 2>&1 || true"]);
                }
            }
        }
    }
    
    // ==========================================
    // 1. BARRA PRINCIPAL
    // ==========================================S
    // (centro de control + notificaciones añadidos abajo, zona derecha)
    PanelWindow {
        id: mainBar
        anchors { top: true; left: true; right: true }
        implicitHeight: 28
        // Barra translúcida tipo macOS (el blur lo aplica Hyprland por
        // namespace desde hyprland.lua).
        color: "#26000000"
        WlrLayershell.namespace: "quickshell-bar"
        // color: "#991e1e2e";
    
        // ===== INICIO BLOQUE IZQUIERDA: POWER + WORKSPACES + CLIENTES ===== 
        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 10
            spacing: 12

            // --- 1. Icono de Power ---
            Item {
                id: powerModule
                width: 24
                height: 20
                anchors.verticalCenter: parent.verticalCenter

                property var powerActions: [
                    { label: "Bloquear",      icon: "󰌾", command: ["sh", "-c", "qs -p /home/alexg/.config/quickshell/lock/shell.qml -d -n; sleep 0.3; qs ipc -p /home/alexg/.config/quickshell/lock/shell.qml call lock lock"] },
                    { label: "Suspender",     icon: "󰤄", command: ["systemctl", "suspend"] },
                    { label: "Reiniciar",     icon: "󰜉", command: ["systemctl", "reboot"] },
                    { label: "Apagar",        icon: "⏻", command: ["systemctl", "poweroff"] }
                ]

                function closeMenu() {
                    powerPopup.visible = false;
                    powerFocusGrab.active = false;
                }

                function runAction(cmd) {
                    Quickshell.execDetached(cmd);
                    powerModule.closeMenu();
                }

                BloomText {
                    id: powerText
                    lit: powerMouseArea.containsMouse
                    anchors.centerIn: parent
                    text: "󰣇"
                    color: "#ffffff"
                    font.pixelSize: 18
                    font.family: "SF Pro Text"
                    font.bold: true
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                MouseArea {
                    id: powerMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        powerPopup.visible = !powerPopup.visible;
                        if (powerPopup.visible) powerFocusGrab.active = true;
                    }
                }

                PopupWindow {
                    id: powerPopup
                    visible: false
                    color: "transparent"
                    implicitWidth: 170
                    implicitHeight: powerColumn.implicitHeight + 16

                    anchor {
                        item: powerModule
                        edges: Edges.Bottom | Edges.Left
                        gravity: Edges.Bottom | Edges.Right
                        adjustment: PopupAdjustment.None
                        margins.bottom: 4
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: "#2c2c34"
                        border.color: "#45475a"
                        border.width: 1

                        Column {
                            id: powerColumn
                            anchors.centerIn: parent
                            width: parent.width - 16
                            spacing: 4

                            Repeater {
                                model: powerModule.powerActions

                                Rectangle {
                                    width: powerColumn.width
                                    height: 28
                                    radius: 6
                                    color: btnMouse.containsMouse ? "#45475a" : "transparent"
                                    Behavior on color { ColorAnimation { duration: 100 } }

                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8
                                        spacing: 8

                                        Text {
                                            text: modelData.icon
                                            color: "#ffffff"
                                            font.family: "SF Pro Text"
                                            font.pixelSize: 14
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: modelData.label
                                            color: "#cdd6f4"
                                            font.pixelSize: 13
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        id: btnMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: powerModule.runAction(modelData.command)
                                    }
                                }
                            }
                        }
                    }

                    HyprlandFocusGrab {
                        id: powerFocusGrab
                        windows: [ powerPopup ]
                        onCleared: powerPopup.visible = false
                    }
                }
            }

            // --- 2. Workspaces (1-5 fijos, del 6 en adelante dinámicos) ---
            Item {
                id: workspacesModule
                width: {
                    let extraCount = 0;
                    if (Hyprland.workspaces) {
                        for (var i = 0; i < Hyprland.workspaces.length; i++) {
                            let n = parseInt(Hyprland.workspaces[i].name);
                            if (!isNaN(n) && n > 5) extraCount++;
                        }
                    }
                    if (Hyprland.focusedWorkspace) {
                        let fn = parseInt(Hyprland.focusedWorkspace.name);
                        if (!isNaN(fn) && fn > 5 && extraCount === 0) extraCount = 1;
                    }
                    return (5 + extraCount) * 38;
                }
                height: 20
                anchors.verticalCenter: parent.verticalCenter

                property var kanjiNumbers: ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]

                function toKanji(n) {
                    if (n >= 0 && n < workspacesModule.kanjiNumbers.length) return workspacesModule.kanjiNumbers[n];
                    return n.toString();
                }

                Repeater {
                    model: 5
                    Rectangle {
                        property int wsNum: index + 1
                        property bool isActive: Hyprland.focusedWorkspace && parseInt(Hyprland.focusedWorkspace.name) === wsNum

                        x: index * 38
                        width: 32
                        height: 20
                        radius: 0
                        color: isActive ? "#4dffffff" : "#22ffffff"

                        Behavior on color { ColorAnimation { duration: 200 } }

                        BloomText {
                            id: wsText
                            lit: wsChipMouse.containsMouse
                            anchors.centerIn: parent
                            text: workspacesModule.toKanji(wsNum)
                            color: isActive ? '#ffffff' : "#cdd6f4"
                            font.pixelSize: 14
                            font.bold: true
                            font.family: "SF Pro Text"
                        }

                        MouseArea {
                            id: wsChipMouse
                            hoverEnabled: true
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Hyprland.dispatch("workspace " + wsNum)
                        }
                    }
                }

                Repeater {
                    model: Hyprland.workspaces
                    delegate: Loader {
                        id: dynLoader
                        property var modelData: model.modelData
                        property int wsNum: parseInt(modelData.name)
                        
                        active: !isNaN(wsNum) && wsNum > 5
                        visible: active

                        sourceComponent: Rectangle {
                            width: 32
                            height: 20
                            radius: 0
                            x: {
                                let indexOffset = 5;
                                if (Hyprland.workspaces) {
                                    let counted = 0;
                                    for (var j = 0; j < Hyprland.workspaces.length; j++) {
                                        let n = parseInt(Hyprland.workspaces[j].name);
                                        if (!isNaN(n) && n > 5) {
                                            if (n === wsNum) break;
                                            counted++;
                                        }
                                    }
                                    indexOffset += counted;
                                }
                                return indexOffset * 38;
                            }
                            z: modelData.active ? 100 : wsNum
                            color: modelData.active ? "#4dffffff" : "#22ffffff"

                            Behavior on color { ColorAnimation { duration: 200 } }
                            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutExpo } }

                            BloomText {
                                id: dynWsText
                                lit: dynWsChipMouse.containsMouse
                                anchors.centerIn: parent
                                text: workspacesModule.toKanji(wsNum)
                                color: modelData.active ? '#ffffff' : "#cdd6f4"
                                font.bold: true
                                font.family: "SF Pro Text"
                            }

                            MouseArea {
                                id: dynWsChipMouse
                                hoverEnabled: true
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: modelData.activate()
                            }
                        }
                    }
                }
            }

            // --- 3. Aplicación activa (estilo macOS) ---
            // Muestra el nombre de la app enfocada y, si existe, el título de
            // la ventana, como la barra de menús de macOS.
            Item {
                id: activeAppModule
                anchors.verticalCenter: parent.verticalCenter
                height: 20
                width: visible ? activeAppRow.width : 0
                visible: activeAppModule.appName !== ""

                function displayName(cls) {
                    let s = (cls || "").trim();
                    if (s === "") return "";
                    let lower = s.toLowerCase();
                    if (lower.indexOf("kitty") !== -1) return "Terminal";
                    if (lower.indexOf("nautilus") !== -1 || lower.indexOf("thunar") !== -1) return "Archivos";
                    if (lower.indexOf("brave") !== -1) return "Brave";
                    if (lower.indexOf("chromium") !== -1) return "Chromium";
                    if (lower.indexOf("firefox") !== -1) return "Firefox";
                    if (lower.indexOf("code") !== -1) return "Code";
                    if (lower.indexOf("discord") !== -1) return "Discord";
                    if (lower.indexOf("spotify") !== -1) return "Spotify";
                    if (lower.indexOf("obsidian") !== -1) return "Obsidian";
                    if (lower.indexOf("steam") !== -1) return "Steam";
                    // Fallback: primera letra en mayúscula.
                    return s.charAt(0).toUpperCase() + s.slice(1);
                }

                property string appName: {
                    let t = Hyprland.activeToplevel;
                    if (!t) return "";
                    let cls = "";
                    if (t.lastIpcObject && t.lastIpcObject.class) cls = t.lastIpcObject.class;
                    else if (t.wayland && t.wayland.appId) cls = t.wayland.appId;
                    return displayName(cls);
                }

                property string windowTitle: {
                    let t = Hyprland.activeToplevel;
                    return t && t.title ? t.title : "";
                }

                Row {
                    id: activeAppRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        text: activeAppModule.appName
                        color: "#ffffff"
                        font.family: "SF Pro Text"
                        font.pixelSize: 14
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        visible: activeAppModule.windowTitle !== ""
                        text: "·"
                        color: "#80ffffff"
                        font.family: "SF Pro Text"
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        visible: activeAppModule.windowTitle !== ""
                        width: Math.min(implicitWidth, 260)
                        text: activeAppModule.windowTitle
                        elide: Text.ElideRight
                        color: "#d9ffffff"
                        font.family: "SF Pro Text"
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
        // ===== FIN BLOQUE IZQUIERDA =====

        // --- CENTRO: RELOJ Y CLIMA ---
        Row {
            anchors.centerIn: parent
            spacing: 15 // Espacio entre el reloj y el clima

            // --- Módulo de Fecha y Calendario ---
            Item {
                id: dateModule
                width: dateRow.width
                height: 20
                anchors.verticalCenter: parent.verticalCenter

                property date today: new Date()
                property int currentMonth: today.getMonth()
                property int currentYear: today.getFullYear()

                function getMonthName(m) {
                    const months = ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"];
                    return months[m];
                }

                function getFormattedDate() {
                    const days = ["dom", "lun", "mar", "mié", "jue", "vie", "sáb"];
                    const months = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"];
                    return days[today.getDay()] + " " + today.getDate() + " " + months[today.getMonth()];
                }

                // Genera la cuadrícula de días para el mes actual
                function updateCalendar() {
                    calendarModel.clear();
                    let firstDay = new Date(currentYear, currentMonth, 1).getDay();
                    let offset = (firstDay === 0) ? 6 : firstDay - 1; // Ajuste para que la semana empiece en Lunes (0)
                    let daysInMonth = new Date(currentYear, currentMonth + 1, 0).getDate();

                    // Rellenar espacios vacíos antes del día 1
                    for (let i = 0; i < offset; i++) {
                        calendarModel.append({ dayText: "", isToday: false });
                    }
                    // Rellenar los días del mes
                    for (let d = 1; d <= daysInMonth; d++) {
                        let isT = (d === today.getDate() && currentMonth === today.getMonth() && currentYear === today.getFullYear());
                        calendarModel.append({ dayText: d.toString(), isToday: isT });
                    }
                }

                Component.onCompleted: updateCalendar()
                onCurrentMonthChanged: updateCalendar()
                onCurrentYearChanged: updateCalendar()

                // Actualiza la fecha a la medianoche
                Timer {
                    interval: 60000 
                    running: true
                    repeat: true
                    onTriggered: {
                        let d = new Date();
                        if (d.getDate() !== dateModule.today.getDate()) {
                            dateModule.today = d;
                            dateModule.updateCalendar();
                        }
                    }
                }

                // Texto en la barra (Fecha)
                BloomRow {
                    id: dateRow
                    lit: dateMouse.containsMouse
                    spacing: 5
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        text: dateModule.getFormattedDate()
                        color: "#ffffff"
                        font.family: "SF Pro Text"
                        font.pixelSize: 15
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: dateMouse
                    hoverEnabled: true
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        calendarPopup.visible = !calendarPopup.visible;
                        if (calendarPopup.visible) {
                            // Al abrir, vuelve a mostrar el mes actual por defecto
                            dateModule.currentMonth = dateModule.today.getMonth();
                            dateModule.currentYear = dateModule.today.getFullYear();
                            calendarFocusGrab.active = true;
                        }
                    }
                }

                // Popup interactivo del calendario
                PopupWindow {
                    id: calendarPopup
                    visible: false
                    color: "transparent"
                    implicitWidth: 260
                    implicitHeight: 280

                    anchor {
                        item: dateModule
                        edges: Edges.Bottom
                        gravity: Edges.Bottom
                        adjustment: PopupAdjustment.None
                        margins.bottom: 4
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: "#2c2c34"
                        border.color: "#45475a"
                        border.width: 1

                        Column {
                            anchors.fill: parent
                            anchors.margins: 15
                            spacing: 12

                            // Cabecera (Flechas y Mes/Año)
                            Item {
                                width: parent.width
                                height: 30

                                Rectangle {
                                    width: 24; height: 24; radius: 4; color: prevMouse.containsMouse ? "#45475a" : "transparent"
                                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    
                                    Text { text: ""; font.family: "JetBrainsMono Nerd Font"; color: "#ffffff"; font.pixelSize: 12; anchors.centerIn: parent }
                                    
                                    MouseArea { 
                                        id: prevMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (dateModule.currentMonth === 0) { dateModule.currentMonth = 11; dateModule.currentYear--; }
                                            else { dateModule.currentMonth--; }
                                        }
                                    }
                                }

                                Text {
                                    text: dateModule.getMonthName(dateModule.currentMonth) + " " + dateModule.currentYear
                                    color: "#ffffff"
                                    font.bold: true
                                    font.pixelSize: 14
                                    anchors.centerIn: parent
                                }

                                Rectangle {
                                    width: 24; height: 24; radius: 4; color: nextMouse.containsMouse ? "#45475a" : "transparent"
                                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                    Behavior on color { ColorAnimation { duration: 100 } }

                                    Text { text: ""; font.family: "JetBrainsMono Nerd Font"; color: "#ffffff"; font.pixelSize: 12; anchors.centerIn: parent }
                                    
                                    MouseArea { 
                                        id: nextMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (dateModule.currentMonth === 11) { dateModule.currentMonth = 0; dateModule.currentYear++; }
                                            else { dateModule.currentMonth++; }
                                        }
                                    }
                                }
                            }

                            // Días de la semana
                            Grid {
                                columns: 7
                                spacing: 5
                                Repeater {
                                    model: ["Lu", "Ma", "Mi", "Ju", "Vi", "Sa", "Do"]
                                    Text {
                                        width: 28; height: 20
                                        text: modelData
                                        color: "#cdd6f4"
                                        font.pixelSize: 12
                                        font.bold: true
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }

                            // Cuadrícula de días
                            ListModel { id: calendarModel }
                            Grid {
                                columns: 7
                                spacing: 5
                                Repeater {
                                    model: calendarModel
                                    Rectangle {
                                        width: 28; height: 28
                                        radius: 14
                                        color: model.isToday ? "#1747a9" : "transparent"
                                        
                                        Text {
                                            text: model.dayText
                                            color: model.isToday ? "#ffffff" : "#cdd6f4"
                                            font.pixelSize: 13
                                            anchors.centerIn: parent
                                        }
                                    }
                                }
                            }
                        }
                    }

                    HyprlandFocusGrab {
                        id: calendarFocusGrab
                        windows: [ calendarPopup ]
                        onCleared: calendarPopup.visible = false
                    }
                }
            }

            // Reloj (Tu codigo original adaptado al Row)
            BloomText {
                id: clockText
                MouseArea {
                    id: clockMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }
                lit: clockMouse.containsMouse
                color: "#ffffff"
                font.pixelSize: 15
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
                function updateTime() { text = Qt.formatTime(new Date(), "hh:mm") }
                Component.onCompleted: updateTime()
                Timer { interval: 1000; running: true; repeat: true; onTriggered: parent.updateTime() }
            }

            // Clima (Actualiza con la IP)
            BloomRow {
                lit: weatherIconMouse.containsMouse || weatherTextMouse.containsMouse
                id: weatherModule // ID para referenciar las funciones desde dentro
                spacing: 5
                anchors.verticalCenter: parent.verticalCenter
                
                Text {
                    id: weatherIcon
                    MouseArea {
                        id: weatherIconMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }
                    text: "" // Icono por defecto al cargar
                    color: "#ffffff"
                    font.pixelSize: 15
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    id: weatherText
                    MouseArea {
                        id: weatherTextMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }
                    text: "..."
                    color: "#ffffff"
                    font.pixelSize: 15
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }

                function updateWeather() {
                    var req = new XMLHttpRequest();
                    // %C = Condicion textual (ej. Clear, Rain), %t = Temperatura
                    // Usamos "|" para separar ambos valores y procesarlos facil
                    req.open("GET", "http://wttr.in/?format=%C|%t");
                    req.setRequestHeader("User-Agent", "curl/7.81.0");
                    
                    req.onreadystatechange = function() {
                        if (req.readyState === XMLHttpRequest.DONE) {
                            if (req.status === 200) {
                                var parts = req.responseText.trim().split("|");
                                if (parts.length >= 2) {
                                    var condition = parts[0].toLowerCase();
                                    // Quitamos el signo "+" de la temperatura si lo trae por estetica
                                    weatherText.text = parts[1].replace("+", ""); 
                                    
                                    // Cambiamos el icono segun el texto de la condicion
                                    if (condition.indexOf("clear") !== -1 || condition.indexOf("sunny") !== -1) weatherIcon.text = ""; // Sol
                                    else if (condition.indexOf("rain") !== -1 || condition.indexOf("drizzle") !== -1 || condition.indexOf("shower") !== -1) weatherIcon.text = ""; // Lluvia
                                    else if (condition.indexOf("snow") !== -1 || condition.indexOf("ice") !== -1) weatherIcon.text = ""; // Nieve
                                    else if (condition.indexOf("thunder") !== -1 || condition.indexOf("storm") !== -1) weatherIcon.text = ""; // Tormenta
                                    else if (condition.indexOf("fog") !== -1 || condition.indexOf("mist") !== -1) weatherIcon.text = ""; // Niebla
                                    else weatherIcon.text = ""; // Nublado o generico
                                }
                            }
                        }
                    }
                    req.send();
                }

                Component.onCompleted: weatherModule.updateWeather()

                Timer {
                    interval: 1800000 // Actualiza cada 30 min
                    running: true
                    repeat: true
                    onTriggered: weatherModule.updateWeather()
                }
            }
        }

        // --- DERECHA: MODULOS DE SISTEMA ---
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 10
            spacing: 15 // Espacio entre los diferentes modulos

            
            // --- Módulo de Spotify (solo aparece si Spotify está abierto) ---
            // Carátula + título de la canción. Los datos vienen de MPRIS.
            Item {
                id: spotifyModule
                width: spotifyRow.width
                height: 20
                anchors.verticalCenter: parent.verticalCenter
                visible: spotifyModule.player !== null

                readonly property var player: mediaControl.spotifyPlayer()
                readonly property bool artReady: artImage.status === Image.Ready

                // --- Fondo animado: la carátula muy difuminada, derivando
                // despacio y "respirando" mientras suena la canción. ---
                Item {
                    id: spotifyGlow
                    visible: spotifyModule.artReady
                    anchors.fill: parent
                    anchors.leftMargin: -6
                    anchors.rightMargin: -7
                    anchors.topMargin: -4
                    anchors.bottomMargin: -4
                    clip: true

                    // Esquinas redondeadas del fondo (misma técnica que la carátula).
                    Rectangle {
                        id: glowMask
                        anchors.fill: parent
                        radius: 9
                        color: "black"
                        visible: false
                        layer.enabled: true
                    }

                    Item {
                        anchors.fill: parent
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: glowMask
                            blurEnabled: true
                            blur: 1.0
                            blurMax: 40
                        }

                        Image {
                            id: glowImage
                            source: artImage.source
                            width: parent.width * 1.7
                            height: parent.height * 3
                            anchors.verticalCenter: parent.verticalCenter
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            smooth: true
                            opacity: 0.85

                            // Deriva horizontal lenta, de un lado a otro.
                            SequentialAnimation on x {
                                running: spotifyModule.artReady
                                loops: Animation.Infinite
                                NumberAnimation {
                                    from: -spotifyGlow.width * 0.25
                                    to: spotifyGlow.width * 0.05
                                    duration: 16000
                                    easing.type: Easing.InOutSine
                                }
                                NumberAnimation {
                                    from: spotifyGlow.width * 0.05
                                    to: -spotifyGlow.width * 0.25
                                    duration: 16000
                                    easing.type: Easing.InOutSine
                                }
                            }
                        }
                    }

                    // Velo oscuro para que el texto siga leyéndose bien.
                    Rectangle {
                        anchors.fill: parent
                        radius: 9
                        color: "#40000000"
                    }

                    // Pulso de luz muy suave, solo mientras hay reproducción.
                    Rectangle {
                        anchors.fill: parent
                        radius: 9
                        color: "#ffffff"
                        opacity: 0

                        SequentialAnimation on opacity {
                            running: !!spotifyModule.player && spotifyModule.player.isPlaying
                            loops: Animation.Infinite
                            NumberAnimation { from: 0.0; to: 0.09; duration: 3200; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 0.09; to: 0.0; duration: 3200; easing.type: Easing.InOutSine }
                        }
                    }
                }

                BloomRow {
                    id: spotifyRow
                    lit: spotifyMouse.containsMouse
                    spacing: 8
                    anchors.verticalCenter: parent.verticalCenter

                    // Carátula del álbum, con esquinas redondeadas.
                    Item {
                        width: 20
                        height: 20
                        anchors.verticalCenter: parent.verticalCenter

                        // Fondo (y nota musical) mientras no hay carátula o
                        // mientras la imagen de Spotify está descargando.
                        Rectangle {
                            id: artPlaceholder
                            anchors.fill: parent
                            radius: 4
                            color: "#26ffffff"
                            visible: !spotifyModule.player || !spotifyModule.player.trackArtUrl
                                     || artImage.status !== Image.Ready

                            Text {
                                anchors.centerIn: parent
                                text: "󰎆"
                                color: "#ffffff"
                                font.pixelSize: 12
                                font.family: "SF Pro Text"
                            }
                        }

                        // Máscara redondeada para recortar la carátula.
                        Rectangle {
                            id: artMask
                            anchors.fill: parent
                            radius: 4
                            color: "black"
                            visible: false
                            layer.enabled: true
                        }

                        Image {
                            id: artImage
                            anchors.fill: parent
                            source: {
                                var p = spotifyModule.player;
                                return (p && p.trackArtUrl) ? p.trackArtUrl : "";
                            }
                            sourceSize: Qt.size(40, 40)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            smooth: true
                            visible: status === Image.Ready
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: artMask
                            }
                        }
                    }

                    Text {
                        text: {
                            var p = spotifyModule.player;
                            if (!p) return "";
                            return p.trackTitle || "Spotify";
                        }
                        color: "#ffffff"
                        font.pixelSize: 15
                        font.bold: true
                        font.family: "SF Pro Text"
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        // No deja que un título largo empuje el resto de la barra.
                        width: Math.min(implicitWidth, 160)
                    }
                }

                MouseArea {
                    id: spotifyMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }
            }

            // --- Modulo de Volumen (PipeWire via wpctl) ---
            Item {
                id: volumeModule
                width: volumeRow.width
                height: volumeRow.height
                anchors.verticalCenter: parent.verticalCenter

                property int volume: 0
                property bool muted: false

                function volumeIcon() {
                    if (volumeModule.muted || volumeModule.volume === 0) return "󰝟";
                    else if (volumeModule.volume < 30) return "󰕿";
                    else if (volumeModule.volume < 70) return "󰖀";
                    else return "󰕾";
                }

                function refreshVolume() {
                    getVolumeProcess.running = true;
                }

                // Fija el volumen a un valor absoluto (usado por el slider)
                function setVolumeAbsolute(pct) {
                    pct = Math.max(0, Math.min(100, Math.round(pct)));
                    volumeModule.volume = pct;
                    volumeModule.muted = false;
                    setVolumeProcess.command = ["sh", "-c", "wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ " + (pct / 100).toFixed(2)];
                    setVolumeProcess.running = true;
                }

                // Sube/baja el volumen relativamente (usado por la rueda del raton)
                function adjustVolume(deltaPct) {
                    var dir = deltaPct > 0 ? "+" : "-";
                    var step = Math.abs(deltaPct);
                    setVolumeProcess.command = ["sh", "-c", "wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ " + step + "%" + dir];
                    setVolumeProcess.running = true;
                    volumeModule.volume = Math.max(0, Math.min(100, volumeModule.volume + deltaPct));
                }

                BloomRow {
                    id: volumeRow
                    lit: volumeMouse.containsMouse
                    spacing: 5
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        text: volumeModule.volumeIcon()
                        color: "#ffffff"
                        font.pixelSize: 18
                        font.family: "SF Pro Text"
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: volumeModule.muted ? "" : volumeModule.volume + "%"
                        color: "#ffffff"
                        font.pixelSize: 15
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: volumeMouse
                    hoverEnabled: true
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton
                    onClicked: {
                        volumePopup.visible = !volumePopup.visible;
                        if (volumePopup.visible) {
                            volumeModule.refreshVolume();
                            volumeFocusGrab.active = true;
                        }
                    }
                    onWheel: (wheel) => {
                        if (wheel.angleDelta.y > 0) volumeModule.adjustVolume(2);
                        else volumeModule.adjustVolume(-2);
                    }
                }

                // Lee el volumen actual desde PipeWire
                Process {
                    id: getVolumeProcess
                    command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@"]
                    running: false

                    stdout: SplitParser {
                        onRead: data => {
                            let line = data.trim();
                            let muted = line.indexOf("MUTED") !== -1;
                            let match = line.match(/[\d.]+/);
                            if (match) {
                                volumeModule.volume = Math.round(parseFloat(match[0]) * 100);
                                volumeModule.muted = muted;
                            }
                        }
                    }
                }

                // Ejecuta los cambios de volumen (set-volume)
                Process {
                    id: setVolumeProcess
                    running: false
                    onRunningChanged: if (!running) volumeModule.refreshVolume()
                }

                // Refresco periodico por si el volumen cambia desde fuera (teclas, otra app, etc.)
                Timer {
                    interval: 100
                    running: true
                    repeat: true
                    onTriggered: volumeModule.refreshVolume()
                }

                Component.onCompleted: volumeModule.refreshVolume()

                // --- Popup con el slider ---
                PopupWindow {
                    id: volumePopup
                    visible: false
                    color: "transparent"
                    implicitWidth: 200
                    implicitHeight: 56

                    anchor {
                        item: volumeModule
                        edges: Edges.Bottom
                        gravity: Edges.Bottom
                        adjustment: PopupAdjustment.None
                        margins.bottom: -8
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 0
                        color: "#99202028"
                        border.color: "#33ffffff"
                        border.width: 1

                        Slider {
                            id: volumeSlider
                            anchors.centerIn: parent
                            width: parent.width - 30
                            from: 0
                            to: 100
                            value: volumeModule.volume
                            onMoved: volumeModule.setVolumeAbsolute(value)

                            background: Rectangle {
                                x: volumeSlider.leftPadding
                                y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                                width: volumeSlider.availableWidth
                                height: 6
                                radius: 3
                                color: "#33ffffff"

                                Rectangle {
                                    width: volumeSlider.visualPosition * parent.width
                                    height: parent.height
                                    radius: 3
                                    color: "#1747a9"
                                }
                            }

                            handle: Rectangle {
                                x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                                y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                                width: 16
                                height: 16
                                radius: 8
                                color: volumeSlider.pressed ? "#cdd6f4" : "#ffffff"
                                border.color: "#1747a9"
                                border.width: 2
                            }
                        }
                    }

                    HyprlandFocusGrab {
                        id: volumeFocusGrab
                        windows: [ volumePopup ]
                        onCleared: volumePopup.visible = false
                    }
                }
            }

            // --- Módulo de Bluetooth ---
            Item {
                id: bluetoothModule
                width: btRow.width
                height: 20
                anchors.verticalCenter: parent.verticalCenter

                readonly property var adapter: Bluetooth.defaultAdapter
                readonly property bool btEnabled: bluetoothModule.adapter ? bluetoothModule.adapter.enabled : false

                BloomRow {
                    id: btRow
                    lit: btMouse.containsMouse
                    spacing: 5
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        text: bluetoothModule.btEnabled ? "󰂯" : "󰂲"
                        color: bluetoothModule.btEnabled ? "#ffffff" : "#ffffff"
                        font.pixelSize: 18
                        font.family: "SF Pro Text"
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: btMouse
                    hoverEnabled: true
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        bluetoothPopup.visible = !bluetoothPopup.visible;
                        if (bluetoothPopup.visible) bluetoothFocusGrab.active = true;
                    }
                }

                PopupWindow {
                    id: bluetoothPopup
                    visible: false
                    color: "transparent"
                    implicitWidth: 240
                    implicitHeight: bluetoothColumn.implicitHeight + 20

                    anchor {
                        item: bluetoothModule
                        edges: Edges.Bottom
                        gravity: Edges.Bottom
                        adjustment: PopupAdjustment.None
                        margins.bottom: 4
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: "#99202028"
                        border.color: "#33ffffff"
                        border.width: 1

                        Column {
                            id: bluetoothColumn
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.topMargin: 10
                            width: parent.width - 20
                            spacing: 10

                            // --- Cabecera con el switch ---
                            Item {
                                width: parent.width
                                height: 24

                                Text {
                                    text: "Bluetooth"
                                    color: "#ffffff"
                                    font.pixelSize: 14
                                    font.bold: true
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Rectangle {
                                    id: btSwitch
                                    width: 40
                                    height: 22
                                    radius: 11
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: bluetoothModule.btEnabled ? "#1747a9" : "#33ffffff"
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Rectangle {
                                        width: 18
                                        height: 18
                                        radius: 9
                                        color: "#ffffff"
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: bluetoothModule.btEnabled ? parent.width - width - 2 : 2
                                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutExpo } }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (bluetoothModule.adapter) {
                                                bluetoothModule.adapter.enabled = !bluetoothModule.adapter.enabled;
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: "#33ffffff"
                                visible: bluetoothModule.btEnabled
                            }

                            // --- Lista de dispositivos (solo si está encendido) ---
                            Column {
                                width: parent.width
                                spacing: 4
                                visible: bluetoothModule.btEnabled

                                Text {
                                    text: (bluetoothModule.adapter && bluetoothModule.adapter.devices.values.length > 0) ? "Dispositivos" : "Sin dispositivos emparejados"
                                    color: "#cdd6f4"
                                    font.pixelSize: 11
                                }

                                Repeater {
                                    model: bluetoothModule.adapter ? bluetoothModule.adapter.devices.values : []

                                    Rectangle {
                                        width: parent.width
                                        height: 28
                                        radius: 6
                                        color: deviceMouse.containsMouse ? "#33ffffff" : "transparent"
                                        Behavior on color { ColorAnimation { duration: 100 } }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.left: parent.left
                                            anchors.leftMargin: 8
                                            text: (modelData.connected ? "󰂱 " : "󰂯 ") + modelData.name
                                            color: modelData.connected ? "#a6e3a1" : "#ffffff"
                                            font.pixelSize: 12
                                            font.family: "SF Pro Text"
                                        }

                                        MouseArea {
                                            id: deviceMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: modelData.connected = !modelData.connected
                                        }
                                    }
                                }
                            }
                        }
                    }

                    HyprlandFocusGrab {
                        id: bluetoothFocusGrab
                        windows: [ bluetoothPopup ]
                        onCleared: bluetoothPopup.visible = false
                    }
                }
            }

            // --- Módulo de Red (SSID + señal WiFi) ---
            BloomRow {
                // Solo el icono: el nombre de la conexion (SSID) esta comentado
                lit: netIconMouse.containsMouse
                id: netModule
                spacing: 8

                property int signalStrength: 100
                property string wifiIcon: "󰤨"
                property string ssidName: "..."

                function updateWifiIcon(signal) {
                    if (signal > 80) return "󰤨";      // Excelente
                    else if (signal > 60) return "󰤥"; // Buena
                    else if (signal > 40) return "󰤢"; // Media
                    else if (signal > 20) return "󰤟"; // Baja
                    else if (signal > 0) return "󰤯";  // Muy baja
                    else return "󰤮";                 // Sin señal
                }

                Text {
                    id: netIconText
                    MouseArea {
                        id: netIconMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }
                    text: netModule.wifiIcon
                    color: "#ffffff"
                    font.pixelSize: 18
                    font.family: "SF Pro Text"
                    anchors.verticalCenter: parent.verticalCenter
                }

                /*
                 * Nombre de la conexion (SSID) - COMENTADO a peticion del
                 * usuario: en la barra solo queda visible el icono de WiFi.
                 * El dato se sigue leyendo en netProcess (netModule.ssidName)
                 * por si se quiere volver a mostrar.
                 *
                Text {
                    id: netSsidText
                    MouseArea {
                        id: netSsidMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }
                    text: netModule.ssidName
                    color: "#ffffff"
                    font.pixelSize: 15
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    // Corta el nombre si es muy largo, para no romper la barra
                    width: Math.min(implicitWidth, 140)
                }
                */

                Process {
                    id: netProcess
                    command: ["bash", "-c", "iface=$(ip route 2>/dev/null | awk '/default/ {print $5}' | head -n1); [ -z \"$iface\" ] && iface='wlan0'; link=$(iw dev \"$iface\" link 2>/dev/null); ssid=$(echo \"$link\" | awk -F': ' '/SSID/ {print $2}'); dbm=$(echo \"$link\" | awk '/signal:/ {print $2}'); if [ -z \"$ssid\" ]; then ssid='Sin conexión'; sig=0; else if [ -n \"$dbm\" ]; then sig=$(( (dbm + 100) * 2 )); [ $sig -lt 0 ] && sig=0; [ $sig -gt 100 ] && sig=100; else sig=100; fi; fi; echo \"$sig|$ssid\""]
                    running: false

                    stdout: SplitParser {
                        onRead: data => {
                            let line = data.trim();
                            let parts = line.split("|");
                            if (parts.length >= 2) {
                                let sig = parseInt(parts[0]);
                                let ssid = parts[1];

                                if (!isNaN(sig)) {
                                    netModule.signalStrength = sig;
                                    netModule.wifiIcon = netModule.updateWifiIcon(sig);
                                }
                                netModule.ssidName = ssid;
                            }
                        }
                    }
                }

                Timer {
                    interval: 100
                    running: true
                    repeat: true
                    onTriggered: {
                        if (!netProcess.running) {
                            netProcess.running = true;
                        }
                    }
                }

                Component.onCompleted: netProcess.running = true
            }

/* 
            // --- Modulo de RAM (Sincronizado con el sistema) ---
            Row {
                spacing: 5
                
                Text {
                    text: "" // Glifo de chip/memoria (Nerd Font)
                    color: "#ffffff"
                    font.pixelSize: 16
                    font.family: "SF Pro Text"
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Text {
                    id: ramText
                    text: "..." 
                    color: "#ffffff"
                    font.pixelSize: 15
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }

                Process {
                    id: ramProcess
                    // Calcula el porcentaje de RAM usada dividiendo usada / total
                    command: ["sh", "-c", "free | awk '/Mem:/ {print int($3/$2 * 100)}'"]
                    running: false

                    stdout: SplitParser {
                        onRead: data => {
                            let val = data.trim();
                            if (val !== "" && !isNaN(val)) {
                                ramText.text = val + "%";
                            }
                        }
                    }
                }

                // El Timer actualiza el valor de la RAM cada 5 segundos
                Timer {
                    interval: 5000
                    running: true
                    repeat: true
                    onTriggered: {
                        if (!ramProcess.running) {
                            ramProcess.running = true;
                        }
                    }
                }
            }

            // --- Modulo de CPU (Exacto y sincronizado con btop) ---
           Row {
                spacing: 5
                
                Text {
                    text: "" 
                    color: "#ffffff"
                    font.pixelSize: 16
                    font.family: "SF Pro Text"
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Text {
                    id: cpuText
                    text: "..." 
                    color: "#ffffff"
                    font.pixelSize: 15
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }

                Process {
                    id: cpuProcess
                    // Toma dos fotos de /proc/stat separadas por 1 segundo, calcula el % real y escupe un único número
                    command: ["sh", "-c", "awk 'NR==1 {u1=$2+$3+$4; t1=$2+$3+$4+$5+$6+$7+$8} NR==2 {u2=$2+$3+$4; t2=$2+$3+$4+$5+$6+$7+$8; print int((u2-u1)*100/(t2-t1))}' <(grep '^cpu ' /proc/stat) <(sleep 1; grep '^cpu ' /proc/stat)"]
                    running: false

                    stdout: SplitParser {
                        onRead: data => {
                            let val = data.trim();
                            if (val !== "" && !isNaN(val)) {
                                cpuText.text = val + "%";
                            }
                        }
                    }
                }

                // El Timer dispara una medición limpia cada 2 segundos
                Timer {
                    interval: 2000
                    running: true
                    repeat: true
                    onTriggered: {
                        if (!cpuProcess.running) {
                            cpuProcess.running = true;
                        }
                    }
                }
            }
 */

            // --- Módulo de Batería estilo macOS ---
            BloomRow {
                id: batteryRow
                lit: batteryTextMouse.containsMouse || batteryShapeMouse.containsMouse
                spacing: 8
                anchors.verticalCenter: parent.verticalCenter

                // Texto del porcentaje
                Text {
                    id: batteryText
                    MouseArea {
                        id: batteryTextMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }
                    color: {
                        if (UPower.displayDevice.state === 1 || UPower.displayDevice.state === 4) return "#a6e3a1";
                        if (ccModule.powerProfile === "power-saver") return "#fab387";
                        if (UPower.displayDevice.percentage <= 0.2) return "#f38ba8";
                        return "#ffffff";
                    }
                    font.pixelSize: 15
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(UPower.displayDevice.percentage * 100) + "%"
                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }

                // Píldora de batería dibujada mediante QML
                Item {
                    id: batteryShape
                    MouseArea {
                        id: batteryShapeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }
                    width: 24
                    height: 11
                    anchors.verticalCenter: parent.verticalCenter

                    property real pct: UPower.displayDevice.percentage // Valor entre 0.0 y 1.0
                    property bool isCharging: UPower.displayDevice.state === 1 || UPower.displayDevice.state === 4

                    // Contenedor principal (El cuerpo de la batería)
                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 21
                        height: 11
                        radius: 3.5
                        color: "#22ffffff" // Fondo translúcido de la batería
                        border.color: "#cdd6f4"
                        border.width: 1

                        // Relleno interior proporcional al porcentaje
                        Rectangle {
                            id: fillRect
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.margins: 2
                            // El ancho se calcula en función del porcentaje real (dejando margen interior)
                            width: Math.max(0, (parent.width - 4) * parent.parent.pct)
                            radius: 2
                            color: {
                                if (parent.parent.isCharging) return "#a6e3a1";
                                if (ccModule.powerProfile === "power-saver") return "#fab387";
                                if (parent.parent.pct <= 0.2) return "#f38ba8";
                                return "#ffffff";
                            }

                            Behavior on width {
                                NumberAnimation { duration: 200 }
                            }
                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }
                        }
                    }

                    // El "pezón" o terminal positivo de la batería a la derecha
                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 2
                        height: 5
                        radius: 1
                        color: "#cdd6f4"
                    }
                }
            }

            // --- Módulo de Notificaciones (historial + avisos) ---
            Item {
                id: notifModule
                width: notifRow.width
                height: 20
                anchors.verticalCenter: parent.verticalCenter

                readonly property int count: notifServer.trackedNotifications.values.length

                // Muestra un aviso emergente con la notificación recién recibida
                function toast(notif) {
                    if (ccModule.dnd) return;
                    toastApp.text = notif.appName || "";
                    toastTitle.text = notif.summary || "";
                    toastBody.text = notif.body || "";
                    toastPopup.visible = true;
                    toastTimer.restart();
                }

                BloomRow {
                    lit: notifMouse.containsMouse
                    id: notifRow
                    spacing: 5
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        text: ccModule.dnd ? "\u{f0f6}" : "\u{f0f3}" // campana / campana tachada
                        color: notifMouse.containsMouse ? "#ffffff" : (ccModule.dnd ? "#a6adc8" : "#ffffff")
                        Behavior on color { ColorAnimation { duration: 150 } }
                        font.pixelSize: 17
                        font.family: "SF Pro Text"
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        visible: notifModule.count > 0
                        text: notifModule.count
                        color: "#f38ba8"
                        font.pixelSize: 13
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: notifMouse
                    hoverEnabled: true
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        notifPopup.visible = !notifPopup.visible;
                        if (notifPopup.visible) notifFocusGrab.active = true;
                    }
                }

                // --- Popup con el historial de notificaciones ---
                PopupWindow {
                    id: notifPopup
                    visible: false
                    color: "transparent"
                    implicitWidth: 300
                    implicitHeight: Math.min(notifCol.implicitHeight + 16, 400)

                    anchor {
                        item: notifModule
                        edges: Edges.Bottom | Edges.Right
                        gravity: Edges.Bottom | Edges.Left
                        adjustment: PopupAdjustment.SlideX
                        margins.bottom: 4
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: "#2c2c34"
                        border.color: "#45475a"
                        border.width: 1

                        Column {
                            id: notifCol
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6

                            // --- Cabecera ---
                            Item {
                                width: parent.width
                                height: 22

                                Text {
                                    text: "Notificaciones"
                                    color: "#ffffff"
                                    font.pixelSize: 13
                                    font.bold: true
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    visible: notifModule.count > 0
                                    text: "Limpiar todo"
                                    color: "#f38ba8"
                                    font.pixelSize: 11
                                    font.underline: true
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -6
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: ccModule.clearAllNotifications()
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: "#33ffffff"
                            }

                            // --- No molestar ---
                            Item {
                                width: parent.width
                                height: 22

                                Text {
                                    text: "No molestar"
                                    color: "#a6adc8"
                                    font.pixelSize: 11
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Row {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6

                                    Text {
                                        text: ccModule.dnd ? "\u{f0f6}" : "\u{f0f3}"
                                        color: ccModule.dnd ? "#a6adc8" : "#ffffff"
                                        font.pixelSize: 13
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    CcSwitch {
                                        anchors.verticalCenter: parent.verticalCenter
                                        checked: ccModule.dnd
                                        onToggled: ccModule.dnd = !ccModule.dnd
                                    }
                                }
                            }

                            // --- Sonido de notificaciones ---
                            Item {
                                width: parent.width
                                height: 22

                                Text {
                                    text: "Sonido de notificaciones"
                                    color: "#a6adc8"
                                    font.pixelSize: 11
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Row {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6

                                    Text {
                                        text: ccModule.notificationSound ? "\uf001" : "\uf001"
                                        color: ccModule.notificationSound ? "#ffffff" : "#a6adc8"
                                        font.pixelSize: 13
                                        font.family: "SF Pro Text"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    CcSwitch {
                                        anchors.verticalCenter: parent.verticalCenter
                                        checked: ccModule.notificationSound
                                        onToggled: ccModule.notificationSound = !ccModule.notificationSound
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: "#33ffffff"
                            }

                            // --- Lista de notificaciones ---
                            Flickable {
                                id: notifFlick
                                width: parent.width
                                height: Math.min(contentHeight, 330)
                                contentHeight: notifList.implicitHeight
                                clip: true

                                Column {
                                    id: notifList
                                    width: parent.width
                                    spacing: 4

                                    Text {
                                        visible: notifModule.count === 0
                                        text: "Sin notificaciones"
                                        color: "#a6adc8"
                                        font.pixelSize: 12
                                    }

                                    Repeater {
                                        model: notifServer.trackedNotifications.values

                                        Rectangle {
                                            width: notifList.width
                                            height: notifItemCol.implicitHeight + 12
                                            radius: 6
                                            color: "#33ffffff"

                                            Column {
                                                id: notifItemCol
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: 8
                                                anchors.rightMargin: 8
                                                spacing: 2

                                                Row {
                                                    width: parent.width
                                                    spacing: 6

                                                    Text {
                                                        text: modelData.appName || "Aplicación"
                                                        color: "#a6adc8"
                                                        font.pixelSize: 10
                                                        elide: Text.ElideRight
                                                        width: parent.width - closeNotif.width - 6
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }

                                                    Text {
                                                        id: closeNotif
                                                        text: "×"
                                                        color: "#a6adc8"
                                                        font.pixelSize: 14
                                                        font.bold: true
                                                        anchors.verticalCenter: parent.verticalCenter

                                                        MouseArea {
                                                            anchors.fill: parent
                                                            anchors.margins: -6
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: modelData.dismiss()
                                                        }
                                                    }
                                                }

                                                Text {
                                                    text: modelData.summary
                                                    color: modelData.urgency === 2 ? "#f38ba8" : "#ffffff"
                                                    font.pixelSize: 12
                                                    font.bold: true
                                                    elide: Text.ElideRight
                                                    width: parent.width
                                                }

                                                Text {
                                                    visible: modelData.body !== ""
                                                    text: modelData.body
                                                    color: "#cdd6f4"
                                                    font.pixelSize: 11
                                                    wrapMode: Text.WordWrap
                                                    maximumLineCount: 3
                                                    elide: Text.ElideRight
                                                    width: parent.width
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    HyprlandFocusGrab {
                        id: notifFocusGrab
                        windows: [ notifPopup ]
                        onCleared: notifPopup.visible = false
                    }
                }

                // --- Aviso emergente (toast) para notificaciones nuevas ---
                PopupWindow {
                    id: toastPopup
                    visible: false
                    color: "transparent"
                    implicitWidth: 300
                    implicitHeight: toastCol.implicitHeight + 16

                    anchor {
                        item: notifModule
                        edges: Edges.Bottom | Edges.Right
                        gravity: Edges.Bottom | Edges.Left
                        adjustment: PopupAdjustment.SlideX
                        margins.bottom: 4
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: "#2c2c34"
                        border.color: "#1747a9"
                        border.width: 1

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: toastPopup.visible = false
                        }

                        Column {
                            id: toastCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 2

                            Text {
                                id: toastApp
                                width: parent.width
                                color: "#a6adc8"
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }

                            Text {
                                id: toastTitle
                                width: parent.width
                                color: "#ffffff"
                                font.pixelSize: 12
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                id: toastBody
                                width: parent.width
                                color: "#cdd6f4"
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                                maximumLineCount: 4
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Timer {
                        id: toastTimer
                        interval: 5000
                        onTriggered: toastPopup.visible = false
                    }
                }
            }

            // --- Módulo de Centro de Control (WiFi + Bluetooth + Batería) ---
            Item {
                id: ccModule
                width: kbLangRow.width + 10 + ccIconRow.width
                height: 20
                anchors.verticalCenter: parent.verticalCenter

                // ====== Estado WiFi (iwd via D-Bus) ======
                property bool wifiPowered: false
                property bool wifiScanning: false
                property string wifiState: "disconnected"
                property string wifiConnectedName: ""
                property var wifiNets: []        // { hex, name, type, dbm, known, connected }
                property string wifiNetsJson: "[]"
                property string wifiIface: "wlan0"
                property string pendingSsid: ""  // red que está pidiendo contraseña
                property string pendingType: ""  // tipo de la red pendiente
                property string wifiError: ""

                // ====== Bluetooth ======
                readonly property var btAdapter: Bluetooth.defaultAdapter
                readonly property bool btEnabled: btAdapter ? btAdapter.enabled : false

                // ====== Notificaciones ======
                property bool dnd: false
                property bool notificationSound: true

                // ====== Idioma del teclado (es/us) ======
                property string kbLayout: "es"         // codigo del layout activo
                property var kbLayoutList: ["es", "us"] // layouts de input.kb_layout

                // ====== Brillo de pantalla ======
                property int brightness: 100

                // ====== Perfil de energía ======
                property string powerProfile: ""
                readonly property var powerProfiles: [
                    { key: "performance", label: "Rendimiento" },
                    { key: "balanced", label: "Equilibrado" },
                    { key: "power-saver", label: "Ahorro" }
                ]

                // ====== Reproductor multimedia (MPRIS) ======
                // Cualquier app que exponga MPRIS: Brave/Chromium, Spotify, VLC, Firefox…
                readonly property var mediaPlayers: Mpris.players.values
                property string mediaPlayerId: ""   // dbusName del reproductor elegido a mano
                readonly property var mediaPlayer: activeMediaPlayer()
                property int mediaTick: 0

                // Decodifica el nombre en hex que usa iwd a texto (UTF-8 básico)
                function hexUtf8(hex) {
                    var bytes = [], i;
                    for (i = 0; i + 1 < hex.length; i += 2)
                        bytes.push(parseInt(hex.substr(i, 2), 16));
                    var out = "";
                    i = 0;
                    while (i < bytes.length) {
                        var b = bytes[i++];
                        if (b < 0x80)
                            out += String.fromCharCode(b);
                        else if ((b & 0xE0) === 0xC0 && i < bytes.length)
                            out += String.fromCharCode(((b & 0x1F) << 6) | (bytes[i++] & 0x3F));
                        else if ((b & 0xF0) === 0xE0 && i + 1 < bytes.length)
                            out += String.fromCharCode(((b & 0x0F) << 12) | ((bytes[i++] & 0x3F) << 6) | (bytes[i++] & 0x3F));
                        else
                            out += "?";
                    }
                    return out;
                }

                // Icono de señal a partir de la potencia (1/100 dBm)
                function wifiIconFor(sig100) {
                    var pct = Math.max(0, Math.min(100, (Math.round(sig100 / 100) + 100) * 2));
                    if (pct > 80) return "󰤨";
                    else if (pct > 60) return "󰤥";
                    else if (pct > 40) return "󰤢";
                    else if (pct > 20) return "󰤟";
                    else if (pct > 0) return "󰤯";
                    return "󰤮";
                }

                function refreshWifi() {
                    if (!wifiInfoProcess.running) wifiInfoProcess.running = true;
                }

                function wifiStateLabel() {
                    if (!wifiPowered) return "Apagado";
                    if (wifiState === "connected") return "Conectado";
                    if (wifiState === "connecting" || wifiState === "roaming") return "Conectando…";
                    if (wifiScanning) return "Buscando…";
                    return "Desconectado";
                }

                // Conecta a una red: si iwd conoce la red usa la contraseña guardada
                function connectWifi(hex, type) {
                    pendingSsid = hexUtf8(hex);
                    pendingType = type;
                    wifiError = "";
                    wifiConnectProcess.viaPass = false;
                    wifiConnectProcess.command = ["busctl", "call", "net.connman.iwd",
                        "/net/connman/iwd/0/4/" + hex + "_" + type, "net.connman.iwd.Network", "Connect"];
                    wifiConnectProcess.running = true;
                }

                // Conecta indicando la contraseña (redes desconocidas) via iwctl
                function connectWithPass(pass) {
                    wifiError = "";
                    wifiConnectProcess.viaPass = true;
                    wifiConnectProcess.command = ["iwctl", "--passphrase", pass, "station",
                        wifiIface, "connect", pendingSsid];
                    wifiConnectProcess.running = true;
                }

                function disconnectWifi() {
                    wifiDisconnectProcess.running = true;
                }

                function forgetWifi(hex, type) {
                    wifiForgetProcess.command = ["busctl", "call", "net.connman.iwd",
                        "/net/connman/iwd/" + hex + "_" + type, "net.connman.iwd.KnownNetwork", "Forget"];
                    wifiForgetProcess.running = true;
                    pendingSsid = "";
                    wifiError = "";
                }

                function setWifiPower(on) {
                    wifiPowerProcess.command = ["busctl", "set-property", "net.connman.iwd",
                        "/net/connman/iwd/0", "net.connman.iwd.Adapter", "Powered", "b", on ? "true" : "false"];
                    wifiPowerProcess.running = true;
                    pendingSsid = "";
                    wifiError = "";
                }

                function scanWifi() {
                    wifiScanProcess.running = true;
                }

                // ====== Acciones de brillo ======
                function refreshBrightness() {
                    if (!brightnessGetProcess.running) brightnessGetProcess.running = true;
                }

                // ====== Acciones de perfil de energía ======
                function refreshProfile() {
                    if (!profileGetProcess.running) profileGetProcess.running = true;
                }

                function setProfile(key) {
                    powerProfile = key;
                    Quickshell.execDetached(["powerprofilesctl", "set", key]);
                    profileRefreshTimer.restart();

                    var label = profileLabel(key);
                    Quickshell.execDetached(["sh", "-c",
                        "notify-send -a 'Centro de control' -i preferences-system-power 'Perfil de energía' "
                        + "'Ahora está activo el perfil " + label + " (" + key + ")'"]);
                }

                function profileLabel(key) {
                    for (var i = 0; i < powerProfiles.length; i++) {
                        if (powerProfiles[i].key === key)
                            return powerProfiles[i].label;
                    }
                    return key;
                }

                // ====== Idioma del teclado =====
                // Alterna al siguiente layout (es <-> us) en todos los teclados
                function switchKbLayout() {
                    Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]);
                    kbLayoutRefreshTimer.restart();
                }

                // Fija un layout concreto (por ejemplo "es" o "us")
                function setKbLayout(code) {
                    var i = kbLayoutList.indexOf(code);
                    if (i < 0) return;
                    Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", String(i)]);
                    kbLayoutRefreshTimer.restart();
                }

                // ====== Reproductor multimedia ======
                // Elige el reproductor activo: el seleccionado a mano, o el que esté sonando
                function activeMediaPlayer() {
                    var vals = mediaPlayers;
                    if (!vals || vals.length === 0) return null;

                    if (mediaPlayerId !== "") {
                        for (var i = 0; i < vals.length; i++) {
                            if (vals[i].dbusName === mediaPlayerId) return vals[i];
                        }
                    }

                    for (var j = 0; j < vals.length; j++) {
                        if (vals[j].isPlaying) return vals[j];
                    }

                    return vals[0];
                }

                // Nombre corto de la app del reproductor (brave, spotify, vlc…)
                function mediaAppLabel(p) {
                    if (!p) return "";
                    if (p.desktopEntry) {
                        var d = p.desktopEntry.split(".").pop();
                        if (d.toLowerCase() === "brave-browser") return "Brave";
                        return d.charAt(0).toUpperCase() + d.slice(1);
                    }
                    return p.identity;
                }

                // Formatea segundos como "m:ss"
                function fmtTime(sec) {
                    if (!sec || sec <= 0 || isNaN(sec)) return "0:00";
                    var s = Math.floor(sec);
                    var m = Math.floor(s / 60);
                    var r = s % 60;
                    return m + ":" + (r < 10 ? "0" : "") + r;
                }

                // Fracción reproducida; lee mediaTick para refrescarse cada segundo
                function mediaProgress() {
                    if (mediaTick < 0) return 0;
                    var p = mediaPlayer;
                    if (!p || !p.length || p.length <= 0) return 0;
                    return Math.max(0, Math.min(1, p.position / p.length));
                }

                // ====== Acciones de Bluetooth ======
                function setBtPower(on) {
                    if (!btAdapter) return;
                    if (on) {
                        // Hay que quitar el bloqueo rfkill antes de encender la radio
                        Quickshell.execDetached(["rfkill", "unblock", "bluetooth"]);
                        btEnableTimer.start();
                    } else {
                        btEnableTimer.stop();
                        btAdapter.enabled = false;
                        Quickshell.execDetached(["rfkill", "block", "bluetooth"]);
                    }
                }

                function btStateLabel(dev) {
                    if (dev.state === 1) return "Conectando…";
                    if (dev.state === 2) return "Conectado";
                    if (dev.state === 3) return "Desconectando…";
                    if (dev.paired || dev.bonded) return "Emparejado";
                    return "Pulsa para emparejar";
                }

                // Clic en un dispositivo: conecta, desconecta o inicia el emparejamiento
                function btClick(dev) {
                    if (dev.state === 2) dev.disconnect();
                    else if (dev.state !== 1 && dev.state !== 3) {
                        if (dev.paired || dev.bonded) dev.connect();
                        else dev.pair();
                    }
                }

                // ====== Batería (UPower) ======
                function batteryStateLabel() {
                    var s = UPower.displayDevice.state;
                    if (s === 1) return "Cargando";
                    if (s === 2) return "Descargando";
                    if (s === 3) return "Batería vacía";
                    if (s === 4) return "Batería completa";
                    if (s === 5) return "Carga pendiente";
                    if (s === 6) return "Descarga pendiente";
                    return "Estado desconocido";
                }

                function batteryStateColor() {
                    var s = UPower.displayDevice.state;
                    if (s === 1 || s === 4) return "#a6e3a1";
                    if (s === 2 && UPower.displayDevice.percentage <= 0.2) return "#f38ba8";
                    return "#cdd6f4";
                }

                // Formata una duración en segundos como "X h Y min"
                function fmtDur(sec) {
                    if (!sec || sec <= 0) return "—";
                    var h = Math.floor(sec / 3600);
                    var m = Math.floor((sec % 3600) / 60);
                    if (h > 0) return h + " h " + m + " min";
                    return Math.max(1, m) + " min";
                }

                function batteryTimeText() {
                    var s = UPower.displayDevice.state;
                    if (s === 1) return "Completa en " + fmtDur(UPower.displayDevice.timeToFull);
                    if (s === 2) return "Autonomía " + fmtDur(UPower.displayDevice.timeToEmpty);
                    return "";
                }

                // ====== Notificaciones ======
                function clearAllNotifications() {
                    var vals = notifServer.trackedNotifications.values;
                    for (var i = vals.length - 1; i >= 0; i--) vals[i].dismiss();
                }

                // Pequeño botón reutilizable
                component CcButton: Rectangle {
                    id: btn
                    property string label: ""
                    property string txtColor: "#cdd6f4"
                    signal clicked()
                    height: 20
                    width: btnLabel.implicitWidth + 14
                    radius: 5
                    color: btnMouse.containsMouse ? "#45475a" : "#33ffffff"
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                        id: btnLabel
                        anchors.centerIn: parent
                        text: btn.label
                        color: btn.txtColor
                        font.pixelSize: 10
                        font.bold: true
                    }

                    MouseArea {
                        id: btnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: btn.clicked()
                    }
                }

                // Interruptor reutilizable (estilo ya usado en el popup de Bluetooth)
                component CcSwitch: Rectangle {
                    id: sw
                    property bool checked: false
                    signal toggled()
                    width: 36
                    height: 20
                    radius: 10
                    color: sw.checked ? "#1747a9" : "#33ffffff"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Rectangle {
                        width: 16
                        height: 16
                        radius: 8
                        color: "#ffffff"
                        anchors.verticalCenter: parent.verticalCenter
                        x: sw.checked ? parent.width - width - 2 : 2
                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutExpo } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sw.toggled()
                    }
                }

                // Indicador del idioma del teclado (ES / US). Al pulsarlo
                // alterna entre español e inglés en todos los teclados.
                BloomRow {
                    id: kbLangRow
                    spacing: 4
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    lit: kbLangMouse.containsMouse

                    Text {
                        text: ccModule.kbLayout.toUpperCase()
                        color: "#ffffff"
                        font.pixelSize: 13
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                BloomRow {
                    lit: ccMouse.containsMouse
                    id: ccIconRow
                    spacing: 5
                    anchors.left: kbLangRow.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        text: "\u{f0493}" // engranaje (centro de control)
                        color: "#ffffff"
                        font.pixelSize: 17
                        font.family: "SF Pro Text"
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: ccMouse
                    hoverEnabled: true
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        ccPopup.visible = !ccPopup.visible;
                        if (ccPopup.visible) {
                            ccModule.refreshWifi();
                            ccModule.refreshBrightness();
                            ccModule.refreshProfile();
                            ccFocusGrab.active = true;
                        }
                    }
                }

                // Ratón del indicador de idioma. Se declara DESPUÉS de ccMouse
                // para que quede por encima: así la pulsación cambia el
                // idioma y no abre el centro de control.
                MouseArea {
                    id: kbLangMouse
                    anchors.left: kbLangRow.left
                    anchors.right: kbLangRow.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 18
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ccModule.switchKbLayout()
                }

                // ====== Proceso del idioma del teclado =====
                // Lee el layout activo (script: kb-layout.sh -> "es,us|1")
                Process {
                    id: kbLayoutProcess
                    command: ["/home/alexg/.config/quickshell/scripts/kb-layout.sh"]
                    running: false

                    stdout: SplitParser {
                        onRead: data => {
                            var v = data.trim();
                            if (v === "") return;
                            var p = v.split("|");
                            ccModule.kbLayoutList = p[0].split(",");
                            var i = parseInt(p[1]);
                            if (!isNaN(i) && i >= 0 && i < ccModule.kbLayoutList.length)
                                ccModule.kbLayout = ccModule.kbLayoutList[i];
                        }
                    }
                }

                // Sondeo: el layout cambia con SUPER + K o con ALT + SHIFT
                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: if (!kbLayoutProcess.running) kbLayoutProcess.running = true
                }

                // Refresco inmediato tras conmutar el layout
                Timer {
                    id: kbLayoutRefreshTimer
                    interval: 250
                    onTriggered: {
                        kbLayoutProcess.running = false;
                        kbLayoutProcess.running = true;
                    }
                }

                // ====== Procesos WiFi ======
                // Lee el estado de iwd: alimentación, escaneo, redes y conexión actual
                Process {
                    id: wifiInfoProcess
                    command: ["/home/alexg/.config/quickshell/scripts/iwd-info.sh"]
                    running: false
                    property var netsAcc: []

                    stdout: SplitParser {
                        onRead: data => {
                            var parts = data.trim().split("|");
                            if (parts.length < 2) return;
                            if (parts[0] === "estado") {
                                ccModule.wifiPowered = parts[1] === "true";
                                ccModule.wifiScanning = parts[2] === "true";
                                ccModule.wifiState = parts[3];
                                wifiInfoProcess.netsAcc = [];
                            } else if (parts[0] === "conectado") {
                                var c = parts[1];
                                ccModule.wifiConnectedName = (c === "" || c === "/") ? "" :
                                    ccModule.hexUtf8(c.substring(0, c.lastIndexOf("_")));
                            } else if (parts[0] === "red") {
                                wifiInfoProcess.netsAcc.push({
                                    hex: parts[1],
                                    name: ccModule.hexUtf8(parts[1]),
                                    type: parts[2],
                                    dbm: parseInt(parts[3]),
                                    known: parts[4] === "1",
                                    connected: parts[5] === "1"
                                });
                            }
                        }
                    }

                    // Solo re-renderiza la lista si algo ha cambiado (evita parpadeos)
                    onExited: {
                        var j = JSON.stringify(wifiInfoProcess.netsAcc);
                        if (j !== ccModule.wifiNetsJson) {
                            ccModule.wifiNetsJson = j;
                            ccModule.wifiNets = wifiInfoProcess.netsAcc;
                        }
                    }
                }

                // Conexión (D-Bus para redes conocidas, iwctl con contraseña para el resto)
                Process {
                    id: wifiConnectProcess
                    running: false
                    property bool viaPass: false

                    onExited: (exitCode) => {
                        if (exitCode === 0) {
                            ccModule.pendingSsid = "";
                            ccModule.wifiError = "";
                        } else if (wifiConnectProcess.viaPass) {
                            ccModule.wifiError = "Contraseña incorrecta o red no disponible";
                        } else if (ccModule.pendingType !== "open") {
                            // iwd no tiene contraseña guardada: la pedimos
                            ccModule.wifiError = "Introduce la contraseña";
                        } else {
                            ccModule.pendingSsid = "";
                            ccModule.wifiError = "No se pudo conectar";
                        }
                        ccModule.refreshWifi();
                    }
                }

                Process {
                    id: wifiDisconnectProcess
                    command: ["busctl", "call", "net.connman.iwd", "/net/connman/iwd/0/4", "net.connman.iwd.Station", "Disconnect"]
                    running: false
                    onExited: ccModule.refreshWifi()
                }

                Process {
                    id: wifiScanProcess
                    command: ["busctl", "call", "net.connman.iwd", "/net/connman/iwd/0/4", "net.connman.iwd.Station", "Scan"]
                    running: false
                    onExited: ccModule.refreshWifi()
                }

                Process {
                    id: wifiForgetProcess
                    running: false
                    onExited: ccModule.refreshWifi()
                }

                Process {
                    id: wifiPowerProcess
                    running: false
                    onExited: ccModule.refreshWifi()
                }

                // ====== Procesos del panel lateral ======
                // brightnessctl -m -> dispositivo,tipo,valor,porcentaje,máximo
                Process {
                    id: brightnessGetProcess
                    command: ["brightnessctl", "-m"]
                    running: false

                    stdout: SplitParser {
                        onRead: data => {
                            var p = data.trim().split(",");
                            if (p.length < 4) return;
                            var pct = parseInt(p[3]);
                            if (!isNaN(pct)) ccModule.brightness = pct;
                        }
                    }
                }

                // Aplica el brillo con un pequeño retardo para no lanzar un proceso por píxel
                Timer {
                    id: brightSetTimer
                    interval: 80
                    onTriggered: Quickshell.execDetached(["brightnessctl", "-q", "set", ccModule.brightness + "%"])
                }

                // Perfil de energía actual
                Process {
                    id: profileGetProcess
                    command: ["powerprofilesctl", "get"]
                    running: false

                    stdout: SplitParser {
                        onRead: data => {
                            var v = data.trim();
                            if (v !== "") ccModule.powerProfile = v;
                        }
                    }
                }

                Timer {
                    id: profileRefreshTimer
                    interval: 400
                    onTriggered: ccModule.refreshProfile()
                }

                // Avanza la barra de progreso del reproductor mientras suena
                Timer {
                    id: mediaTickTimer
                    interval: 1000
                    repeat: true
                    running: ccPopup.visible && ccModule.mediaPlayer !== null && ccModule.mediaPlayer.isPlaying
                    onTriggered: ccModule.mediaTick++
                }

                // Pequeña espera para que rfkill desbloquee la radio antes de encenderla
                Timer {
                    id: btEnableTimer
                    interval: 300
                    onTriggered: if (ccModule.btAdapter) ccModule.btAdapter.enabled = true
                }

                // Refresco periódico mientras el popup está abierto
                Timer {
                    interval: 4000
                    running: ccPopup.visible
                    repeat: true
                    onTriggered: {
                        ccModule.refreshWifi();
                        ccModule.refreshProfile();
                    }
                }

                // ====== Popup del centro de control ======
                PopupWindow {
                    id: ccPopup
                    visible: false
                    color: "transparent"
                    implicitWidth: 600
                    implicitHeight: Math.min(Math.max(sideCol.implicitHeight, ccCol.implicitHeight) + 20, 560)

                    anchor {
                        item: ccModule
                        edges: Edges.Bottom | Edges.Right
                        gravity: Edges.Bottom | Edges.Left
                        adjustment: PopupAdjustment.SlideX
                        margins.bottom: 4
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: "#2c2c34"
                        border.color: "#45475a"
                        border.width: 1

                        // ---------- Panel lateral: brillo, energía y multimedia ----------
                        Item {
                            id: ccSide
                            x: 10
                            y: 10
                            width: 248
                            height: parent.height - 20
                            clip: true

                            Column {
                                id: sideCol
                                width: parent.width
                                spacing: 10

                                // ===== Brillo =====
                                Item {
                                    width: parent.width
                                    height: 18

                                    Text {
                                        text: "\u{f185}"
                                        color: "#a6adc8"
                                        font.pixelSize: 13
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: "Brillo"
                                        color: "#ffffff"
                                        font.pixelSize: 12
                                        font.bold: true
                                        anchors.left: parent.left
                                        anchors.leftMargin: 20
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: Math.round(brightSlider.value) + "%"
                                        color: "#a6adc8"
                                        font.pixelSize: 11
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                Slider {
                                    id: brightSlider
                                    width: parent.width
                                    height: 20
                                    from: 1
                                    to: 100
                                    value: ccModule.brightness

                                    onMoved: {
                                        ccModule.brightness = Math.round(value);
                                        brightSetTimer.restart();
                                    }

                                    background: Rectangle {
                                        x: brightSlider.leftPadding
                                        y: brightSlider.topPadding + brightSlider.availableHeight / 2 - height / 2
                                        width: brightSlider.availableWidth
                                        height: 6
                                        radius: 3
                                        color: "#33ffffff"

                                        Rectangle {
                                            width: brightSlider.visualPosition * parent.width
                                            height: parent.height
                                            radius: 3
                                            color: "#1747a9"
                                        }
                                    }

                                    handle: Rectangle {
                                        x: brightSlider.leftPadding + brightSlider.visualPosition * (brightSlider.availableWidth - width)
                                        y: brightSlider.topPadding + brightSlider.availableHeight / 2 - height / 2
                                        width: 16
                                        height: 16
                                        radius: 8
                                        color: brightSlider.pressed ? "#cdd6f4" : "#ffffff"
                                        border.color: "#1747a9"
                                        border.width: 2
                                    }
                                }

                                // ===== Perfil de energía =====
                                Item {
                                    width: parent.width
                                    height: 18

                                    Text {
                                        text: "\u{f0e7}"
                                        color: "#a6adc8"
                                        font.pixelSize: 13
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: "Perfil de energía"
                                        color: "#ffffff"
                                        font.pixelSize: 12
                                        font.bold: true
                                        anchors.left: parent.left
                                        anchors.leftMargin: 20
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                Row {
                                    width: parent.width
                                    spacing: 5

                                    Repeater {
                                        model: ccModule.powerProfiles

                                        Rectangle {
                                            width: (sideCol.width - 10) / 3
                                            height: 24
                                            radius: 5
                                            color: ccModule.powerProfile === modelData.key ? "#1747a9"
                                                 : (profMouse.containsMouse ? "#45475a" : "#33ffffff")
                                            Behavior on color { ColorAnimation { duration: 100 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.label
                                                color: ccModule.powerProfile === modelData.key ? "#ffffff" : "#cdd6f4"
                                                font.pixelSize: 10
                                                font.bold: ccModule.powerProfile === modelData.key
                                            }

                                            MouseArea {
                                                id: profMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: ccModule.setProfile(modelData.key)
                                            }
                                        }
                                    }
                                }

                                Rectangle { width: parent.width; height: 1; color: "#26ffffff" }

                                // ===== Reproductor multimedia =====
                                Item {
                                    width: parent.width
                                    height: 18

                                    Text {
                                        text: "\u{f001}"
                                        color: "#a6adc8"
                                        font.pixelSize: 13
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: "Reproductor"
                                        color: "#ffffff"
                                        font.pixelSize: 12
                                        font.bold: true
                                        anchors.left: parent.left
                                        anchors.leftMargin: 20
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        visible: ccModule.mediaPlayer !== null
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: ccModule.mediaAppLabel(ccModule.mediaPlayer)
                                        color: "#a6adc8"
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                        width: 80
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }

                                // Selector: solo aparece si hay más de un reproductor abierto
                                Row {
                                    visible: ccModule.mediaPlayers.length > 1
                                    width: parent.width
                                    spacing: 5

                                    Repeater {
                                        model: ccModule.mediaPlayers

                                        Rectangle {
                                            width: Math.min(110, (sideCol.width - 5 * (ccModule.mediaPlayers.length - 1)) / ccModule.mediaPlayers.length)
                                            height: 20
                                            radius: 5
                                            color: ccModule.mediaPlayer && ccModule.mediaPlayer.dbusName === modelData.dbusName
                                                 ? "#1747a9"
                                                 : (playerMouse.containsMouse ? "#45475a" : "#33ffffff")
                                            Behavior on color { ColorAnimation { duration: 100 } }

                                            Text {
                                                anchors.centerIn: parent
                                                width: parent.width - 8
                                                text: ccModule.mediaAppLabel(modelData)
                                                color: ccModule.mediaPlayer && ccModule.mediaPlayer.dbusName === modelData.dbusName
                                                     ? "#ffffff" : "#cdd6f4"
                                                font.pixelSize: 9
                                                font.bold: ccModule.mediaPlayer && ccModule.mediaPlayer.dbusName === modelData.dbusName
                                                elide: Text.ElideRight
                                                horizontalAlignment: Text.AlignHCenter
                                            }

                                            MouseArea {
                                                id: playerMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: ccModule.mediaPlayerId = modelData.dbusName
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    height: ccModule.mediaPlayer ? 104 : 30
                                    radius: 6
                                    color: "#1e1e26"
                                    border.color: "#26ffffff"
                                    border.width: 1

                                    Text {
                                        visible: ccModule.mediaPlayer === null
                                        anchors.centerIn: parent
                                        text: "Sin reproductor activo"
                                        color: "#a6adc8"
                                        font.pixelSize: 10
                                    }

                                    Column {
                                        visible: ccModule.mediaPlayer !== null
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 3

                                        Text {
                                            width: parent.width
                                            text: ccModule.mediaPlayer ? (ccModule.mediaPlayer.trackTitle || "Sin título") : ""
                                            color: "#ffffff"
                                            font.pixelSize: 11
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            width: parent.width
                                            text: {
                                                var p = ccModule.mediaPlayer;
                                                if (!p) return "";
                                                if (p.trackArtist) return p.trackArtist;
                                                if (p.trackAlbum) return p.trackAlbum;
                                                return p.identity;
                                            }
                                            color: "#a6adc8"
                                            font.pixelSize: 9
                                            elide: Text.ElideRight
                                        }

                                        // Barra de progreso (clic para buscar)
                                        Item {
                                            width: parent.width
                                            height: 8

                                            Rectangle {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: parent.width
                                                height: 4
                                                radius: 2
                                                color: "#33ffffff"

                                                Rectangle {
                                                    width: parent.width * ccModule.mediaProgress()
                                                    height: parent.height
                                                    radius: 2
                                                    color: "#1747a9"
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                enabled: ccModule.mediaPlayer !== null && ccModule.mediaPlayer.canSeek
                                                onClicked: (mouse) => {
                                                    var p = ccModule.mediaPlayer;
                                                    if (p && p.length > 0)
                                                        p.position = Math.max(0, Math.min(1, mouse.x / width)) * p.length;
                                                }
                                            }
                                        }

                                        // Tiempos
                                        Item {
                                            width: parent.width
                                            height: 10

                                            Text {
                                                text: ccModule.mediaPlayer ? ccModule.fmtTime(ccModule.mediaPlayer.position) : "0:00"
                                                color: "#a6adc8"
                                                font.pixelSize: 9
                                            }

                                            Text {
                                                anchors.right: parent.right
                                                text: ccModule.mediaPlayer ? ccModule.fmtTime(ccModule.mediaPlayer.length) : "0:00"
                                                color: "#a6adc8"
                                                font.pixelSize: 9
                                            }
                                        }

                                        // Controles
                                        Item {
                                            width: parent.width
                                            height: 22

                                            Row {
                                                anchors.centerIn: parent
                                                spacing: 22

                                                Text {
                                                    text: "\u{f04ae}"
                                                    color: ccModule.mediaPlayer && ccModule.mediaPlayer.canGoPrevious ? "#cdd6f4" : "#5a5a6a"
                                                    font.pixelSize: 15
                                                    anchors.verticalCenter: parent.verticalCenter

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        anchors.margins: -6
                                                        cursorShape: Qt.PointingHandCursor
                                                        enabled: ccModule.mediaPlayer !== null && ccModule.mediaPlayer.canGoPrevious
                                                        onClicked: if (ccModule.mediaPlayer) ccModule.mediaPlayer.previous()
                                                    }
                                                }

                                                Text {
                                                    text: ccModule.mediaPlayer && ccModule.mediaPlayer.isPlaying ? "\u{f03e4}" : "\u{f040a}"
                                                    color: ccModule.mediaPlayer && ccModule.mediaPlayer.canTogglePlaying ? "#ffffff" : "#5a5a6a"
                                                    font.pixelSize: 19
                                                    anchors.verticalCenter: parent.verticalCenter

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        anchors.margins: -6
                                                        cursorShape: Qt.PointingHandCursor
                                                        enabled: ccModule.mediaPlayer !== null && ccModule.mediaPlayer.canTogglePlaying
                                                        onClicked: if (ccModule.mediaPlayer) ccModule.mediaPlayer.togglePlaying()
                                                    }
                                                }

                                                Text {
                                                    text: "\u{f04ad}"
                                                    color: ccModule.mediaPlayer && ccModule.mediaPlayer.canGoNext ? "#cdd6f4" : "#5a5a6a"
                                                    font.pixelSize: 15
                                                    anchors.verticalCenter: parent.verticalCenter

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        anchors.margins: -6
                                                        cursorShape: Qt.PointingHandCursor
                                                        enabled: ccModule.mediaPlayer !== null && ccModule.mediaPlayer.canGoNext
                                                        onClicked: if (ccModule.mediaPlayer) ccModule.mediaPlayer.next()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Separador entre el panel lateral y la columna principal
                        Rectangle {
                            x: 10 + 248 + 9
                            y: 10
                            width: 1
                            height: parent.height - 20
                            color: "#26ffffff"
                        }

                        Flickable {
                            anchors.fill: parent
                            anchors.margins: 10
                            anchors.leftMargin: 10 + 248 + 20
                            contentHeight: ccCol.implicitHeight
                            clip: true

                            Column {
                                id: ccCol
                                width: parent.width
                                spacing: 8

                                // ---------- Cabecera ----------
                                Item {
                                    width: parent.width
                                    height: 22

                                    Text {
                                        text: "Centro de control"
                                        color: "#ffffff"
                                        font.pixelSize: 14
                                        font.bold: true
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                Rectangle { width: parent.width; height: 1; color: "#33ffffff" }

                                // ---------- WiFi ----------
                                Item {
                                    width: parent.width
                                    height: 22

                                    Text {
                                        id: wifiTitle
                                        text: "WiFi"
                                        color: "#ffffff"
                                        font.pixelSize: 13
                                        font.bold: true
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: ccModule.wifiStateLabel()
                                        color: "#a6adc8"
                                        font.pixelSize: 10
                                        anchors.left: wifiTitle.right
                                        anchors.leftMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Row {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6

                                        CcButton {
                                            visible: ccModule.wifiPowered
                                            label: ccModule.wifiScanning ? "Buscando…" : "Escanear"
                                            anchors.verticalCenter: parent.verticalCenter
                                            onClicked: ccModule.scanWifi()
                                        }

                                        CcSwitch {
                                            anchors.verticalCenter: parent.verticalCenter
                                            checked: ccModule.wifiPowered
                                            onToggled: ccModule.setWifiPower(!ccModule.wifiPowered)
                                        }
                                    }
                                }

                                // Lista de redes visibles
                                Column {
                                    width: parent.width
                                    spacing: 2
                                    visible: ccModule.wifiPowered

                                    Text {
                                        visible: ccModule.wifiNets.length === 0
                                        text: "Sin redes disponibles"
                                        color: "#a6adc8"
                                        font.pixelSize: 11
                                    }

                                    Repeater {
                                        model: ccModule.wifiNets

                                        Rectangle {
                                            width: ccCol.width
                                            height: 30
                                            radius: 6
                                            color: netMouse.containsMouse ? "#33ffffff" : "transparent"
                                            Behavior on color { ColorAnimation { duration: 100 } }

                                            Text {
                                                id: netIcon
                                                text: ccModule.wifiIconFor(modelData.dbm)
                                                color: modelData.connected ? "#a6e3a1" : "#cdd6f4"
                                                font.pixelSize: 15
                                                font.family: "SF Pro Text"
                                                anchors.left: parent.left
                                                anchors.leftMargin: 8
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Text {
                                                text: modelData.name
                                                color: modelData.connected ? "#a6e3a1" : "#ffffff"
                                                font.pixelSize: 12
                                                elide: Text.ElideRight
                                                width: parent.width - 110
                                                anchors.left: netIcon.right
                                                anchors.leftMargin: 8
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Text {
                                                text: modelData.connected ? "Conectado" : (modelData.type !== "open" ? "󰌾" : "")
                                                color: modelData.connected ? "#a6e3a1" : "#a6adc8"
                                                font.pixelSize: modelData.connected ? 10 : 13
                                                font.family: "SF Pro Text"
                                                anchors.right: parent.right
                                                anchors.rightMargin: 8
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            MouseArea {
                                                id: netMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (!modelData.connected)
                                                        ccModule.connectWifi(modelData.hex, modelData.type);
                                                }
                                            }
                                        }
                                    }
                                }

                                // Acciones de la red conectada (desconectar / olvidar)
                                Item {
                                    width: parent.width
                                    height: ccModule.wifiConnectedName !== "" ? 22 : 0
                                    visible: height > 0

                                    Text {
                                        text: ccModule.wifiConnectedName
                                        color: "#a6e3a1"
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                        width: parent.width - 145
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Row {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6

                                        CcButton {
                                            label: "Desconectar"
                                            anchors.verticalCenter: parent.verticalCenter
                                            onClicked: ccModule.disconnectWifi()
                                        }

                                        CcButton {
                                            label: "Olvidar"
                                            txtColor: "#f38ba8"
                                            anchors.verticalCenter: parent.verticalCenter
                                            onClicked: {
                                                for (var i = 0; i < ccModule.wifiNets.length; i++) {
                                                    if (ccModule.wifiNets[i].connected && ccModule.wifiNets[i].known)
                                                        ccModule.forgetWifi(ccModule.wifiNets[i].hex, ccModule.wifiNets[i].type);
                                                }
                                            }
                                        }
                                    }
                                }

                                // Campo de contraseña para redes desconocidas
                                Item {
                                    width: parent.width
                                    height: ccModule.pendingSsid !== "" ? passCol.implicitHeight + 12 : 0
                                    visible: height > 0

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 6
                                        color: "#1e1e26"
                                        border.color: "#33ffffff"
                                        border.width: 1

                                        Column {
                                            id: passCol
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            spacing: 5

                                            Text {
                                                width: parent.width
                                                text: "Contraseña de «" + ccModule.pendingSsid + "»"
                                                color: "#cdd6f4"
                                                font.pixelSize: 11
                                                elide: Text.ElideRight
                                            }

                                            Row {
                                                width: parent.width
                                                spacing: 6

                                                Item {
                                                    width: parent.width - passBtn.width - cancelPassBtn.width - 12
                                                    height: 24

                                                    Text {
                                                        visible: passInput.text === ""
                                                        text: "Escribe la contraseña…"
                                                        color: "#a6adc8"
                                                        font.pixelSize: 11
                                                        anchors.left: parent.left
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }

                                                    TextInput {
                                                        id: passInput
                                                        anchors.fill: parent
                                                        color: "#ffffff"
                                                        font.pixelSize: 12
                                                        echoMode: TextInput.Password
                                                        verticalAlignment: TextInput.AlignVCenter
                                                        focus: ccPopup.visible && ccModule.pendingSsid !== ""
                                                        Keys.onReturnPressed: ccModule.connectWithPass(text)
                                                        Keys.onEnterPressed: ccModule.connectWithPass(text)
                                                    }
                                                }

                                                CcButton {
                                                    id: passBtn
                                                    label: "Conectar"
                                                    txtColor: "#a6e3a1"
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    onClicked: ccModule.connectWithPass(passInput.text)
                                                }

                                                CcButton {
                                                    id: cancelPassBtn
                                                    label: "Cancelar"
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    onClicked: {
                                                        ccModule.pendingSsid = "";
                                                        ccModule.wifiError = "";
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Mensaje de error del WiFi
                                Text {
                                    visible: ccModule.wifiError !== "" && ccModule.wifiPowered
                                    width: parent.width
                                    text: ccModule.wifiError
                                    color: "#f38ba8"
                                    font.pixelSize: 10
                                }

                                Rectangle { width: parent.width; height: 1; color: "#33ffffff" }

                                // ---------- Bluetooth ----------
                                Item {
                                    width: parent.width
                                    height: 22

                                    Text {
                                        id: btTitle
                                        text: "Bluetooth"
                                        color: "#ffffff"
                                        font.pixelSize: 13
                                        font.bold: true
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Row {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6

                                        CcButton {
                                            visible: ccModule.btEnabled
                                            label: ccModule.btAdapter && ccModule.btAdapter.discovering ? "Detener" : "Buscar"
                                            anchors.verticalCenter: parent.verticalCenter
                                            onClicked: {
                                                if (ccModule.btAdapter)
                                                    ccModule.btAdapter.discovering = !ccModule.btAdapter.discovering;
                                            }
                                        }

                                        CcSwitch {
                                            anchors.verticalCenter: parent.verticalCenter
                                            checked: ccModule.btEnabled
                                            onToggled: ccModule.setBtPower(!ccModule.btEnabled)
                                        }
                                    }
                                }

                                Text {
                                    visible: !ccModule.btEnabled
                                    width: parent.width
                                    text: "Bluetooth desactivado"
                                    color: "#a6adc8"
                                    font.pixelSize: 11
                                }

                                // Lista de dispositivos Bluetooth
                                Column {
                                    width: parent.width
                                    spacing: 2
                                    visible: ccModule.btEnabled

                                    Text {
                                        visible: ccModule.btAdapter && ccModule.btAdapter.devices.values.length === 0
                                        text: "Sin dispositivos; pulsa «Buscar»"
                                        color: "#a6adc8"
                                        font.pixelSize: 11
                                    }

                                    Repeater {
                                        model: ccModule.btAdapter ? ccModule.btAdapter.devices.values : []

                                        Rectangle {
                                            width: ccCol.width
                                            height: 30
                                            radius: 6
                                            color: devMouse.containsMouse ? "#33ffffff" : "transparent"
                                            Behavior on color { ColorAnimation { duration: 100 } }

                                            Text {
                                                id: devIcon
                                                text: modelData.connected ? "󰂱" : "󰂯"
                                                color: modelData.connected ? "#a6e3a1" : "#cdd6f4"
                                                font.pixelSize: 15
                                                font.family: "SF Pro Text"
                                                anchors.left: parent.left
                                                anchors.leftMargin: 8
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Text {
                                                text: modelData.name
                                                color: modelData.connected ? "#a6e3a1" : "#ffffff"
                                                font.pixelSize: 12
                                                elide: Text.ElideRight
                                                width: parent.width - devIcon.width - stateText.width - forgetDev.width - 34
                                                anchors.left: devIcon.right
                                                anchors.leftMargin: 8
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Text {
                                                id: stateText
                                                text: ccModule.btStateLabel(modelData)
                                                color: modelData.connected ? "#a6e3a1" : "#a6adc8"
                                                font.pixelSize: 10
                                                anchors.right: forgetDev.left
                                                anchors.rightMargin: 8
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            MouseArea {
                                                id: devMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: ccModule.btClick(modelData)
                                            }

                                            Text {
                                                id: forgetDev
                                                visible: (modelData.paired || modelData.bonded) && devMouse.containsMouse
                                                text: "Olvidar"
                                                color: "#f38ba8"
                                                font.pixelSize: 10
                                                anchors.right: parent.right
                                                anchors.rightMargin: 8
                                                anchors.verticalCenter: parent.verticalCenter

                                                MouseArea {
                                                    anchors.fill: parent
                                                    anchors.margins: -4
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: modelData.forget()
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle { width: parent.width; height: 1; color: "#33ffffff" }

                                // ---------- Batería ----------
                                Item {
                                    width: parent.width
                                    height: 20

                                    Text {
                                        text: "Batería"
                                        color: "#ffffff"
                                        font.pixelSize: 13
                                        font.bold: true
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: Math.round(UPower.displayDevice.percentage * 100) + "%"
                                        color: "#ffffff"
                                        font.pixelSize: 12
                                        font.bold: true
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                Row {
                                    width: parent.width
                                    spacing: 8

                                    Text {
                                        id: batState
                                        text: ccModule.batteryStateLabel()
                                        color: ccModule.batteryStateColor()
                                        font.pixelSize: 11
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: ccModule.batteryTimeText()
                                        color: "#a6adc8"
                                        font.pixelSize: 11
                                        horizontalAlignment: Text.AlignRight
                                        width: parent.width - batState.width - 8
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                Text {
                                    width: parent.width
                                    text: "Salud: " + Math.round(UPower.displayDevice.healthPercentage * 100) +
                                          "%  ·  Consumo: " + Math.abs(UPower.displayDevice.changeRate).toFixed(1) + " W"
                                    color: "#a6adc8"
                                    font.pixelSize: 10
                                }

                                Rectangle { width: parent.width; height: 1; color: "#33ffffff" }

                                // ---------- Teclado (idioma es/us) ----------
                                Item {
                                    width: parent.width
                                    height: 22

                                    Text {
                                        text: "Teclado"
                                        color: "#ffffff"
                                        font.pixelSize: 13
                                        font.bold: true
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Row {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6

                                        // Un boton por cada layout de input.kb_layout
                                        Repeater {
                                            model: ccModule.kbLayoutList

                                            CcButton {
                                                label: String(modelData).toUpperCase()
                                                txtColor: ccModule.kbLayout === modelData ? "#ffffff" : "#7f849c"
                                                anchors.verticalCenter: parent.verticalCenter
                                                onClicked: ccModule.setKbLayout(modelData)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    HyprlandFocusGrab {
                        id: ccFocusGrab
                        windows: [ ccPopup ]
                        onCleared: ccPopup.visible = false
                    }
                }
            }
        }
    }
}
