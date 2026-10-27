import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Lanzador de aplicaciones con el estilo de la barra principal.
// Abrir/cerrar:  qs ipc -p ~/.config/quickshell/launcher/shell.qml call launcher toggle

Scope {
    id: root
    property bool open: false

    // ==========================================
    // TEMA macOS (Spotlight / Launchpad)
    // ==========================================
    // Nota (alexg): el lanzador NO sigue a pywal a propósito. Se fija una
    // paleta tipo macOS: material oscuro translúcido, hairlines sutiles y
    // selección gris translúcida. El desenfoque real del fondo lo aporta
    // Hyprland con la layer rule "quickshell-launcher-blur".
    Item {
        id: theme
        property color panel: "#E81D1D1F"      // material oscuro (Spotlight)
        property color panelGrid: "#DB1A1A1C"  // Launchpad: algo más translúcido
        property color border: "#24FFFFFF"     // hairline de 1 px
        property color separator: "#16FFFFFF"  // separador bajo el buscador
        property color fg: "#F5F5F7"           // etiqueta principal (Apple white)
        property color fg_dim: "#9E9EA4"       // etiqueta secundaria
        property color accent: "#0A84FF"       // azul macOS (cursor de texto)
        property color selection: "#2EFFFFFF"  // fila activa (gris translúcido)

        function alpha(colorString, a) {
            let c = Qt.color(colorString);
            return Qt.rgba(c.r, c.g, c.b, a);
        }
    }

    // pywal desactivado para el lanzador: se conserva por si se quisiera
    // volver a sincronizar con el wallpaper (poner running: true y
    // descomentar las asignaciones del SplitParser).
    Process {
        id: pywalLoader
        command: ["sh", "-c", "cat ~/.cache/wal/colors.json 2>/dev/null | tr -d '\n'"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                if (data === "") return;
                try {
                    let j = JSON.parse(data);
                    // theme.bg = j.special.background;
                    // theme.panel = j.special.background;
                    // theme.border = j.colors.color8;
                    // theme.fg = j.special.foreground;
                    // theme.fg_dim = j.colors.color7;
                    // theme.accent = j.colors.color4;
                } catch (e) {}
            }
        }
    }

    // ==========================================
    // IPC Y DATOS
    // ==========================================
    IpcHandler {
        target: "launcher"
        function toggle(): void {
            if (!root.open) root.gridMode = false;
            root.setOpen(!root.open);
        }
        function show(): void {
            root.gridMode = false;
            root.setOpen(true);
        }
        // Abre directamente en rejilla (Launchpad).
        function grid(): void {
            root.gridMode = true;
            root.setOpen(true);
        }
        function hide(): void { root.setOpen(false) }
        // Búsqueda programática (útil para scripts y para probar el lanzador).
        function search(text: string): void {
            root.setOpen(true);
            searchInput.text = text;
            root.filterApps();
            root.startFileSearch();
        }
        function reloadColors(): void { pywalLoader.running = true }
        function reloadApps(): void {
            allApps.clear();
            appReader.running = true;
        }
    }

    // Abre o cierra el lanzador comprobando que la ventana se ha creado.
    function setOpen(value: bool): void {
        root.open = value;
        if (root.open) root.ensureWindow();
    }

    // Quickshell 0.3.2 destruye la superficie layer-shell cada vez que se
    // oculta y puede dejar la instancia desincronizada: la siguiente
    // apertura no crea ninguna ventana y el lanzador deja de responder.
    // Forzar un ciclo completo (cerrar + abrir) recupera la instancia.
    function ensureWindow(): void {
        if (win.backingWindowVisible) return;
        root.open = false;
        root.open = true;
    }

    // Vigilancia: si la ventana muere con el lanzador abierto, se recupera.
    property int missingTicks: 0
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            if (!root.open || win.backingWindowVisible) {
                root.missingTicks = 0;
                return;
            }
            root.missingTicks++;
            if (root.missingTicks >= 2) {
                root.missingTicks = 0;
                root.ensureWindow();
            }
        }
    }

    // Número de filas que se ven a la vez (el resto se alcanza con scroll).
    property int visibleRows: 8
    // Número total de coincidencias (apps + archivos, con scroll).
    property int matchCount: 0
    // Búsqueda de archivos: proceso actual, generación y resultados parciales.
    property var fileProc: null
    property int fileSearchId: 0
    property string fileActiveQuery: ""
    property var fileHits: []
    property var fileHitsSystem: []
    // Alto de cada fila de la lista (ritmo compacto estilo Spotlight).
    property int rowHeight: 46
    // Modo rejilla (estilo Launchpad). Se alterna con el botón del buscador
    // o con Tab; el buscador sigue funcionando igual.
    property bool gridMode: false
    property int gridColumns: 7
    property int gridRowsVisible: 4
    property int gridCellWidth: 108
    property int gridCellHeight: 112
    // Momento (ms) en el que se abrió el lanzador. Evita que un clic o una
    // tecla que llegan justo en el instante de abrirlo lo cierren al momento.
    property int openedAt: 0

    function canAct(): bool {
        return Date.now() - root.openedAt > 350;
    }

    ListModel { id: allApps }
    ListModel { id: filteredApps }
    // Resultados de archivos encontrados con fd (sólo texto de la ruta).
    ListModel { id: filteredFiles }
    // Modelo unificado de la lista: primero las apps y después los archivos.
    ListModel { id: listModel }

    // La búsqueda de archivos espera a que el usuario deje de escribir.
    Timer {
        id: fileDebounce
        interval: 220
        repeat: false
        onTriggered: root.startFileSearch()
    }

    // Cada búsqueda usa su propio Process: así una consulta nueva no mezcla
    // la salida de la anterior (el token identifica cada ejecución).
    Component {
        id: fileProcComponent
        Process {
            id: fileProc
            property string token: ""
            property string stage: ""
            command: []
            running: false
            stdout: SplitParser {
                onRead: data => root.collectFileHit(fileProc.token, fileProc.stage, data)
            }
            onRunningChanged: {
                if (running) return;
                root.finishFileStage(fileProc.token, fileProc.stage);
                fileProc.destroy();
            }
        }
    }

    Process {
        id: appReader
        command: [Quickshell.env("HOME") + "/.config/quickshell/launcher/get_apps.sh"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                // Formato: Nombre <TAB> Ejecutar <TAB> RutaIcono
                let line = data.trim();
                if (line === "") return;
                let parts = line.split("\t");
                if (parts.length < 2) return;
                allApps.append({
                    appName: parts[0],
                    appExec: parts[1],
                    appIcon: parts.length >= 3 ? parts[2] : ""
                });
            }
        }
        onRunningChanged: {
            if (!running) filterApps(); // Llena la lista inicial al terminar de leer
        }
    }

    function filterApps() {
        filteredApps.clear();
        let query = searchInput.text.toLowerCase();
        for (let i = 0; i < allApps.count; i++) {
            let app = allApps.get(i);
            if (app.appName.toLowerCase().includes(query)) {
                // Se cargan todas: la lista se desplaza para verlas todas.
                filteredApps.append(app);
            }
        }
        appList.currentIndex = 0;
        appList.contentY = 0;
        if (gridView) {
            gridView.currentIndex = 0;
            gridView.contentY = 0;
        }
        root.rebuildListModel();
    }

    // Reconstruye la lista visible: primero las apps, después los archivos.
    function rebuildListModel() {
        listModel.clear();
        for (let i = 0; i < filteredApps.count; i++) {
            let app = filteredApps.get(i);
            listModel.append({
                kind: "app",
                title: app.appName,
                icon: app.appIcon,
                exec: app.appExec,
                path: ""
            });
        }
        for (let j = 0; j < filteredFiles.count; j++) {
            let path = filteredFiles.get(j).filePath;
            listModel.append({
                kind: "file",
                title: root.baseName(path),
                icon: "",
                exec: "",
                path: path
            });
        }
        root.matchCount = listModel.count;
        if (appList.currentIndex >= listModel.count)
            appList.currentIndex = Math.max(listModel.count - 1, 0);
    }

    // ------------------------------------------
    // Búsqueda de archivos con fd
    // ------------------------------------------

    function scheduleFileSearch() {
        // Si la consulta es demasiado corta no merece la pena recorrer el disco.
        if (searchInput.text.trim().length < 2) {
            root.clearFileSearch();
            return;
        }
        // Detiene la búsqueda en curso; el temporizador agrupa las pulsaciones.
        if (root.fileProc) {
            root.fileProc.running = false;
            root.fileProc.destroy();
            root.fileProc = null;
        }
        fileDebounce.restart();
    }

    function clearFileSearch() {
        fileDebounce.stop();
        root.fileSearchId++;
        if (root.fileProc) {
            root.fileProc.running = false;
            root.fileProc.destroy();
            root.fileProc = null;
        }
        root.fileHits = [];
        root.fileHitsSystem = [];
        filteredFiles.clear();
        root.rebuildListModel();
    }

    function startFileSearch() {
        let query = searchInput.text.trim();
        fileDebounce.stop();
        if (query.length < 2) {
            root.clearFileSearch();
            return;
        }
        root.fileSearchId++;
        if (root.fileProc) {
            root.fileProc.running = false;
            root.fileProc.destroy();
            root.fileProc = null;
        }
        root.fileHits = [];
        root.fileHitsSystem = [];
        root.fileActiveQuery = query;

        root.launchFileStage("home", query, root.fileSearchId);
    }

    function launchFileStage(stage, query, searchId) {
        let token = searchId + ":" + stage;
        let proc = fileProcComponent.createObject(root, {
            token: token,
            stage: stage
        });
        if (!proc) return;
        root.fileProc = proc;

        let args = [
            "fd", "--color", "never", "--hidden", "--no-ignore", "--type", "f",
            "--fixed-strings", "--ignore-case",
            "--format", token + "\t{}"
        ];

        if (stage === "home") {
            args.push("--max-results", "150");
            args.push("--exclude", ".git", "--exclude", "node_modules",
                      "--exclude", ".cache", "--exclude", "__pycache__",
                      "--exclude", ".venv", "--exclude", "venv",
                      "--exclude", ".tox", "--exclude", "site-packages",
                      "--exclude", ".cargo", "--exclude", ".rustup",
                      "--exclude", ".npm", "--exclude", ".gradle",
                      "--exclude", ".m2", "--exclude", ".local/share/Trash",
                      "--exclude", ".local/share/Steam",
                      "--exclude", ".local/share/lutris",
                      "--exclude", ".local/share/flatpak",
                      "--exclude", ".local/share/nvim",
                      "--exclude", ".local/state",
                      "--exclude", ".oh-my-zsh",
                      "--exclude", ".vscode",
                      "--exclude", ".vscode-server",
                      "--exclude", ".eclipse",
                      "--exclude", "CachedData",
                      "--exclude", "CachedExtensionVSIXs",
                      "--exclude", "History");
            args.push("--", query, Quickshell.env("HOME"));
        } else {
            args.push("--max-results", "100");
            args.push("--exclude", ".git", "--exclude", "node_modules",
                      "--exclude", "__pycache__", "--exclude", ".venv",
                      "--exclude", "venv", "--exclude", ".cache",
                      "--exclude", "man", "--exclude", "locale",
                      "--exclude", "doc", "--exclude", "icons",
                      "--exclude", "pixmaps", "--exclude", "themes",
                      "--exclude", "sounds", "--exclude", "help",
                      "--exclude", "examples", "--exclude", "samples");
            args.push("--", query, "/etc", "/opt", "/srv", "/usr/local", "/usr/share");
        }

        proc.command = args;
        proc.running = true;
    }

    function collectFileHit(token, stage, line) {
        // Ignora líneas de búsquedas anteriores o de otra etapa.
        if (!token.startsWith(root.fileSearchId + ":")) return;
        let tab = line.indexOf("\t");
        if (tab < 0) return;
        let path = line.substring(tab + 1);
        if (path === "") return;
        if (stage === "home") root.fileHits.push(path);
        else root.fileHitsSystem.push(path);
    }

    function finishFileStage(token, stage) {
        if (!token.startsWith(root.fileSearchId + ":")) return;
        if (stage === "home") {
            // Los resultados de casa ya están; se completa con el sistema y
            // se publica todo junto para que el panel no parpadee.
            root.launchFileStage("system", root.fileActiveQuery, root.fileSearchId);
        } else if (stage === "system") {
            root.fileProc = null;
            root.publishFileResults(root.fileHits.concat(root.fileHitsSystem));
        }
    }

    function publishFileResults(paths) {
        filteredFiles.clear();
        let ranked = root.rankFiles(paths, root.fileActiveQuery);
        for (let i = 0; i < ranked.length; i++)
            filteredFiles.append({ filePath: ranked[i] });
        root.rebuildListModel();
    }

    // Ordena por relevancia: nombre que empieza por la consulta, límite de
    // palabra, rutas poco profundas y, sobre todo, archivos dentro de $HOME.
    function rankFiles(paths, query) {
        let q = query.toLowerCase();
        let home = Quickshell.env("HOME") + "/";
        let scored = [];
        for (let i = 0; i < paths.length; i++) {
            let path = paths[i];
            if (!path) continue;
            let base = root.baseName(path).toLowerCase();
            let idx = base.indexOf(q);
            let score;
            if (idx === 0) score = 0;
            else if (idx > 0 && root.isBoundary(base.charAt(idx - 1))) score = 15 + idx;
            else if (idx > 0) score = 60 + idx;
            else score = 300; // coincide sólo en la carpeta
            score += path.split("/").length * 2;
            if (path.startsWith(home)) score -= 25;
            // Las copias de seguridad no deberían tapar el archivo real.
            let lowerPath = path.toLowerCase();
            if (lowerPath.includes("backup")) score += 40;
            if (lowerPath.includes(".bak")) score += 25;
            score += Math.min(base.length, 100) / 25;
            scored.push({ path: path, score: score });
        }
        scored.sort((a, b) => a.score - b.score);
        let out = [];
        let seen = {};
        for (let i = 0; i < scored.length && out.length < 40; i++) {
            let path = scored[i].path;
            if (seen[path]) continue;
            seen[path] = true;
            out.push(path);
        }
        return out;
    }

    function isBoundary(ch) {
        return ch === " " || ch === "." || ch === "-" || ch === "_"
            || ch === "(" || ch === "[" || ch === ",";
    }

    function baseName(path) {
        let i = path.lastIndexOf("/");
        return i >= 0 ? path.substring(i + 1) : path;
    }

    // Glifo de archivo según el tipo (Nerd Font, mismo look monocromo que los
    // iconos simbólicos de macOS).
    function fileGlyph(path) {
        let base = root.baseName(path).toLowerCase();
        let dot = base.lastIndexOf(".");
        let ext = dot >= 0 ? base.substring(dot + 1) : "";
        if (["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg", "avif",
             "heic", "tif", "tiff", "ico", "raw"].includes(ext))
            return "\uf1c5"; // imagen
        if (["mp4", "mkv", "webm", "avi", "mov", "m4v", "mpg", "mpeg"].includes(ext))
            return "\uf1c8"; // vídeo
        if (["mp3", "flac", "ogg", "wav", "m4a", "opus", "aac"].includes(ext))
            return "\uf1c7"; // audio
        if (ext === "pdf") return "\uf1c1"; // PDF
        if (["zip", "tar", "gz", "bz2", "xz", "zst", "7z", "rar", "deb",
             "rpm"].includes(ext))
            return "\uf410"; // archivo comprimido
        return "\uf15b"; // documento
    }

    function prettyDir(path) {
        let i = path.lastIndexOf("/");
        let dir = i > 0 ? path.substring(0, i) : "/";
        let home = Quickshell.env("HOME");
        if (dir === home) return "~";
        if (dir.startsWith(home + "/")) return "~/" + dir.substring(home.length + 1);
        return dir;
    }

    // Mueve la selección y mantiene la fila seleccionada a la vista.
    function moveSelection(delta: int): void {
        if (root.gridMode) {
            if (filteredApps.count === 0) return;
            gridView.currentIndex = Math.max(0, Math.min(gridView.currentIndex + delta, filteredApps.count - 1));
            gridView.positionViewAtIndex(gridView.currentIndex, GridView.Contain);
            return;
        }
        if (listModel.count === 0) return;
        appList.currentIndex = Math.max(0, Math.min(appList.currentIndex + delta, listModel.count - 1));
        appList.positionViewAtIndex(appList.currentIndex, ListView.Contain);
    }

    // Navegación horizontal/vertical dentro de la rejilla.
    function moveGrid(dx: int, dy: int): void {
        if (filteredApps.count === 0) return;
        let idx = gridView.currentIndex + dx + dy * root.gridColumns;
        gridView.currentIndex = Math.max(0, Math.min(idx, filteredApps.count - 1));
        gridView.positionViewAtIndex(gridView.currentIndex, GridView.Contain);
    }

    function toggleGridMode(): void {
        root.gridMode = !root.gridMode;
        if (root.gridMode) {
            gridView.currentIndex = Math.min(appList.currentIndex, Math.max(filteredApps.count - 1, 0));
            gridView.positionViewAtIndex(gridView.currentIndex, GridView.Contain);
        } else {
            appList.currentIndex = Math.min(gridView.currentIndex, Math.max(listModel.count - 1, 0));
            appList.positionViewAtIndex(appList.currentIndex, ListView.Contain);
        }
        // El buscador conserva el foco para poder seguir escribiendo.
        searchInput.forceActiveFocus();
    }

    function currentAppIndex(): int {
        return root.gridMode ? gridView.currentIndex : appList.currentIndex;
    }

    onOpenChanged: {
        if (open) {
            root.openedAt = Date.now();
            searchInput.text = "";
            root.clearFileSearch();
            root.filterApps();
            searchInput.forceActiveFocus();
        } else {
            root.clearFileSearch();
        }
    }

    function launchCurrent() {
        if (!root.canAct()) return;
        let idx = root.currentAppIndex();
        if (idx < 0) return;

        if (root.gridMode) {
            if (idx >= filteredApps.count) return;
            Quickshell.execDetached(["sh", "-c", filteredApps.get(idx).appExec]);
            root.open = false;
            return;
        }

        if (idx >= listModel.count) return;
        let item = listModel.get(idx);
        if (item.kind === "file") {
            Quickshell.execDetached(["xdg-open", item.path]);
        } else {
            Quickshell.execDetached(["sh", "-c", item.exec]);
        }
        root.open = false;
    }

    // ==========================================
    // VENTANA PRINCIPAL
    // ==========================================
    PanelWindow {
        id: win
        visible: root.open
        // NOTA: PanelWindow usa anclas booleanas, no `anchors.fill`
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "launcher"

        // La ventana sólo existe a partir de aquí: hay que pedir el foco
        // cuando se acaba de crear, si no el buscador no recibe las teclas.
        onVisibleChanged: {
            if (!visible) return;
            openAnim.restart();
            searchInput.forceActiveFocus();
        }

        // Entrada suave tipo Spotlight (fade + escala mínima).
        ParallelAnimation {
            id: openAnim
            NumberAnimation {
                target: panel; property: "opacity"
                from: 0; to: 1; duration: 130; easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: panel; property: "scale"
                from: 0.97; to: 1; duration: 160; easing.type: Easing.OutCubic
            }
        }

        // Sin oscurecer en modo lista (Spotlight). En Launchpad se difumina y
        // oscurece el escritorio, como hace macOS.
        Rectangle {
            anchors.fill: parent
            color: root.gridMode ? "#4D000000" : "transparent"
            Behavior on color { ColorAnimation { duration: 180 } }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    // Un clic recibido en el mismo instante en que se abre el
                    // lanzador se considera espurio y no lo cierra.
                    if (root.canAct()) root.open = false;
                }
            }
        }

        // Panel estilo Spotlight: flota cerca de la parte superior y se centra
        // al pasar al modo Launchpad.
        Rectangle {
            id: panel
            width: root.gridMode ? 760 : 660
            height: root.gridMode
                ? 60 + Math.max(1, Math.min(
                    Math.ceil(filteredApps.count / root.gridColumns),
                    root.gridRowsVisible)) * root.gridCellHeight + 14
                : 60 + Math.max(1, Math.min(listModel.count, root.visibleRows)) * root.rowHeight + 10
            x: Math.round((parent.width - width) / 2)
            y: root.gridMode
                ? Math.round((parent.height - height) / 2)
                : Math.round(parent.height * 0.16)
            color: root.gridMode ? theme.panelGrid : theme.panel
            radius: 14
            border.color: theme.border
            border.width: 1
            clip: true
            transformOrigin: Item.Center

            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutExpo } }
            Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutExpo } }
            Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutExpo } }
            Behavior on color { ColorAnimation { duration: 150 } }

            // Consume los clics sobre el propio panel (márgenes, esquinas) para
            // que no lleguen al MouseArea de fuera y cierren el lanzador.
            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            Column {
                id: mainCol
                anchors.fill: parent

                // ---------- Barra de búsqueda ----------
                Rectangle {
                    width: parent.width
                    height: 60
                    color: "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 18
                        anchors.rightMargin: 16
                        spacing: 12

                        Text {
                            text: "\uf002" // lupa
                            color: theme.fg_dim
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        TextInput {
                            id: searchInput
                            width: parent.width - 70
                            height: parent.height
                            anchors.verticalCenter: parent.verticalCenter
                            color: theme.fg
                            font.pixelSize: 19
                            font.family: "SF Pro Text"
                            font.weight: Font.Medium
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            selectByMouse: true
                            selectionColor: theme.alpha(theme.accent, 0.35)
                            selectedTextColor: theme.fg

                            Text {
                                text: "Buscar apps y archivos…"
                                color: theme.alpha(theme.fg_dim, 0.85)
                                font.pixelSize: 19
                                font.family: "SF Pro Text"
                                font.weight: Font.Medium
                                visible: parent.text === ""
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            onTextEdited: {
                                root.filterApps();
                                root.scheduleFileSearch();
                            }

                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Tab) {
                                    root.toggleGridMode();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Down) {
                                    if (root.gridMode) root.moveGrid(0, 1);
                                    else root.moveSelection(1);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Up) {
                                    if (root.gridMode) root.moveGrid(0, -1);
                                    else root.moveSelection(-1);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Left) {
                                    if (root.gridMode) {
                                        root.moveGrid(-1, 0);
                                        event.accepted = true;
                                    }
                                } else if (event.key === Qt.Key_Right) {
                                    if (root.gridMode) {
                                        root.moveGrid(1, 0);
                                        event.accepted = true;
                                    }
                                } else if (event.key === Qt.Key_PageDown) {
                                    root.moveSelection(root.gridMode ? root.gridColumns : root.visibleRows);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_PageUp) {
                                    root.moveSelection(-(root.gridMode ? root.gridColumns : root.visibleRows));
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Home) {
                                    if (root.gridMode) {
                                        gridView.currentIndex = 0;
                                        gridView.positionViewAtIndex(0, GridView.Beginning);
                                    } else {
                                        appList.currentIndex = 0;
                                        appList.positionViewAtIndex(0, ListView.Beginning);
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_End) {
                                    if (root.gridMode) {
                                        gridView.currentIndex = Math.max(filteredApps.count - 1, 0);
                                        gridView.positionViewAtIndex(gridView.currentIndex, GridView.End);
                                    } else {
                                        appList.currentIndex = Math.max(listModel.count - 1, 0);
                                        appList.positionViewAtIndex(appList.currentIndex, ListView.End);
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    launchCurrent();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Escape) {
                                    if (root.canAct()) root.open = false;
                                    event.accepted = true;
                                }
                            }
                        }

                        // Botón para alternar lista / rejilla (estilo Launchpad)
                        Item {
                            width: 30
                            height: 30
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                anchors.fill: parent
                                radius: 7
                                color: gridToggleMouse.containsMouse ? theme.selection : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: root.gridMode ? "\uf03a" : "\uf00a" // lista / rejilla
                                color: theme.fg_dim
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 15
                            }

                            MouseArea {
                                id: gridToggleMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleGridMode()
                            }
                        }
                    }

                    // Hairline inferior del buscador (muy sutil, como Spotlight)
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: theme.separator
                    }
                }

                // ---------- Lista de aplicaciones y archivos ----------
                // El panel ya pinta el material: cada fila sólo añade su
                // selección redondeada, como en Spotlight.
                ListView {
                    id: appList
                    visible: !root.gridMode
                    width: parent.width
                    height: root.gridMode ? 0 : Math.min(listModel.count, root.visibleRows) * root.rowHeight
                    model: listModel
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    currentIndex: 0
                    // Desplazamiento suave con la rueda
                    flickDeceleration: 4000
                    maximumFlickVelocity: 3000

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            launchCurrent();
                            event.accepted = true;
                        }
                    }

                    delegate: Rectangle {
                        required property int index
                        required property string kind
                        required property string title
                        required property string icon
                        required property string exec
                        required property string path

                        width: appList.width
                        height: root.rowHeight
                        color: "transparent"

                        // Selección redondeada (gris translúcido de macOS)
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 6
                            width: parent.width - 12
                            height: parent.height - 8
                            radius: 8
                            color: appList.currentIndex === index ? theme.selection : "transparent"
                            Behavior on color { ColorAnimation { duration: 90 } }
                        }

                        // Separador entre las apps y los archivos
                        Rectangle {
                            anchors.top: parent.top
                            x: 12
                            width: parent.width - 24
                            height: 1
                            color: theme.separator
                            visible: index > 0 && kind === "file"
                                && listModel.get(index - 1).kind === "app"
                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 18
                            spacing: 12

                            // Icono: imagen real de la app o glifo de archivo
                            Item {
                                width: 24
                                height: 24
                                anchors.verticalCenter: parent.verticalCenter

                                Image {
                                    id: listIconImg
                                    anchors.fill: parent
                                    source: (kind === "app" && icon !== "") ? "file://" + icon : ""
                                    sourceSize.width: 24
                                    sourceSize.height: 24
                                    fillMode: Image.PreserveAspectFit
                                    visible: kind === "app" && status === Image.Ready
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: kind === "file"
                                    text: kind === "file" ? root.fileGlyph(path) : ""
                                    color: theme.fg_dim
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 17
                                }

                                // Sin icono: cuadrado con la inicial de la app
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 22
                                    height: 22
                                    radius: 5
                                    color: theme.alpha(theme.fg, 0.12)
                                    visible: kind === "app" && listIconImg.status !== Image.Ready

                                    Text {
                                        anchors.centerIn: parent
                                        text: title.length > 0 ? title.charAt(0).toUpperCase() : "?"
                                        color: theme.fg_dim
                                        font.family: "SF Pro Text"
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                    }
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1
                                width: appList.width - 70

                                Text {
                                    width: parent.width
                                    text: title
                                    color: theme.fg
                                    font.family: "SF Pro Text"
                                    font.pixelSize: 15
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    visible: kind === "file"
                                    text: kind === "file" ? root.prettyDir(path) : ""
                                    color: theme.alpha(theme.fg_dim, 0.9)
                                    font.family: "SF Pro Text"
                                    font.pixelSize: 11
                                    elide: Text.ElideMiddle
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: appList.currentIndex = index
                            onClicked: {
                                appList.currentIndex = index;
                                root.launchCurrent();
                            }
                        }
                    }
                }

                // ---------- Sin resultados ----------
                Text {
                    width: parent.width
                    height: root.rowHeight
                    visible: !root.gridMode && listModel.count === 0
                    text: "Sin resultados"
                    color: theme.fg_dim
                    font.family: "SF Pro Text"
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                // ---------- Rejilla de aplicaciones (estilo Launchpad) ----------
                GridView {
                    id: gridView
                    visible: root.gridMode
                    width: parent.width
                    height: root.gridMode
                        ? Math.max(1, Math.min(
                            Math.ceil(filteredApps.count / root.gridColumns),
                            root.gridRowsVisible)) * root.gridCellHeight
                        : 0
                    cellWidth: Math.floor(width / root.gridColumns)
                    cellHeight: root.gridCellHeight
                    model: filteredApps
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    currentIndex: 0
                    flickDeceleration: 4000
                    maximumFlickVelocity: 3000

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            launchCurrent();
                            event.accepted = true;
                        }
                    }

                    delegate: Item {
                        required property int index
                        required property string appName
                        required property string appIcon

                        width: gridView.cellWidth
                        height: gridView.cellHeight

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 6
                            radius: 14
                            color: gridView.currentIndex === index
                                ? theme.selection
                                : "transparent"
                            Behavior on color { ColorAnimation { duration: 100 } }

                            Column {
                                anchors.centerIn: parent
                                spacing: 8

                                Item {
                                    width: 80
                                    height: 56

                                    Image {
                                        id: gridIconImg
                                        anchors.centerIn: parent
                                        width: 56
                                        height: 56
                                        source: appIcon !== "" ? "file://" + appIcon : ""
                                        sourceSize.width: 56
                                        sourceSize.height: 56
                                        fillMode: Image.PreserveAspectFit
                                        visible: status === Image.Ready
                                    }

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 50
                                        height: 50
                                        radius: 12
                                        color: theme.alpha(theme.fg, 0.12)
                                        visible: gridIconImg.status !== Image.Ready

                                        Text {
                                            anchors.centerIn: parent
                                            text: appName.length > 0 ? appName.charAt(0).toUpperCase() : "?"
                                            color: theme.fg_dim
                                            font.family: "SF Pro Text"
                                            font.pixelSize: 20
                                            font.weight: Font.Medium
                                        }
                                    }
                                }

                                Text {
                                    width: 92
                                    text: appName
                                    color: theme.fg
                                    font.family: "SF Pro Text"
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                    wrapMode: Text.Wrap
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: gridView.currentIndex = index
                            onClicked: {
                                gridView.currentIndex = index;
                                launchCurrent();
                            }
                        }
                    }
                }
            }

            // Indicador de scroll: aparece si hay más apps que filas visibles
            Rectangle {
                id: scrollBar
                // La vista activa cambia entre lista y rejilla.
                property var view: root.gridMode ? gridView : appList
                width: 3
                radius: 2
                color: theme.alpha(theme.fg, 0.22)
                visible: view.contentHeight > view.height + 1
                height: visible ? Math.max(24, view.height * (view.height / view.contentHeight)) : 0
                y: visible
                    ? mainCol.y + view.y
                        + (view.contentY / Math.max(1, view.contentHeight - view.height))
                            * (view.height - height)
                    : 0
                x: parent.width - width - 5
            }
        }
    }
}
