//
//  Haul.swift
//  Haul: a graphical front end for yt-dlp on macOS.
//
//  Copyright (C) 2026 Gabriel Castiglia. Licensed under the GNU GPL, version 2 only.
//  Date: October 20, 2026
//  SPDX-License-Identifier: GPL-2.0-only
//
//  This program is free software: you can redistribute it and/or modify it under the terms of
//  the GNU General Public License, version 2, as published by the Free Software Foundation.
//  It is distributed WITHOUT ANY WARRANTY. See the LICENSE file for details.
//
//  Build and installation: see README.md.
//

import SwiftUI
import AppKit

// Homebrew location on Apple Silicon Macs. Apps launched from the Finder do not inherit the
// Terminal's PATH, so it is added explicitly when yt-dlp is launched; Python, deno and ffmpeg
// come from there.
let carpetaHomebrew = "/opt/homebrew/bin"
let rutaPython = carpetaHomebrew + "/python3"

// yt-dlp ships inside the app (Contents/Resources), pinned to the version it was tested with.
let rutaYtDlp = Bundle.main.path(forResource: "yt-dlp", ofType: nil) ?? ""
let versionYtDlp = Bundle.main.object(forInfoDictionaryKey: "YtDlpVersion") as? String ?? "?"

// The palette derives from the system accent color (System Settings > Appearance), so the
// interface follows any accent change without rebuilding.
let acento = Color.accentColor
let degrade = LinearGradient(colors: [acento, acento.mix(with: .black, by: 0.35)],
                             startPoint: .topLeading, endPoint: .bottomTrailing)

// MARK: - Localization

enum Idioma: String, CaseIterable, Identifiable {
    case en, es
    var id: String { rawValue }
    var nombre: String { self == .en ? "English" : "Español" }
}

// Interface language, chosen from the Language menu and remembered between launches.
// English is the default on first launch. AppleLanguages makes the standard menus (Edit,
// Window, Help) follow the same choice from the next launch on.
final class Ajustes: ObservableObject {
    static let shared = Ajustes()

    @Published var idioma: Idioma {
        didSet { guardar() }
    }

    private init() {
        idioma = Idioma(rawValue: UserDefaults.standard.string(forKey: "idioma") ?? "") ?? .en
        guardar()
    }

    private func guardar() {
        UserDefaults.standard.set(idioma.rawValue, forKey: "idioma")
        UserDefaults.standard.set([idioma.rawValue], forKey: "AppleLanguages")
    }
}

// Returns the text for the current interface language.
func tr(_ es: String, _ en: String) -> String {
    Ajustes.shared.idioma == .es ? es : en
}

// MARK: - Formats

enum Formato: String, CaseIterable, Identifiable {
    case video, audio
    var id: String { rawValue }

    var titulo: String { self == .video ? "Video" : tr("Solo audio", "Audio only") }
    var detalle: String {
        self == .video ? tr("MP4 · mejor calidad", "MP4 · best quality")
                       : tr("MP3 · máxima calidad", "MP3 · highest quality")
    }
    var simbolo: String { self == .video ? "film.stack" : "music.note" }

    // yt-dlp arguments for each format.
    var argumentos: [String] {
        switch self {
        case .video:
            // H.264 + AAC is preferred for QuickTime and iOS compatibility; without this
            // preference YouTube serves AV1 + Opus.
            return ["-f", "bv*+ba/b", "-S", "vcodec:h264,res,acodec:aac",
                    "--merge-output-format", "mp4"]
        case .audio:
            return ["-x", "--audio-format", "mp3", "--audio-quality", "0"]
        }
    }
}

// MARK: - Helpers

// Extracts http(s) links from free text, without duplicates and in order of appearance.
func enlaces(en texto: String) -> [String] {
    guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    else { return [] }
    var vistos = Set<String>()
    var resultado: [String] = []
    for m in detector.matches(in: texto, range: NSRange(texto.startIndex..., in: texto)) {
        guard let url = m.url, ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { continue }
        let s = url.absoluteString
        if vistos.insert(s).inserted { resultado.append(s) }
    }
    return resultado
}

// What a link points to, as far as playlists are concerned. Only YouTube is inspected: links to
// other sites download as they are, one video each.
enum Clase { case video, lista, videoEnLista }

func clasificar(_ enlace: String) -> Clase {
    guard let c = URLComponents(string: enlace), let host = c.host?.lowercased() else { return .video }
    let youtube = host == "youtu.be" || host == "youtube.com" || host.hasSuffix(".youtube.com")
    guard youtube else { return .video }
    let consulta = Dictionary(c.queryItems?.map { ($0.name, $0.value ?? "") } ?? [], uniquingKeysWith: { a, _ in a })
    let ruta = c.path.hasSuffix("/") ? String(c.path.dropLast()) : c.path
    let tieneLista = !(consulta["list"] ?? "").isEmpty
    let tieneVideo = !(consulta["v"] ?? "").isEmpty || host == "youtu.be"
        || ruta.hasPrefix("/shorts/") || ruta.hasPrefix("/live/")
    if tieneLista && tieneVideo { return .videoEnLista }
    if tieneLista || ruta == "/playlist" { return .lista }
    // Channel pages (/@name, /channel/…, /c/…, /user/…) are lists of videos too.
    if ruta.hasPrefix("/@") || ruta.hasPrefix("/channel/") || ruta.hasPrefix("/c/") || ruta.hasPrefix("/user/") {
        return .lista
    }
    return .video
}

// A playlist title made safe as a folder name.
func nombreDeCarpeta(_ titulo: String) -> String {
    var t = titulo.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")
        .trimmingCharacters(in: .whitespaces)
    while t.hasPrefix(".") { t.removeFirst() }
    if t.count > 120 { t = String(t.prefix(120)).trimmingCharacters(in: .whitespaces) }
    return t.isEmpty ? tr("Lista", "Playlist") : t
}

// Normalizes a yt-dlp progress field; unknown values are returned empty.
func limpio(_ s: String) -> String {
    let t = s.trimmingCharacters(in: .whitespaces)
    return t.contains("Unknown") || t == "NA" ? "" : t
}

func duracion(_ s: String) -> String {
    guard let seg = Double(s).map({ Int($0) }) else { return "" }
    let h = seg / 3600, m = (seg % 3600) / 60, r = seg % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, r) : String(format: "%d:%02d", m, r)
}

// Strips the prefixes from a yt-dlp error line.
// Example: "ERROR: [youtube] abc123: Video unavailable" → "Video unavailable".
func mensajeDeError(_ linea: String) -> String {
    var t = String(linea.dropFirst("ERROR:".count)).trimmingCharacters(in: .whitespaces)
    if t.hasPrefix("["), let cierre = t.firstIndex(of: "]") {
        t = String(t[t.index(after: cierre)...]).trimmingCharacters(in: .whitespaces)
        if let dos = t.range(of: ": "), !t[..<dos.lowerBound].contains(" ") {
            t = String(t[dos.upperBound...])
        }
    }
    return t
}

// Friendly wording for the most common yt-dlp errors, in the current interface language.
// Errors are stored as yt-dlp reports them and translated at display time, so they follow
// language changes; anything not listed is shown unchanged.
func traducirError(_ mensaje: String) -> String {
    let conocidos = [
        ("unavailable", "El video no está disponible (borrado, privado o bloqueado).",
                        "The video is unavailable (removed, private or blocked)."),
        ("Private video", "Es un video privado.", "This is a private video."),
        ("Sign in to confirm your age", "Pide confirmar la edad con una cuenta: no se puede descargar así.",
                                        "Age confirmation with an account is required; it cannot be downloaded."),
        ("Unsupported URL", "Ese sitio no está soportado por yt-dlp.", "That site is not supported by yt-dlp."),
        ("is not a valid URL", "Eso no parece un enlace válido.", "That does not look like a valid link."),
        ("Unable to download webpage", "No se pudo abrir la página: revisá la conexión.",
                                       "The page could not be opened; check the connection."),
        ("Requested format is not available", "Ese formato no está disponible para este video.",
                                              "That format is not available for this video."),
        ("Sign in to confirm you", "YouTube pide verificar que no sos un robot: instalá la versión más nueva de Haul.",
                                   "YouTube asks to confirm you are not a bot; install the latest version of Haul."),
        ("does not have a videos tab", "Ese canal no tiene videos para bajar.", "That channel has no videos to download."),
        ("The playlist does not exist", "La lista no existe o es privada.", "The playlist does not exist or is private."),
    ]
    for (patron, es, en) in conocidos where mensaje.localizedCaseInsensitiveContains(patron) {
        return tr(es, en)
    }
    return mensaje
}

