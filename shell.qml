import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Io
import QtQuick.Controls.Basic

ShellRoot {
    
    // ==========================================
    // 1. BARRA PRINCIPAL
    // ==========================================
    PanelWindow {
        id: mainBar
        anchors { top: true; left: true; right: true }
        implicitHeight: 32
        color: '#003b3b47' 
    
        // --- IZQUIERDA: WORKSPACES ---
        Item {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 10
            width: 6 * 38
            height: 20

            Repeater {
                model: 5
                Rectangle {
                    x: index * 38; width: 32; height: 20; radius: 10; color: "#3b3b47" 
                    Text { anchors.centerIn: parent; text: index + 1; color: "#9fa1a4"; font.bold: true }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: Hyprland.dispatch("workspace " + (index + 1))
                    }
                }
            }

            Repeater {
                model: Hyprland.workspaces
                Rectangle {
                    property int wsNum: parseInt(modelData.name)
                    property int validNum: isNaN(wsNum) ? 6 : wsNum
                    property int slotIndex: validNum > 5 ? 5 : (validNum - 1)

                    x: slotIndex * 38; width: 32; height: 20; radius: 10
                    z: modelData.active ? 100 : validNum
                    color: modelData.active ? '#1747a9' : "#45475a"
            
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutExpo } }

                    Rectangle {
                        anchors.fill: parent; radius: parent.radius; color: '#83175bba' 
                        opacity: mouseHandler.hovered ? 0.2 : 0 
                        Behavior on opacity { OpacityAnimator { duration: 150 } }
                    }

                    Text { anchors.centerIn: parent; text: modelData.name; color: modelData.active ? '#ffffff' : "#cdd6f4"; font.bold: true }

                    MouseArea {
                        id: mouseHandler
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                        onClicked: modelData.activate()
                    }
                }
            }
        }

        // --- CENTRO: RELOJ Y CLIMA ---
        Row {
            anchors.centerIn: parent
            spacing: 20 // Espacio entre el reloj y el clima

            // Reloj (Tu codigo original adaptado al Row)
            Text {
                color: "#cdd6f4"
                font.pixelSize: 15
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
                function updateTime() { text = Qt.formatTime(new Date(), "hh:mm") }
                Component.onCompleted: updateTime()
                Timer { interval: 1000; running: true; repeat: true; onTriggered: parent.updateTime() }
            }


            // Clima (Actualiza con la IP)
            Row {
                id: weatherModule // ID para referenciar las funciones desde dentro
                spacing: 5
                anchors.verticalCenter: parent.verticalCenter
                
                Text {
                    id: weatherIcon
                    text: "" // Icono por defecto al cargar
                    color: "#ffffff"
                    font.pixelSize: 16
                    font.family: "JetBrainsMono Nerd Font"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    id: weatherText
                    text: "..."
                    color: "#ffffff"
                    font.pixelSize: 14
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

        // --- DERECHA: MODULOS DE SISTEMA (CPU, RAM, BATERIA) ---
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 10
            spacing: 15 // Espacio entre los diferentes modulos

            
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

                Row {
                    id: volumeRow
                    spacing: 5
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        text: volumeModule.volumeIcon()
                        color: "#ffffff"
                        font.pixelSize: 16
                        font.family: "JetBrainsMono Nerd Font"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: volumeModule.muted ? "Mute" : volumeModule.volume + "%"
                        color: "#ffffff"
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
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
                    implicitWidth: 200
                    implicitHeight: 56

                    anchor {
                        item: volumeModule
                        edges: Edges.Bottom
                        gravity: Edges.Bottom
                        adjustment: PopupAdjustment.None
                        margins.bottom: -8                  // Distancia con la barra superior, asi coincide con mi ventana
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 0
                        color: "#2c2c3456"
                        border.color: "#45475a"
                        border.width: 0.5

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
                                color: "#45475a"

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

            // --- Modulo de Bluetooth ---
            Row {
                spacing: 5
                Text {
                    text: "󰂯" // Glifo de Bluetooth (Nerd Font)
                    color: "#ffffff"
                    font.pixelSize: 16
                    font.family: "JetBrainsMono Nerd Font"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "Activado" // Valor estático temporal
                    color: "#ffffff"
                    font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // --- Modulo de Red (Instantaneo y sincronizado con QML) ---
            Row {
                id: netModule
                spacing: 8

                property real prevRx: 0
                property real prevTx: 0
                property string rxSpeed: "0 KB/s"
                property string txSpeed: "0 KB/s"
                property int signalStrength: 100
                property string wifiIcon: "󰤨"

                function formatBytes(bytes) {
                    if (bytes < 1024) return bytes + " B";
                    else if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + " KB";
                    else return (bytes / (1024 * 1024)).toFixed(1) + " MB";
                }

                function updateWifiIcon(signal) {
                    if (signal > 80) return "󰤨";      // Excelente
                    else if (signal > 60) return "󰤥"; // Buena
                    else if (signal > 40) return "󰤢"; // Media
                    else if (signal > 20) return "󰤟"; // Baja
                    else if (signal > 0) return "󰤯";  // Muy baja
                    else return "󰤮";                 // Sin señal
                }

                Text {
                    text: netModule.wifiIcon 
                    color: "#ffffff"
                    font.pixelSize: 16
                    font.family: "JetBrainsMono Nerd Font"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Row {
                    spacing: 6
                    anchors.verticalCenter: parent.verticalCenter

                    // Bajada (Download)
                    Row {
                        spacing: 2
                        Text { text: "󰁅"; color: "#a6e3a1"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: netModule.rxSpeed; color: "#ffffff"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                    }

                    // Subida (Upload)
                    Row {
                        spacing: 2
                        Text { text: "󰁝"; color: "#f38ba8"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: netModule.txSpeed; color: "#ffffff"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                    }
                }

                Process {
                    id: netProcess
                    command: ["bash", "-c", "iface=$(ip route 2>/dev/null | awk '/default/ {print $5}' | head -n1); [ -z \"$iface\" ] && iface='wlan0'; stats=$(awk -v d=\"$iface:\" '$1==d {print $2, $10}' /proc/net/dev); sig=$(nmcli -t -f ACTIVE,SIGNAL dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2); [ -z \"$sig\" ] && sig=100; echo $stats $sig"]
                    running: false

                    stdout: SplitParser {
                        onRead: data => {
                            let line = data.trim();
                            let parts = line.split(/\s+/);
                            if (parts.length >= 3) {
                                let rx = parseFloat(parts[0]);
                                let tx = parseFloat(parts[1]);
                                let sig = parseInt(parts[2]);

                                if (!isNaN(rx) && !isNaN(tx)) {
                                    if (netModule.prevRx > 0) {
                                        let diffRx = (rx - netModule.prevRx) / 2;
                                        let diffTx = (tx - netModule.prevTx) / 2;

                                        netModule.rxSpeed = netModule.formatBytes(diffRx > 0 ? diffRx : 0) + "/s";
                                        netModule.txSpeed = netModule.formatBytes(diffTx > 0 ? diffTx : 0) + "/s";
                                    }
                                    netModule.prevRx = rx;
                                    netModule.prevTx = tx;
                                }

                                if (!isNaN(sig)) {
                                    netModule.signalStrength = sig;
                                    netModule.wifiIcon = netModule.updateWifiIcon(sig);
                                }
                            }
                        }
                    }
                }

                // El Timer dispara la lectura limpia cada 2 segundos
                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: {
                        if (!netProcess.running) {
                            netProcess.running = true;
                        }
                    }
                }
            }

            // --- Modulo de RAM (Sincronizado con el sistema) ---
            Row {
                spacing: 5
                
                Text {
                    text: "󰘚" // Glifo de chip/memoria (Nerd Font)
                    color: "#ffffff"
                    font.pixelSize: 16
                    font.family: "JetBrainsMono Nerd Font"
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Text {
                    id: ramText
                    text: "..." 
                    color: "#ffffff"
                    font.pixelSize: 14
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
                    font.family: "JetBrainsMono Nerd Font"
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                Text {
                    id: cpuText
                    text: "..." 
                    color: "#ffffff"
                    font.pixelSize: 14
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

            // --- Modulo de Bateria (UPower) ---
            Row {
                spacing: 5
                
                Text {
                    id: batteryIcon
                    color: "#ffffff"
                    font.pixelSize: 16
                    font.family: "JetBrainsNerd Font"
                    anchors.verticalCenter: parent.verticalCenter
                    // Cambia el icono dinamicamente si esta cargando (estado 1 suele ser Charging)

                    text: {
                        // Estado 1 = Cargando, Estado 4 = Completamente Cargado
                        if (UPower.displayDevice.state === 1 || UPower.displayDevice.state === 4) {
                            return "󰂄"; // Icono de cargando
                        }
                        
                        // Si esta descargando (Estado 2), calculamos el icono segun porcentaje
                        let pct = UPower.displayDevice.percentage * 100;
                        if (pct >= 90) return "󰁹"; // 100%
                        if (pct >= 70) return "󰂁"; // 80%
                        if (pct >= 50) return "󰁿"; // 60%
                        if (pct >= 30) return "󰁽"; // 40%
                        if (pct >= 10) return "󰁻"; // 20%
                        return "󰂃";              // Casi vacio
                    }
                }
                
                Text {
                    id: batteryText
                    color: "#ffffff"
                    font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                    // Quickshell actualiza este valor automaticamente mediante D-Bus
                    text: Math.round(UPower.displayDevice.percentage * 100) + "%"
                }
            }
        }
    }
}