// MARK: - Filter

// Checks made on every video before anything is downloaded: instrumentals wait unless the user
// allows them, and a few uploads are dropped without a trace.
enum Filtro {
    private static let video = "J0vUqvfHQeQ"
    private static let titulo = "unreleased"
    private static let canales = ["ahdukejk", "ucyeuetgply8mty8ixja3afq"]

    static func esInstrumental(_ titulo: String?) -> Bool {
        titulo?.localizedCaseInsensitiveContains("instrumental") == true
    }

    // fuentes: channel, channel id, uploader and uploader id, as yt-dlp reports them.
    static func descartado(id: String?, titulo t: String?, fuentes: [String?]) -> Bool {
        if id == video { return true }
        if t?.trimmingCharacters(in: .whitespaces).lowercased() == titulo { return true }
        return fuentes.contains { f in
            guard var f = f?.trimmingCharacters(in: .whitespaces).lowercased() else { return false }
            if f.hasPrefix("@") { f.removeFirst() }
            return canales.contains(f)
        }
    }

    // The same checks as a yt-dlp --match-filters expression, so a held-back video is never
    // downloaded. The "?" lets a video without that field through.
    static func expresion(instrumentales: Bool) -> String {
        var partes = ["id!=?\(video)",
                      "title!~=?(?i)^\\s*\(titulo)\\s*$",
                      "channel!~=?(?i)^\(canales[0])$",
                      "uploader!~=?(?i)^\(canales[0])$",
                      "uploader_id!~=?(?i)^@?\(canales[0])$",
                      "channel_id!=?UCYEUeTgPLy8MtY8iXja3AFQ"]
        if !instrumentales { partes.append("title!~=?(?i)instrumental") }
        return partes.joined(separator: " & ")
    }
}

// MARK: - Queue item

// esperando: a failed attempt waits before the next retry. pausada: an instrumental held back.
enum Etapa: Equatable {
    case enCola, leyendo, preparando, bajando, procesando, esperando, lista, cancelada, pausada
    case fallo(String)

    var activa: Bool { [.leyendo, .preparando, .bajando, .procesando, .esperando].contains(self) }
    var terminada: Bool {
        switch self {
        case .lista, .cancelada, .fallo: return true
        default: return false
        }
    }
}

struct InfoVideo {
    var titulo: String
    var autor: String
    var duracion: String
    var miniatura: URL?
}

@MainActor
final class Elemento: ObservableObject, Identifiable {
    let id = UUID()
    let enlace: String
    let formato: Formato
    let destino: URL

    // Playlist rows: number prefix ("03"), playlist name and position ("3/12").
    var prefijo: String?
    var nombreLista: String?
    var posicion: String?
    // A placeholder row that reads a playlist and is replaced by its videos.
    var esLectura = false

    // A failed download or playlist read is tried again this many times, two seconds apart.
    static let maxReintentos = 4
    @Published var reintentos = 0
    // The last yt-dlp error of the current attempt; with retries left the row does not turn red.
    var ultimoError: String?

    // Set from the metadata yt-dlp prints before downloading (or from the playlist entry).
    var instrumental = false
    var descartado = false
    // The user asked for this instrumental anyway.
    var forzar = false

    // Base name of this download's files (without extension) and the files with that base that
    // already existed when it started, so a cancelled download removes only what it created.
    private var baseArchivo: URL?
    private var previos = Set<String>()

    // Notifies the queue of every stage change so the summary and controls stay current.
    @Published var etapa: Etapa = .enCola { didSet { cola?.objectWillChange.send() } }
    weak var cola: Cola?
    @Published var info: InfoVideo?
    @Published var progreso: Double = 0
    @Published var velocidad = ""
    @Published var restante = ""
    @Published var parte = 1
    @Published var archivo: URL?

    var resto = ""          // partial line carried over between pipe reads

    init(enlace: String, formato: Formato, destino: URL) {
        self.enlace = enlace
        self.formato = formato
        self.destino = destino
    }

    var ubicacion: String? { nombreLista.map { "\($0) · \(posicion ?? "")" } }

    // A retry pressed by the user starts over; an automatic one keeps the partial files, which
    // yt-dlp resumes, and the list of files that existed before the first attempt.
    func reiniciar(automatico: Bool = false) {
        etapa = .enCola
        progreso = 0
        velocidad = ""
        restante = ""
        parte = 1
        archivo = nil
        resto = ""
        ultimoError = nil
        if !automatico {
            baseArchivo = nil
            previos = []
            reintentos = 0
        }
    }

    func procesar(_ texto: String) {
        var lineas = (resto + texto).components(separatedBy: "\n")
        resto = lineas.removeLast()
        for linea in lineas {
            let c = linea.components(separatedBy: "\t")
            switch c.first {
            case "META" where c.count >= 7:
                info = InfoVideo(titulo: c[6], autor: c[2] != "NA" ? c[2] : (c[4] != "NA" ? c[4] : ""),
                                 duracion: info?.duracion ?? "",
                                 miniatura: (c.count >= 8 && c[7] != "NA" ? URL(string: c[7]) : nil) ?? info?.miniatura)
                instrumental = Filtro.esInstrumental(c[6])
                descartado = Filtro.descartado(id: c[1], titulo: c[6], fuentes: [c[2], c[3], c[4], c[5]])
            case "INFO" where c.count >= 5:
                info = InfoVideo(titulo: c[1],
                                 autor: c[2] == "NA" ? "" : c[2],
                                 duracion: duracion(c[3]),
                                 miniatura: URL(string: c[4]) ?? info?.miniatura)
                if c.count >= 6, !c[5].isEmpty, c[5] != "NA" { anotar(c[5]) }
            case "AVANCE" where c.count >= 4:
                let numero = c[1].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "%", with: "")
                if let valor = Double(numero) {
                    // In video mode yt-dlp downloads picture and sound separately; a drop in the
                    // percentage marks the start of the second track.
                    if valor / 100 < progreso - 0.5 { parte += 1 }
                    progreso = valor / 100
                    etapa = valor >= 100 ? .procesando : .bajando
                }
                velocidad = limpio(c[2])
                restante = limpio(c[3])
            case "ARCHIVO" where c.count >= 2:
                archivo = URL(fileURLWithPath: c[1])
            default:
                if linea.hasPrefix("ERROR:") {
                    ultimoError = mensajeDeError(linea)
                    if reintentos >= Elemento.maxReintentos { etapa = .fallo(mensajeDeError(linea)) }
                }
            }
        }
    }

    private func anotar(_ nombre: String) {
        let p = nombre.hasPrefix("/") ? URL(fileURLWithPath: nombre) : destino.appendingPathComponent(nombre)
        if p.deletingPathExtension().path == baseArchivo?.path { return }   // a retry of the same file
        baseArchivo = p.deletingPathExtension()
        previos = Set(archivos().map(\.path))
    }

    // Every file named "<base>.<anything>": the final file, the separate picture and sound
    // tracks (".f137.mp4"), partial files (".part", ".part-Frag3", ".ytdl") and ".temp" files.
    private func archivos() -> [URL] {
        guard let base = baseArchivo else { return [] }
        let carpeta = base.deletingLastPathComponent()
        let prefijo = base.lastPathComponent + "."
        let todos = (try? FileManager.default.contentsOfDirectory(at: carpeta, includingPropertiesForKeys: nil)) ?? []
        return todos.filter { $0.lastPathComponent.hasPrefix(prefijo) }
    }

    // Deletes what a cancelled download left behind. Files that existed before it started, such
    // as an earlier download of the same video in another format, are never touched.
    func borrarRestos() {
        for f in archivos() where !previos.contains(f.path) {
            try? FileManager.default.removeItem(at: f)
        }
        baseArchivo = nil
    }

    // After a successful download, removes what yt-dlp could not delete by itself, such as the
    // original audio after converting to MP3 while a file sync client held it
    // open. The final file and files that existed before are kept; a locked file is tried again.
    func borrarIntermedios() {
        guard let final = archivo?.standardizedFileURL.path, baseArchivo != nil else { return }
        Task { @MainActor in
            for _ in 0..<5 {
                let quedan = archivos().filter { !previos.contains($0.path) && $0.standardizedFileURL.path != final }
                if quedan.isEmpty { return }
                for f in quedan { try? FileManager.default.removeItem(at: f) }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    var textoDeEstado: String {
        // While retrying, the attempt is shown first: "Retry 2/4 · 37 % · …".
        let max = Elemento.maxReintentos
        let intento = reintentos > 0 ? tr("Reintento \(reintentos)/\(max)", "Retry \(reintentos)/\(max)") + " · " : ""
        switch etapa {
        case .enCola: return tr("En cola", "Queued") + " · \(formato.titulo)"
        case .leyendo: return intento + tr("Leyendo la lista…", "Reading the playlist…")
        case .preparando: return intento + tr("Preparando…", "Preparing…")
        case .esperando:
            return tr("Falló; reintento \(reintentos) de \(max) en 2 s…", "Failed; retry \(reintentos) of \(max) in 2 s…")
        case .pausada: return tr("En pausa: es un instrumental", "Paused: it is an instrumental")
        case .procesando:
            return intento + (formato == .audio ? tr("Convirtiendo a MP3…", "Converting to MP3…")
                                                : tr("Uniendo imagen y sonido…", "Merging picture and sound…"))
        case .bajando:
            var partes = ["\(Int(progreso * 100)) %"]
            if !velocidad.isEmpty { partes.append(velocidad) }
            if !restante.isEmpty { partes.append(tr("quedan \(restante)", "\(restante) left")) }
            if formato == .video && parte > 1 { partes.append(tr("sonido", "sound")) }
            return intento + partes.joined(separator: " · ")
        case .lista:
            let datos = [info?.autor, info?.duracion].compactMap { $0 }.filter { !$0.isEmpty }
            return datos.isEmpty ? tr("Listo", "Done") : datos.joined(separator: " · ")
        case .cancelada: return tr("Cancelada", "Cancelled")
        case .fallo(let m):
            return traducirError(m) + (reintentos > 0 ? tr(" · \(reintentos) reintentos", " · \(reintentos) retries") : "")
        }
    }
}

// MARK: - Queue

@MainActor
final class Cola: ObservableObject {
    @Published var texto = ""
    @Published var formato: Formato {
        didSet { UserDefaults.standard.set(formato.rawValue, forKey: "formato") }
    }
    @Published var destino: URL {
        didSet { UserDefaults.standard.set(destino.path, forKey: "carpeta") }
    }
    @Published var elementos: [Elemento] = []
    @Published var registro = ""

    // When on, every download that finishes leaves the list by itself. Turning it on also clears
    // what had already finished.
    @Published var limpiarSola: Bool {
        didSet {
            UserDefaults.standard.set(limpiarSola, forKey: "limpiarSola")
            if limpiarSola { limpiarTerminados() }
        }
    }
    // When off, videos with "instrumental" in the title wait in the queue, paused.
    @Published var instrumentales: Bool {
        didSet {
            UserDefaults.standard.set(instrumentales, forKey: "instrumentales")
            for e in elementos where e.instrumental && !e.forzar {
                if instrumentales && e.etapa == .pausada { e.etapa = .enCola }
                else if !instrumentales && e.etapa == .enCola { e.etapa = .pausada }
            }
            siguiente()
        }
    }
    // Finished downloads already removed from the list while the queue still has work, so the
    // summary keeps counting them.
    private var limpias = 0
    // Rows waiting two seconds before their next attempt.
    private var esperas: [ObjectIdentifier: DispatchWorkItem] = [:]

    private var proceso: Process?
    @Published private var actual: Elemento?
    private var ultimoPortapapeles = -1
    // Playlists being read, and rows whose process was stopped by the user.
    @Published private var lecturas: [ObjectIdentifier: Process] = [:]
    private var canceladas = Set<ObjectIdentifier>()

    // Lists longer than this ask for confirmation before filling the queue.
    static let listaGrande = 200

    // Questions shown by the window as alerts. While one is open, the remaining links wait.
    @Published var preguntaLista: String?             // a video opened from a playlist
    @Published var confirmacionGrande: ListaGrande?   // a playlist with many videos
    private var pendientes: [String] = []
    private var esperaGrande: (fila: Elemento, nombre: String, videos: [(enlace: String, info: InfoVideo)])?

    init() {
        // Restores the folder and format from the previous session. If the saved folder no
        // longer exists, Downloads is used.
        let descargas = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        var esCarpeta: ObjCBool = false
        if let guardada = UserDefaults.standard.string(forKey: "carpeta"),
           FileManager.default.fileExists(atPath: guardada, isDirectory: &esCarpeta), esCarpeta.boolValue {
            destino = URL(fileURLWithPath: guardada)
        } else {
            destino = descargas
        }
        formato = Formato(rawValue: UserDefaults.standard.string(forKey: "formato") ?? "") ?? .video
        limpiarSola = UserDefaults.standard.bool(forKey: "limpiarSola")
        instrumentales = UserDefaults.standard.bool(forKey: "instrumentales")
    }

    var ytDlpInstalado: Bool {
        FileManager.default.isExecutableFile(atPath: rutaPython) && FileManager.default.fileExists(atPath: rutaYtDlp)
    }
    var ocupada: Bool { actual != nil || !lecturas.isEmpty }
    var detectados: [String] { enlaces(en: texto) }
    var hayTerminados: Bool { elementos.contains { $0.etapa.terminada } }

    var resumen: String {
        let listas = elementos.filter { $0.etapa == .lista }.count + limpias
        let fallos = elementos.filter { if case .fallo = $0.etapa { return true } else { return false } }.count
        let pausadas = elementos.filter { $0.etapa == .pausada }.count
        // A playlist still being read is not counted yet; one that failed is.
        let total = elementos.filter { !($0.esLectura && $0.etapa.activa) }.count + limpias
        var t = tr("\(listas) de \(total) listas", "\(listas) of \(total) done")
        if fallos > 0 { t += " · " + tr("\(fallos) con error", "\(fallos) failed") }
        if pausadas > 0 { t += " · " + tr("\(pausadas) en pausa", "\(pausadas) paused") }
        return t
    }

    // Adds the links found on the clipboard. In automatic mode it only acts when the field is
    // empty and the clipboard changed since the last read, so processed links are not re-added.
    // Automatic reads require the user to have set clipboard access to "Always Allow"; otherwise
    // the clipboard is read only when Paste is pressed, and the app shows no prompt at launch.
    func tomarDelPortapapeles(forzar: Bool = false) {
        let pp = NSPasteboard.general
        guard forzar || (texto.isEmpty && pp.changeCount != ultimoPortapapeles) else { return }
        if !forzar, #available(macOS 15.4, *), pp.accessBehavior != .alwaysAllow { return }
        ultimoPortapapeles = pp.changeCount
        leerPortapapeles(forzar: forzar)
    }

    // On its own it skips links already in the queue, so a cleared field does not fill up again.
    private func leerPortapapeles(forzar: Bool) {
        let pp = NSPasteboard.general
        let nuevos = enlaces(en: pp.string(forType: .string) ?? "")
        let yaEstan = Set(detectados).union(forzar ? [] : elementos.map(\.enlace))
        let agregar = nuevos.filter { !yaEstan.contains($0) }
        guard !agregar.isEmpty else { return }
        texto = (texto.isEmpty || texto.hasSuffix("\n") ? texto : texto + "\n")
            + agregar.joined(separator: "\n") + "\n"
    }

    func elegirCarpeta() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.directoryURL = destino
        panel.prompt = tr("Elegir", "Choose")
        if panel.runModal() == .OK, let url = panel.url { destino = url }
    }

    func agregar() {
        let nuevos = detectados
        guard !nuevos.isEmpty else { return }
        texto = ""
        // The clipboard that held these links counts as read, so it is not pasted back in.
        ultimoPortapapeles = NSPasteboard.general.changeCount
        pendientes += nuevos
        procesarPendientes()
    }

    // Adds the waiting links in order; stops at a video opened from a playlist until the user answers.
    private func procesarPendientes() {
        while preguntaLista == nil, !pendientes.isEmpty {
            let enlace = pendientes.removeFirst()
            switch clasificar(enlace) {
            case .lista: leer(nuevaFila(enlace, lectura: true))
            case .videoEnLista: preguntaLista = enlace
            case .video: sumar(nuevaFila(enlace))
            }
        }
        siguiente()
    }

    // Answer to the playlist question: the whole playlist (true), only the video (false) or nothing (nil).
    func responderLista(_ entera: Bool?) {
        guard let enlace = preguntaLista else { return }
        preguntaLista = nil
        switch entera {
        case .some(true): leer(nuevaFila(enlace, lectura: true))
        case .some(false): sumar(nuevaFila(enlace))
        case .none: break
        }
        // The next question, if any, opens after this alert has closed.
        DispatchQueue.main.async { self.procesarPendientes() }
    }

    func responderGrande(_ agregar: Bool) {
        confirmacionGrande = nil
        guard let espera = esperaGrande else { return }
        esperaGrande = nil
        if agregar { expandir(espera.fila, nombre: espera.nombre, videos: espera.videos) }
        else { espera.fila.etapa = .cancelada }
    }

    private func nuevaFila(_ enlace: String, lectura: Bool = false) -> Elemento {
        let e = Elemento(enlace: enlace, formato: formato, destino: destino)
        e.esLectura = lectura
        e.cola = self
        return e
    }

    private func sumar(_ e: Elemento, en lugar: Int? = nil) {
        if elementos.isEmpty { limpias = 0 }
        e.cola = self
        if let i = lugar, i <= elementos.count { elementos.insert(e, at: i) } else { elementos.append(e) }
    }

    func quitar(_ e: Elemento) {
        guard !e.etapa.activa else { return }
        elementos.removeAll { $0 === e }
    }

    func cancelar(_ e: Elemento) {
        let id = ObjectIdentifier(e)
        if let w = esperas.removeValue(forKey: id) { w.cancel(); detener(e) }
        else if let p = lecturas[id] { canceladas.insert(id); p.terminate() }
        else if e === actual { canceladas.insert(id); terminarArbol(proceso) }
        else if e.etapa == .enCola { e.etapa = .cancelada }
    }

    func cancelarTodo() {
        for e in elementos where e.etapa == .enCola || e.etapa == .pausada { e.etapa = .cancelada }
        for e in elementos {
            if let w = esperas.removeValue(forKey: ObjectIdentifier(e)) { w.cancel(); detener(e) }
        }
        for (id, p) in lecturas { canceladas.insert(id); p.terminate() }
        if let e = actual { canceladas.insert(ObjectIdentifier(e)); terminarArbol(proceso) }
    }

    // yt-dlp starts ffmpeg as a child process; both are stopped so no file stays open.
    private func terminarArbol(_ p: Process?) {
        guard let p, p.isRunning else { return }
        let hijos = Process()
        hijos.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        hijos.arguments = ["-TERM", "-P", String(p.processIdentifier)]
        try? hijos.run()
        hijos.waitUntilExit()
        p.terminate()
    }

    // Pressed by the user: on a paused instrumental it means "download it anyway".
    func reintentar(_ e: Elemento) {
        if e.etapa == .pausada { e.forzar = true }
        e.reiniciar()
        if e.esLectura { leer(e, yaEnLaCola: true) } else { siguiente() }
    }

    func limpiarTerminados() {
        let quedaTrabajo = elementos.contains { !$0.etapa.terminada }
        limpias = quedaTrabajo ? limpias + elementos.filter { $0.etapa == .lista }.count : 0
        elementos.removeAll { $0.etapa.terminada }
    }

    // With automatic clearing on, a finished or cancelled row leaves the list; failed ones stay.
    private func despedir(_ e: Elemento) {
        guard limpiarSola, e.etapa == .lista || e.etapa == .cancelada else { return }
        if e.etapa == .lista { limpias += 1 }
        elementos.removeAll { $0 === e }
    }

    // A failed attempt is repeated after two seconds, up to Elemento.maxReintentos times. A
    // download keeps its place as the current one meanwhile, so the order of the queue is kept.
    private func reprogramar(_ e: Elemento, _ volver: @escaping () -> Void) {
        e.reintentos += 1
        e.etapa = .esperando
        let id = ObjectIdentifier(e)
        let w = DispatchWorkItem { [weak self, weak e] in
            guard let self, let e, self.esperas.removeValue(forKey: id) != nil else { return }
            e.reiniciar(automatico: true)
            volver()
        }
        esperas[id] = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: w)
    }

    // Stops a row that was waiting for its next attempt.
    private func detener(_ e: Elemento) {
        let eraActual = e === actual
        if eraActual { actual = nil }
        e.borrarRestos()
        e.etapa = .cancelada
        despedir(e)
        if eraActual { siguiente() }
    }

    // Processes the queue serially: the next download starts when the previous one ends.
    private func siguiente() {
        guard actual == nil, let e = elementos.first(where: { $0.etapa == .enCola && !$0.esLectura }) else { return }
        iniciar(e)
    }

    private func iniciar(_ e: Elemento) {
        do {
            try FileManager.default.createDirectory(at: e.destino, withIntermediateDirectories: true)
        } catch {
            actual = nil
            e.etapa = .fallo(tr("No se pudo crear la carpeta: ", "Could not create the folder: ") + error.localizedDescription)
            siguiente()
            return
        }

        let p = Process()
        p.executableURL = URL(fileURLWithPath: rutaPython)
        p.currentDirectoryURL = e.destino
        // Output is requested in a custom, tab-separated format:
        //   META     id, channel, uploader, title and thumbnail, before the match filter (-O pre_process)
        //   INFO     video metadata and file name, before downloading (-O before_dl)
        //   AVANCE   percentage, speed and time remaining (--progress-template)
        //   ARCHIVO  final path, after merging or converting (-O after_move)
        p.arguments = [rutaYtDlp] + e.formato.argumentos + [
            "--newline", "--color", "no_color", "--no-playlist",
            "-o", e.prefijo.map { "\($0) - %(title)s.%(ext)s" } ?? "%(title)s.%(ext)s",
            "--match-filters", Filtro.expresion(instrumentales: instrumentales || e.forzar),
            "--no-simulate", "--progress",
            "--progress-template",
            "download:AVANCE\t%(progress._percent_str)s\t%(progress._speed_str)s\t%(progress._eta_str)s",
            "-O", "pre_process:META\t%(id)s\t%(channel)s\t%(channel_id)s\t%(uploader)s\t%(uploader_id)s\t%(title)s\t%(thumbnail)s",
            "-O", "before_dl:INFO\t%(title)s\t%(uploader)s\t%(duration)s\t%(thumbnail)s\t%(filename)s",
            "-O", "after_move:ARCHIVO\t%(filepath)s",
            "--", e.enlace,
        ]
        var entorno = ProcessInfo.processInfo.environment
        entorno["PATH"] = carpetaHomebrew + ":" + (entorno["PATH"] ?? "/usr/bin:/bin")
        p.environment = entorno

        let tubo = Pipe()
        p.standardOutput = tubo
        p.standardError = tubo
        tubo.fileHandleForReading.readabilityHandler = { [weak self, weak e] h in
            let datos = h.availableData
            guard !datos.isEmpty, let texto = String(data: datos, encoding: .utf8) else { return }
            Task { @MainActor in
                self?.registro += texto
                e?.procesar(texto)
            }
        }
        p.terminationHandler = { [weak self, weak e] proc in
            tubo.fileHandleForReading.readabilityHandler = nil
            let codigo = proc.terminationStatus
            let motivo = proc.terminationReason
            Task { @MainActor in
                guard let self, let e else { return }
                self.terminar(e, codigo: codigo, motivo: motivo)
            }
        }

        registro += "── \(e.enlace) ──\n"
        e.etapa = .preparando
        actual = e
        do {
            try p.run()
            proceso = p
        } catch {
            e.etapa = .fallo(tr("No se pudo arrancar yt-dlp: ", "Could not start yt-dlp: ") + error.localizedDescription)
            actual = nil
            siguiente()
        }
    }

    private func terminar(_ e: Elemento, codigo: Int32, motivo: Process.TerminationReason) {
        proceso = nil
        let cancelada = canceladas.remove(ObjectIdentifier(e)) != nil || motivo == .uncaughtSignal
        let fallo = !cancelada && !e.descartado && (codigo != 0 || e.ultimoError != nil)
        if fallo && e.reintentos < Elemento.maxReintentos {
            reprogramar(e) { [weak self] in self?.iniciar(e) }
            return
        }
        actual = nil
        if cancelada {
            e.borrarRestos()
            e.etapa = .cancelada
            despedir(e)
        } else if e.descartado {
            e.borrarRestos()
            elementos.removeAll { $0 === e }
        } else if codigo == 0 && e.archivo == nil && e.instrumental && !instrumentales && !e.forzar {
            // The match filter held it back: an instrumental, while instrumentals are off.
            e.etapa = .pausada
        } else if codigo == 0 && e.ultimoError == nil {
            e.progreso = 1
            e.etapa = .lista
            e.borrarIntermedios()
            despedir(e)
        } else if case .fallo = e.etapa {
            // The yt-dlp error message was already recorded by procesar(_:).
        } else {
            e.etapa = .fallo(e.ultimoError
                ?? tr("yt-dlp terminó con el código \(codigo). El detalle está en «Detalles técnicos».",
                      "yt-dlp exited with code \(codigo). See \"Technical details\" for more."))
        }
        siguiente()
    }

    // MARK: Playlists

    // Reads a playlist with yt-dlp (--flat-playlist, no download) and replaces the placeholder
    // row with one row per video, saved in a subfolder named after the playlist and numbered in
    // playlist order.
    private func leer(_ fila: Elemento, yaEnLaCola: Bool = false) {
        if !yaEnLaCola { sumar(fila) }
        fila.etapa = .leyendo

        let p = Process()
        p.executableURL = URL(fileURLWithPath: rutaPython)
        p.arguments = [rutaYtDlp, "--flat-playlist", "--yes-playlist", "-J", "--no-warnings", "--", fila.enlace]
        var entorno = ProcessInfo.processInfo.environment
        entorno["PATH"] = carpetaHomebrew + ":" + (entorno["PATH"] ?? "/usr/bin:/bin")
        p.environment = entorno

        // The JSON can be large: it is collected as it arrives so the pipe never fills up.
        let salida = Pipe(), errores = Pipe()
        let datos = Acumulador(), mensajes = Acumulador()
        p.standardOutput = salida
        p.standardError = errores
        salida.fileHandleForReading.readabilityHandler = { h in datos.sumar(h.availableData) }
        errores.fileHandleForReading.readabilityHandler = { h in mensajes.sumar(h.availableData) }
        p.terminationHandler = { [weak self, weak fila] proc in
            salida.fileHandleForReading.readabilityHandler = nil
            errores.fileHandleForReading.readabilityHandler = nil
            datos.sumar(salida.fileHandleForReading.readDataToEndOfFile())
            mensajes.sumar(errores.fileHandleForReading.readDataToEndOfFile())
            let codigo = proc.terminationStatus
            Task { @MainActor in
                guard let self, let fila else { return }
                self.leida(fila, codigo: codigo, json: datos.valor,
                           error: String(decoding: mensajes.valor, as: UTF8.self))
            }
        }

        registro += "── \(fila.enlace) (\(tr("lista", "playlist"))) ──\n"
        do {
            try p.run()
            lecturas[ObjectIdentifier(fila)] = p
        } catch {
            fila.etapa = .fallo(tr("No se pudo arrancar yt-dlp: ", "Could not start yt-dlp: ") + error.localizedDescription)
        }
    }

    private func leida(_ fila: Elemento, codigo: Int32, json: Data, error: String) {
        lecturas[ObjectIdentifier(fila)] = nil
        registro += error
        if canceladas.remove(ObjectIdentifier(fila)) != nil { fila.etapa = .cancelada; return }

        guard codigo == 0 else {
            if fila.reintentos < Elemento.maxReintentos {
                reprogramar(fila) { [weak self] in self?.leer(fila, yaEnLaCola: true) }
                return
            }
            let linea = error.components(separatedBy: "\n").last { $0.hasPrefix("ERROR:") }
            fila.etapa = .fallo(linea.map(mensajeDeError)
                                ?? tr("yt-dlp terminó con el código \(codigo).", "yt-dlp exited with code \(codigo)."))
            return
        }
        guard let raiz = (try? JSONSerialization.jsonObject(with: json)) as? [String: Any] else {
            fila.etapa = .fallo(tr("No se pudo leer la lista.", "Could not read the playlist."))
            return
        }
        guard raiz["_type"] as? String == "playlist", let entradas = raiz["entries"] as? [[String: Any]] else {
            // Not a playlist after all: yt-dlp resolved it to a single video.
            let lugar = elementos.firstIndex { $0 === fila }
            elementos.removeAll { $0 === fila }
            sumar(Elemento(enlace: fila.enlace, formato: fila.formato, destino: fila.destino), en: lugar)
            siguiente()
            return
        }

        let nombre = raiz["title"] as? String ?? ""
        var videos: [(enlace: String, info: InfoVideo)] = []
        for v in entradas {
            let id = v["id"] as? String
            if Filtro.descartado(id: id, titulo: v["title"] as? String,
                                 fuentes: [v["channel"], v["channel_id"], v["uploader"], v["uploader_id"]].map { $0 as? String }) {
                continue
            }
            var enlace = v["url"] as? String ?? v["webpage_url"] as? String
            if enlace?.hasPrefix("http") != true, let id { enlace = "https://www.youtube.com/watch?v=\(id)" }
            guard let enlace else { continue }
            let miniaturas = v["thumbnails"] as? [[String: Any]]
            let dur = (v["duration"] as? NSNumber).map { duracion(String($0.doubleValue)) } ?? ""
            videos.append((enlace, InfoVideo(titulo: v["title"] as? String ?? enlace,
                                             autor: v["channel"] as? String ?? v["uploader"] as? String ?? "",
                                             duracion: dur,
                                             miniatura: (miniaturas?.last?["url"] as? String).flatMap(URL.init(string:)))))
        }
        guard !videos.isEmpty else {
            fila.etapa = .fallo(tr("La lista está vacía.", "The playlist is empty."))
            return
        }
        if videos.count > Cola.listaGrande {
            esperaGrande = (fila, nombre, videos)
            confirmacionGrande = ListaGrande(nombre: nombre.isEmpty ? tr("Lista", "Playlist") : nombre, cantidad: videos.count)
            return
        }
        expandir(fila, nombre: nombre, videos: videos)
    }

    private func expandir(_ fila: Elemento, nombre: String, videos: [(enlace: String, info: InfoVideo)]) {
        let carpeta = fila.destino.appendingPathComponent(nombreDeCarpeta(nombre), isDirectory: true)
        let ancho = max(2, String(videos.count).count)
        let lugar = elementos.firstIndex { $0 === fila }
        elementos.removeAll { $0 === fila }
        for (i, v) in videos.enumerated() {
            let e = Elemento(enlace: v.enlace, formato: fila.formato, destino: carpeta)
            let numero = String(i + 1)
            e.prefijo = String(repeating: "0", count: max(0, ancho - numero.count)) + numero
            e.nombreLista = nombre.isEmpty ? tr("Lista", "Playlist") : nombre
            e.posicion = "\(i + 1)/\(videos.count)"
            e.info = v.info
            e.instrumental = Filtro.esInstrumental(v.info.titulo)
            if e.instrumental && !instrumentales { e.etapa = .pausada }
            sumar(e, en: lugar.map { $0 + i })
        }
        siguiente()
    }
}

struct ListaGrande: Identifiable {
    let id = UUID()
    let nombre: String
    let cantidad: Int
}

// Thread-safe byte buffer for output that arrives on background queues.
final class Acumulador: @unchecked Sendable {
    private var datos = Data()
    private let candado = NSLock()
    func sumar(_ d: Data) { candado.lock(); datos.append(d); candado.unlock() }
    var valor: Data { candado.lock(); defer { candado.unlock() }; return datos }
}

// MARK: - Interface components

// Local boolean view state. Replaces @State because that macro's plugin ships only with Xcode,
// and the project is built with the Command Line Tools.
final class Marca: ObservableObject {
    @Published var valor = false
}

struct Tarjeta<Contenido: View>: View {
    var relleno: CGFloat = 16
    @ViewBuilder var contenido: Contenido
    var body: some View {
        contenido
            .padding(relleno)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.primary.opacity(0.08)))
    }
}

struct BotonFormato: View {
    let formato: Formato
    let elegido: Bool
    let accion: () -> Void
    @StateObject private var encima = Marca()

    var body: some View {
        Button(action: accion) {
            HStack(spacing: 12) {
                Image(systemName: formato.simbolo)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(elegido ? AnyShapeStyle(.white) : AnyShapeStyle(degrade))
                    .frame(width: 38, height: 38)
                    .background(elegido ? AnyShapeStyle(degrade) : AnyShapeStyle(.primary.opacity(0.06)),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(formato.titulo).font(.headline)
                    Text(formato.detalle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(.primary.opacity(encima.valor && !elegido ? 0.05 : 0.0),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(elegido ? AnyShapeStyle(degrade) : AnyShapeStyle(.primary.opacity(0.1)),
                              lineWidth: elegido ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { encima.valor = $0 }
        .animation(.easeOut(duration: 0.15), value: elegido)
    }
}

struct BotonGrande: View {
    let titulo: String
    let simbolo: String
    let activo: Bool
    let accion: () -> Void
    @StateObject private var encima = Marca()

    var body: some View {
        Button(action: accion) {
            Label(titulo, systemImage: simbolo)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(degrade.opacity(activo ? 1 : 0.4), in: Capsule())
                .shadow(color: acento.opacity(activo && encima.valor ? 0.55 : 0.3),
                        radius: encima.valor ? 14 : 8, y: 4)
                .scaleEffect(encima.valor && activo ? 1.01 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!activo)
        .onHover { encima.valor = $0 }
        .animation(.easeOut(duration: 0.15), value: encima.valor)
    }
}

struct BotonIcono: View {
    let simbolo: String
    let ayuda: String
    var color: Color = .secondary
    let accion: () -> Void
    var body: some View {
        Button(action: accion) {
            Image(systemName: simbolo)
                .font(.system(size: 17))
                .foregroundStyle(color)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(ayuda)
    }
}

// A question card: icon tile, title, explanation and the possible answers, in the app's style.
struct TarjetaPregunta: View {
    let simbolo: String
    let titulo: String
    let texto: String
    let detalle: String?
    let principal: String
    let alPrincipal: () -> Void
    let secundario: String?
    let alSecundario: (() -> Void)?
    let alCancelar: () -> Void

    var body: some View {
        Tarjeta {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: simbolo)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(degrade, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 6) {
                    Text(titulo).font(.headline)
                    Text(texto).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    if let detalle {
                        Text(detalle).font(.caption).foregroundStyle(.tertiary).lineLimit(1).truncationMode(.middle)
                    }
                    HStack(spacing: 8) {
                        Button(tr("Cancelar", "Cancel"), action: alCancelar)
                            .keyboardShortcut(.cancelAction)
                        Spacer(minLength: 0)
                        if let secundario, let alSecundario {
                            Button(secundario, action: alSecundario)
                        }
                        Button(principal, action: alPrincipal)
                            .buttonStyle(.borderedProminent)
                            .keyboardShortcut(.defaultAction)
                    }
                    .controlSize(.large)
                    .padding(.top, 6)
                }
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(degrade, lineWidth: 1.5))
    }
}

struct Miniatura: View {
    let url: URL?
    var ancho: CGFloat = 112
    var body: some View {
        AsyncImage(url: url) { img in
            img.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            ZStack {
                degrade.opacity(0.25)
                Image(systemName: "play.rectangle.fill").font(.title2).foregroundStyle(.white.opacity(0.8))
            }
        }
        .frame(width: ancho, height: ancho * 9 / 16)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

struct BarraDeAvance: View {
    let valor: Double
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.08))
                Capsule().fill(degrade)
                    .frame(width: max(6, g.size.width * min(valor, 1)))
                    .animation(.easeOut(duration: 0.25), value: valor)
            }
        }
        .frame(height: 6)
    }
}

struct FilaElemento: View {
    @ObservedObject var e: Elemento
    let cola: Cola

    var body: some View {
        Tarjeta(relleno: 12) {
            HStack(spacing: 12) {
                Miniatura(url: e.info?.miniatura)
                    .opacity(e.etapa == .cancelada ? 0.5 : e.etapa == .pausada ? 0.6 : 1)
                VStack(alignment: .leading, spacing: 6) {
                    Text(e.info?.titulo ?? e.enlace)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(2)
                        .truncationMode(.middle)
                    if let u = e.ubicacion {
                        Text(u).font(.caption).foregroundStyle(.tertiary).lineLimit(1)
                    }
                    if e.etapa == .bajando || e.etapa == .procesando {
                        BarraDeAvance(valor: e.progreso)
                    } else if e.etapa == .preparando || e.etapa == .leyendo || e.etapa == .esperando {
                        ProgressView().controlSize(.mini)
                    }
                    Text(e.textoDeEstado)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(colorDeEstado)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
                Spacer(minLength: 0)
                acciones
            }
        }
    }

    private var colorDeEstado: Color {
        if case .fallo = e.etapa { return .red }
        return .secondary
    }

    @ViewBuilder private var acciones: some View {
        HStack(spacing: 4) {
            switch e.etapa {
            case .enCola:
                BotonIcono(simbolo: "xmark.circle", ayuda: tr("Sacar de la cola", "Remove from queue")) { cola.quitar(e) }
            case .leyendo:
                BotonIcono(simbolo: "stop.circle", ayuda: tr("Dejar de leer la lista", "Stop reading the playlist")) { cola.cancelar(e) }
            case .preparando, .bajando, .procesando, .esperando:
                BotonIcono(simbolo: "stop.circle", ayuda: tr("Cancelar esta descarga", "Cancel this download")) { cola.cancelar(e) }
            case .pausada:
                BotonIcono(simbolo: "arrow.down.circle", ayuda: tr("Descargar igual", "Download anyway"), color: acento) {
                    cola.reintentar(e)
                }
                BotonIcono(simbolo: "xmark.circle", ayuda: tr("Sacar de la lista", "Remove from list")) { cola.quitar(e) }
            case .lista:
                if let archivo = e.archivo {
                    BotonIcono(simbolo: "folder", ayuda: tr("Mostrar en Finder", "Show in Finder")) {
                        NSWorkspace.shared.activateFileViewerSelecting([archivo])
                    }
                    BotonIcono(simbolo: "play.circle.fill", ayuda: tr("Abrir", "Open"), color: acento) {
                        NSWorkspace.shared.open(archivo)
                    }
                } else {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 17)).foregroundStyle(.green)
                }
            case .cancelada, .fallo:
                BotonIcono(simbolo: "arrow.clockwise.circle", ayuda: tr("Probar de nuevo", "Try again"), color: acento) {
                    cola.reintentar(e)
                }
                BotonIcono(simbolo: "xmark.circle", ayuda: tr("Sacar de la lista", "Remove from list")) { cola.quitar(e) }
            }
        }
    }
}

// MARK: - Window

struct Ventana: View {
    @FocusState private var campoEnfocado: Bool
    @StateObject private var cola = Cola()
    @StateObject private var verDetalles = Marca()
    @ObservedObject private var ajustes = Ajustes.shared

    var body: some View {
        ZStack(alignment: .top) {
            // Decorative glow behind the header.
            degrade
                .frame(height: 220)
                .blur(radius: 90)
                .opacity(0.22)
                .offset(y: -90)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
            // The header stays fixed; the rest of the window scrolls under it.
            encabezado
                .padding(.horizontal, 28)
                .padding(.top, 34)
                .padding(.bottom, 14)
                .id(ajustes.idioma)
            ScrollViewReader { desplazar in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !cola.ytDlpInstalado { avisoSinYtDlp }
                    tarjetaEnlaces
                    VStack(alignment: .leading, spacing: 10) {
                        selectorFormato
                        Toggle(tr("Descargar instrumentales", "Download instrumentals"), isOn: $cola.instrumentales)
                            .toggleStyle(.checkbox)
                            .help(tr("Desactivado, los videos con «instrumental» en el título esperan en pausa",
                                     "When off, videos with \"instrumental\" in the title wait, paused"))
                            .padding(.leading, 2)
                        // Kept out of the queue section, which hides itself once the list is empty.
                        Toggle(tr("Limpiar terminadas automáticamente", "Clear finished automatically"), isOn: $cola.limpiarSola)
                            .toggleStyle(.checkbox)
                            .help(tr("Activado, cada descarga terminada sale sola de la lista",
                                     "When on, every finished download leaves the list by itself"))
                            .padding(.leading, 2)
                    }
                    tarjetaDestino
                    BotonGrande(titulo: tituloDelBoton, simbolo: "arrow.down.circle.fill",
                                activo: !cola.detectados.isEmpty && cola.ytDlpInstalado) {
                        campoEnfocado = false
                        cola.agregar()
                    }
                        .keyboardShortcut(.return, modifiers: .command)
                    preguntas.id("pregunta")
                    if !cola.elementos.isEmpty { listaDeLaCola.id("cola") }
                    detalles
                    Text(tr("Haul \(versionHaul) · Motor: yt-dlp \(versionYtDlp), incluido en la app",
                            "Haul \(versionHaul) · Engine: yt-dlp \(versionYtDlp), bundled with the app"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 28)
                .padding(.top, 4)
                .padding(.bottom, 24)
                // Rebuilds the content when the language changes so every text is redrawn.
                .id(ajustes.idioma)
            }
            .scrollBounceBehavior(.basedOnSize)
            // When links are added, scroll to the queue to show progress.
            .onChange(of: cola.elementos.count) { antes, ahora in
                if ahora > antes { withAnimation { desplazar.scrollTo("cola", anchor: .top) } }
            }
            // A question appears in the window itself, so it is scrolled into view.
            // The links field gives up the focus, so Return answers the card instead of adding a line.
            .onChange(of: cola.preguntaLista) { _, ahora in
                if ahora != nil {
                    campoEnfocado = false
                    withAnimation { desplazar.scrollTo("pregunta", anchor: .center) }
                }
            }
            .onChange(of: cola.confirmacionGrande?.id) { _, ahora in
                if ahora != nil {
                    campoEnfocado = false
                    withAnimation { desplazar.scrollTo("pregunta", anchor: .center) }
                }
            }
            }
            }
        }
        .frame(minWidth: 560, idealWidth: 620, minHeight: 560, idealHeight: 780)
        .containerBackground(.thinMaterial, for: .window)
        .onAppear {
            // Launching with links from Terminal or Shortcuts:
            //   open -a Haul --args --descargar URL [URL…]
            let args = CommandLine.arguments
            if let i = args.firstIndex(of: "--descargar") {
                cola.texto = args[(i + 1)...].joined(separator: "\n")
                cola.agregar()
            } else {
                cola.tomarDelPortapapeles()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            cola.tomarDelPortapapeles()
        }
    }

    private var tituloDelBoton: String {
        let n = cola.detectados.count
        if cola.ocupada && n > 0 {
            return n == 1 ? tr("Agregar a la cola", "Add to queue") : tr("Agregar \(n) a la cola", "Add \(n) to queue")
        }
        return n > 1 ? tr("Descargar \(n) enlaces", "Download \(n) links") : tr("Descargar", "Download")
    }

    private var encabezado: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
                .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text("Haul")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text(tr("Una interfaz para yt-dlp", "A front end for yt-dlp"))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button { VentanaAcercaDe.mostrar() } label: {
                Image(systemName: "info.circle").font(.system(size: 17))
            }
            .buttonStyle(.borderless)
            .help(tr("Acerca de Haul", "About Haul"))
            .accessibilityLabel(tr("Acerca de Haul", "About Haul"))
        }
    }

    private var avisoSinYtDlp: some View {
        Tarjeta {
            Label {
                Text(LocalizedStringKey(tr("Falta Python 3 de Homebrew. Abrí la Terminal y escribí: **brew install python deno ffmpeg**",
                                           "Homebrew's Python 3 is missing. Open Terminal and run: **brew install python deno ffmpeg**")))
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            }
        }
    }

    private var tarjetaEnlaces: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "link")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(degrade)
                        .padding(.top, 1)
                    ZStack(alignment: .topLeading) {
                        if cola.texto.isEmpty {
                            Text(tr("Pegá uno o varios enlaces, uno por línea", "Paste one or more links, one per line"))
                                .font(.system(size: 14))
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                        // Locked while a question card is open, so Return answers the card.
                        TextEditor(text: $cola.texto)
                            .focused($campoEnfocado)
                            .disabled(cola.preguntaLista != nil || cola.confirmacionGrande != nil)
                            .font(.system(size: 14))
                            .scrollContentBackground(.hidden)
                            .frame(height: 64)
                    }
                }
                HStack {
                    Text(contador)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !cola.texto.isEmpty {
                        Button(tr("Borrar", "Clear")) { cola.texto = "" }.controlSize(.small)
                    }
                    Button { cola.tomarDelPortapapeles(forzar: true) } label: {
                        Label(tr("Pegar", "Paste"), systemImage: "doc.on.clipboard")
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    private var contador: String {
        let n = cola.detectados.count
        switch n {
        case 0: return cola.texto.isEmpty ? tr("⌘↩ para descargar", "⌘↩ to download")
                                          : tr("No veo ningún enlace", "No links found")
        case 1: return tr("1 enlace · ⌘↩ para descargar", "1 link · ⌘↩ to download")
        default: return tr("\(n) enlaces · ⌘↩ para descargar", "\(n) links · ⌘↩ to download")
        }
    }

    private var selectorFormato: some View {
        HStack(spacing: 12) {
            ForEach(Formato.allCases) { f in
                BotonFormato(formato: f, elegido: cola.formato == f) { cola.formato = f }
            }
        }
    }

    private var tarjetaDestino: some View {
        Tarjeta {
            HStack(spacing: 10) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(degrade)
                VStack(alignment: .leading, spacing: 1) {
                    Text(tr("Guardar en", "Save to")).font(.caption).foregroundStyle(.secondary)
                    Text(cola.destino.lastPathComponent == "Downloads" ? tr("Descargas", "Downloads") : cola.destino.lastPathComponent)
                        .font(.system(size: 14, weight: .medium))
                        .help(cola.destino.path)
                }
                Spacer()
                Button(tr("Cambiar…", "Change…")) { cola.elegirCarpeta() }
                Button { NSWorkspace.shared.open(cola.destino) } label: {
                    Image(systemName: "arrow.up.forward.app")
                }
                .help(tr("Abrir la carpeta en Finder", "Open the folder in Finder"))
            }
        }
    }

    // Questions about playlists, shown as a card in the window rather than as a system alert.
    @ViewBuilder private var preguntas: some View {
        if let enlace = cola.preguntaLista {
            TarjetaPregunta(
                simbolo: "list.bullet.rectangle.portrait",
                titulo: tr("Este video está dentro de una lista", "This video is part of a playlist"),
                texto: tr("Podés bajar solo este video o la lista entera. Con la lista entera, cada video entra a la "
                          + "cola por separado y se guarda en una carpeta con el nombre de la lista, numerado en orden.",
                          "You can download just this video or the whole playlist. With the whole playlist, each video "
                          + "joins the queue on its own and is saved in a folder named after the playlist, in order."),
                detalle: enlace,
                principal: tr("La lista entera", "The whole playlist"), alPrincipal: { cola.responderLista(true) },
                secundario: tr("Solo este video", "Only this video"), alSecundario: { cola.responderLista(false) },
                alCancelar: { cola.responderLista(nil) })
        } else if let l = cola.confirmacionGrande {
            TarjetaPregunta(
                simbolo: "rectangle.stack",
                titulo: tr("Una lista grande", "A large playlist"),
                texto: tr("«\(l.nombre)» tiene \(l.cantidad) videos. ¿Los agrego todos a la cola?",
                          "\"\(l.nombre)\" has \(l.cantidad) videos. Add them all to the queue?"),
                detalle: nil,
                principal: tr("Agregar \(l.cantidad)", "Add \(l.cantidad)"), alPrincipal: { cola.responderGrande(true) },
                secundario: nil, alSecundario: nil,
                alCancelar: { cola.responderGrande(false) })
        }
    }

    private var listaDeLaCola: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(tr("Cola", "Queue")).font(.headline)
                Text(cola.resumen).font(.callout).foregroundStyle(.secondary)
                Spacer()
                if cola.ocupada {
                    Button(tr("Cancelar todo", "Cancel all"), role: .cancel) { cola.cancelarTodo() }.controlSize(.small)
                }
            }
            ForEach(cola.elementos) { e in
                FilaElemento(e: e, cola: cola)
            }
        }
    }

    @ViewBuilder private var detalles: some View {
        if !cola.registro.isEmpty {
            DisclosureGroup(tr("Detalles técnicos", "Technical details"), isExpanded: $verDetalles.valor) {
                ScrollView {
                    Text(cola.registro)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(10)
                }
                .frame(height: 140)
                .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                .padding(.top, 6)
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - About

let repositorio = "https://github.com/Gabriel-Castiglia/haul"
let repositorioWindows = "https://github.com/Gabriel-Castiglia/haul-windows"
let versionHaul = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"

// The About window: version, the meaning of the name, author, license and repository.
struct AcercaDe: View {
    @ObservedObject private var ajustes = Ajustes.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 72, height: 72)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Haul").font(.system(size: 26, weight: .bold, design: .rounded))
                    Text(tr("Versión \(versionHaul) para macOS · yt-dlp \(versionYtDlp)",
                            "Version \(versionHaul) for macOS · yt-dlp \(versionYtDlp)"))
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 4)
            seccion(tr("El nombre", "The name"), tr(
                "«Haul» es una palabra inglesa: quiere decir acarrear algo pesado y también la carga que uno se trae de "
                + "vuelta, como la pesca de un día. Eso hace la app, con yt-dlp de motor: se trae "
                + "la carga a casa.",
                "To haul is to carry something heavy, and a haul is the load you bring back, like a day's catch. That is "
                + "what the app does: with yt-dlp as its engine, it brings the load home."))
            seccion(tr("Autor", "Author"), "Gabriel Castiglia · © 2026")
            seccion(tr("Licencia", "License"), tr(
                "Software libre bajo la Licencia Pública General de GNU, versión 2 (GPL-2.0-only), la misma del núcleo "
                + "Linux. La copia incluida de yt-dlp conserva sus propias licencias (Unlicense y las de sus componentes).",
                "Free software under the GNU General Public License, version 2 (GPL-2.0-only), the same license as the "
                + "Linux kernel. The bundled copy of yt-dlp keeps its own licenses (the Unlicense and those of its components)."))
            VStack(alignment: .leading, spacing: 4) {
                Text(tr("Código fuente", "Source code")).font(.headline)
                Link(String(repositorio.dropFirst("https://".count)), destination: URL(string: repositorio)!)
                Text(tr("Versión para Windows:", "Windows version:")).font(.caption).foregroundStyle(.secondary)
                    .padding(.top, 4)
                Link(String(repositorioWindows.dropFirst("https://".count)), destination: URL(string: repositorioWindows)!)
            }
            HStack {
                Spacer()
                Button(tr("Cerrar", "Close")) { VentanaAcercaDe.cerrar() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 8)
        }
        .padding(28)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .id(ajustes.idioma)
        .onChange(of: ajustes.idioma) { VentanaAcercaDe.retitular() }
    }

    private func seccion(_ titulo: String, _ texto: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titulo).font(.headline)
            Text(texto).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// The About window is created on demand with AppKit: as a SwiftUI Window scene it opened by
// itself at launch.
@MainActor
enum VentanaAcercaDe {
    private static var ventana: NSWindow?

    static func mostrar() {
        if ventana == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: AcercaDe()))
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            ventana = w
        }
        ventana?.title = tr("Acerca de Haul", "About Haul")
        ventana?.center()
        ventana?.makeKeyAndOrderFront(nil)
    }

    static func cerrar() { ventana?.close() }

    static func retitular() { ventana?.title = tr("Acerca de Haul", "About Haul") }
}

// "About Haul" in the app menu opens the same window as the button.
struct MenuAcercaDe: View {
    @ObservedObject private var ajustes = Ajustes.shared
    var body: some View {
        Button(tr("Acerca de Haul", "About Haul")) { VentanaAcercaDe.mostrar() }
    }
}

// MARK: - App

final class Delegado: NSObject, NSApplicationDelegate {
    // The app quits when its only window is closed.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    // With a hidden title bar SwiftUI ignores .defaultSize, so the initial size is set through
    // AppKit; afterwards the window keeps whatever size and position the user chooses.
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async {
            guard let w = NSApp.windows.first else { return }
            if !w.setFrameUsingName("Haul") {
                let alto = min(800, (w.screen?.visibleFrame.height ?? 800) - 40)
                w.setContentSize(NSSize(width: 640, height: alto))
                w.center()
            }
            w.setFrameAutosaveName("Haul")
        }
    }
}

@main
struct HaulApp: App {
    @NSApplicationDelegateAdaptor(Delegado.self) var delegado
    @StateObject private var ajustes = Ajustes.shared

    var body: some Scene {
        Window("Haul", id: "principal") { Ventana() }
            .windowStyle(.hiddenTitleBar)
            .windowResizability(.contentMinSize)
            .commands {
                CommandGroup(replacing: .appInfo) { MenuAcercaDe() }
                CommandMenu(tr("Idioma", "Language")) {
                    Picker(tr("Idioma", "Language"), selection: $ajustes.idioma) {
                        ForEach(Idioma.allCases) { Text($0.nombre).tag($0) }
                    }
                    .pickerStyle(.inline)
                }
            }
    }
}
