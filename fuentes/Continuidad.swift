//
//  Continuidad.swift
//  Haul: a graphical front end for yt-dlp.
//
//  Copyright (C) 2026 Gabriel Castiglia. Licensed under the GNU GPL, version 2 only.
//  Date: November 20, 2026
//  SPDX-License-Identifier: GPL-2.0-only
//
//  This program is free software: you can redistribute it and/or modify it under the terms of
//  the GNU General Public License, version 2, as published by the Free Software Foundation.
//  It is distributed WITHOUT ANY WARRANTY. See the LICENSE file for details.
//
//  What Haul 1.7.0 for Windows brought, on the Mac: the queue kept between sessions, newer copies of yt-dlp
//  downloaded by Haul itself, and the self-test (--self-test), which runs before any window exists.
//

import AppKit
import Foundation

// MARK: - The saved queue

// One row of the queue as it is kept between sessions.
struct FilaGuardada: Codable, Equatable {
    var enlace: String
    var formato = "video"
    var destino: String
    var prefijo: String?
    var nombreLista: String?
    var posicion: String?
    var esLectura = false
    // enCola, detenida (paused by the user), pausada (an instrumental held back) or fallo.
    var etapa = "enCola"
    var fallo: String?
    var titulo: String?
    var autor: String?
    var duracion: String?
    var miniatura: String?
    var instrumental = false
    var forzar = false
    // The files of an unfinished download, so cancelling it later still removes only what it created.
    var baseArchivo: String?
    var previos: [String]?
}

// The rows in order, the links still waiting to be added, and whether the whole queue was paused.
struct EstadoCola: Codable, Equatable {
    var version = 1
    var enPausa = false
    var filas: [FilaGuardada] = []
    var enlaces: [String] = []

    var vacio: Bool { filas.isEmpty && enlaces.isEmpty && !enPausa }
}

// ~/Library/Application Support/Haul/queue.json: the queue that comes back when Haul opens again. It is written to a
// temporary file that then replaces the old one, so a crash or a power cut leaves either the old queue or the new
// one, never half of each. A damaged file is set aside as queue.damaged.json (never lost) and the queue starts empty.
enum ColaGuardada {
    static var carpeta: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Haul", isDirectory: true)
    }
    static var archivo: URL { carpeta.appendingPathComponent("queue.json") }

    private static func esEnlace(_ s: String) -> Bool {
        guard let u = URL(string: s), let e = u.scheme?.lowercased() else { return false }
        return (e == "http" || e == "https") && u.host != nil
    }

    // Writes the queue; an empty queue removes the file.
    static func guardar(_ estado: EstadoCola, en archivo: URL = archivo) throws {
        if estado.vacio {
            try? FileManager.default.removeItem(at: archivo)
            return
        }
        try FileManager.default.createDirectory(at: archivo.deletingLastPathComponent(), withIntermediateDirectories: true)
        let codificador = JSONEncoder()
        codificador.outputFormatting = [.prettyPrinted, .sortedKeys]
        try codificador.encode(estado).write(to: archivo, options: .atomic)
    }

    // Reads the queue. A missing file is an empty queue; a damaged one too, and "danado" says so after the file was
    // renamed. Only web links come back. A file that cannot be read for now (nil) must not be written over.
    static func cargar(_ archivo: URL = archivo, danado: inout Bool) -> EstadoCola? {
        danado = false
        guard FileManager.default.fileExists(atPath: archivo.path) else { return EstadoCola() }
        guard let datos = try? Data(contentsOf: archivo) else { return nil }
        guard var estado = try? JSONDecoder().decode(EstadoCola.self, from: datos) else {
            danado = true
            let aparte = archivo.deletingPathExtension().appendingPathExtension("damaged.json")
            try? FileManager.default.removeItem(at: aparte)
            try? FileManager.default.moveItem(at: archivo, to: aparte)
            return EstadoCola()
        }
        estado.filas = estado.filas.filter { esEnlace($0.enlace) }
        estado.enlaces = estado.enlaces.filter(esEnlace)
        return estado
    }
}

// MARK: - Newer copies of yt-dlp

// The copy of yt-dlp inside the app stays as it was tested. Newer copies come from yt-dlp's official releases on
// GitHub into ~/Library/Application Support/Haul/yt-dlp/<version>/yt-dlp, one folder per version. A copy is kept
// only after its SHA-256 matches the release's SHA2-256SUMS and it answers its own version number; only then the
// folder gets its mark and is used. Downloads already running keep the copy they started with; the next ones use
// the new one. Older folders are removed when Haul starts.
enum MotorYtDlp {
    static let repositorio = "yt-dlp/yt-dlp"
    static let ejecutable = "yt-dlp"
    static let sumas = "SHA2-256SUMS"
    static let marca = "verified.txt"

    // Where the downloaded copies go; the self-test points it to a folder of its own.
    nonisolated(unsafe) static var raiz = ColaGuardada.carpeta.appendingPathComponent("yt-dlp", isDirectory: true)

    // yt-dlp's tags are dates with dots ("2026.09.30", sometimes with a fourth number); only those make a folder.
    static func esEtiqueta(_ s: String) -> Bool {
        s.range(of: #"^\d{4}\.\d{1,2}\.\d{1,2}(\.\d+)?$"#, options: .regularExpression) != nil
    }

    // The newest verified copy in "raiz" that is newer than the one inside the app; nil if there is none.
    static func elegir(_ raiz: URL, incluida: String) -> (ruta: String, version: String)? {
        var mejor: (String, String)?
        var referencia = incluida
        let fm = FileManager.default
        for carpeta in (try? fm.contentsOfDirectory(at: raiz, includingPropertiesForKeys: nil)) ?? [] {
            let nombre = carpeta.lastPathComponent
            let exe = carpeta.appendingPathComponent(ejecutable).path
            guard esEtiqueta(nombre), fm.fileExists(atPath: exe),
                  fm.fileExists(atPath: carpeta.appendingPathComponent(marca).path),
                  SelfUpdate.isNewer(nombre, than: referencia) else { continue }
            mejor = (exe, nombre)
            referencia = nombre
        }
        return mejor
    }

    // Removes every folder in "raiz" except the one of the copy in use, including downloads that never finished.
    static func limpiar(_ raiz: URL, conservar: String?) {
        let fm = FileManager.default
        let dejar = conservar.map { URL(fileURLWithPath: $0).deletingLastPathComponent().standardizedFileURL.path }
        for carpeta in (try? fm.contentsOfDirectory(at: raiz, includingPropertiesForKeys: nil)) ?? [] {
            if carpeta.standardizedFileURL.path == dejar { continue }
            // The mark goes first, so a folder that can only be removed in part is never used again.
            try? fm.removeItem(at: carpeta.appendingPathComponent(marca))
            try? fm.removeItem(at: carpeta)
        }
    }

    // At start: uses the newest verified copy, if any, and removes the others.
    @MainActor
    static func iniciar() {
        let elegida = elegir(raiz, incluida: versionYtDlpIncluida)
        if let e = elegida { rutaYtDlp = e.ruta; versionYtDlp = e.version }
        limpiar(raiz, conservar: elegida?.ruta)
    }

    struct Problema: LocalizedError {
        let texto: String
        var errorDescription: String? { texto }
    }

    private static func pedir(_ url: URL) async throws -> Data {
        var pedido = URLRequest(url: url, timeoutInterval: 60)
        pedido.setValue("Haul/\(versionHaul)", forHTTPHeaderField: "User-Agent")
        let (datos, respuesta) = try await URLSession.shared.data(for: pedido)
        if let codigo = (respuesta as? HTTPURLResponse)?.statusCode, codigo != 200 {
            throw Problema(texto: tr("GitHub respondió \(codigo).", "GitHub answered \(codigo)."))
        }
        return datos
    }

    // Asks GitHub for yt-dlp's latest release and, if it is newer than the copy in use, downloads it, checks it and
    // starts using it. Returns whether there was a new version and the version in use afterwards. Throws with a
    // message for the user if something fails; the copy in use stays as it was.
    @MainActor
    static func actualizar(en raiz: URL = raiz) async throws -> (nueva: Bool, version: String) {
        var pedido = URLRequest(url: URL(string: "https://api.github.com/repos/\(repositorio)/releases/latest")!, timeoutInterval: 15)
        pedido.setValue("Haul/\(versionHaul)", forHTTPHeaderField: "User-Agent")
        pedido.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (json, _) = try await URLSession.shared.data(for: pedido)
        guard let raizJSON = (try? JSONSerialization.jsonObject(with: json)) as? [String: Any],
              let etiqueta = raizJSON["tag_name"] as? String else {
            throw Problema(texto: tr("No se pudo leer la respuesta de GitHub.", "GitHub's answer could not be read."))
        }
        guard SelfUpdate.isNewer(etiqueta, than: versionYtDlp) else { return (false, versionYtDlp) }
        guard esEtiqueta(etiqueta) else {
            throw Problema(texto: tr("La versión publicada de yt-dlp tiene un nombre inesperado: \(etiqueta).",
                                     "The published yt-dlp version has an unexpected name: \(etiqueta)."))
        }
        var urlExe: URL?, urlSumas: URL?
        for a in raizJSON["assets"] as? [[String: Any]] ?? [] {
            guard let n = a["name"] as? String, let u = a["browser_download_url"] as? String, u.hasPrefix("https://") else { continue }
            if n == ejecutable { urlExe = URL(string: u) } else if n == sumas { urlSumas = URL(string: u) }
        }
        guard let urlExe, let urlSumas else {
            throw Problema(texto: tr("La versión \(etiqueta) de yt-dlp no trae \(ejecutable) y \(sumas).",
                                     "yt-dlp \(etiqueta) does not include \(ejecutable) and \(sumas)."))
        }
        let ruta = try await instalar(en: raiz, etiqueta: etiqueta, urlExe: urlExe, urlSumas: urlSumas)
        rutaYtDlp = ruta
        versionYtDlp = etiqueta
        return (true, etiqueta)
    }

    // Downloads and checks one version into its own folder; returns the path of its yt-dlp.
    static func instalar(en raiz: URL, etiqueta: String, urlExe: URL, urlSumas: URL) async throws -> String {
        let fm = FileManager.default
        let temporal = raiz.appendingPathComponent(etiqueta + ".download", isDirectory: true)
        try? fm.removeItem(at: temporal)
        try fm.createDirectory(at: temporal, withIntermediateDirectories: true)
        do {
            guard let esperado = SelfUpdate.hash(for: ejecutable, in: String(decoding: try await pedir(urlSumas), as: UTF8.self)) else {
                throw Problema(texto: tr("La lista de sumas de comprobación no nombra \(ejecutable).", "The checksum list does not name \(ejecutable)."))
            }
            let exe = temporal.appendingPathComponent(ejecutable)
            try await pedir(urlExe).write(to: exe)
            guard try SelfUpdate.sha256(of: exe) == esperado else {
                throw Problema(texto: tr("\(ejecutable) no coincide con su suma de comprobación: se borró sin ejecutarlo.",
                                         "\(ejecutable) does not match its checksum: it was deleted without running it."))
            }
            // The checked file is run once: it must answer the version it was published as.
            let dice = await versionDe(exe.path)
            guard let dice, SelfUpdate.parts(dice) == SelfUpdate.parts(etiqueta) else {
                throw Problema(texto: tr("La copia descargada de yt-dlp dice ser la versión «\(dice ?? "?")», no la \(etiqueta).",
                                         "The downloaded yt-dlp says it is version \"\(dice ?? "?")\", not \(etiqueta)."))
            }
            try Data((esperado + "  " + ejecutable + "\n").utf8).write(to: temporal.appendingPathComponent(marca))
            let final = raiz.appendingPathComponent(etiqueta, isDirectory: true)
            try? fm.removeItem(at: final)
            try fm.moveItem(at: temporal, to: final)
            return final.appendingPathComponent(ejecutable).path
        } catch {
            try? fm.removeItem(at: temporal)
            throw error
        }
    }

    // What "yt-dlp --version" prints, or nil if it does not answer within a minute.
    static func versionDe(_ exe: String) async -> String? {
        await Task.detached { () -> String? in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: rutaPython)
            p.arguments = [exe, "--version"]
            var entorno = ProcessInfo.processInfo.environment
            entorno["PYTHONDONTWRITEBYTECODE"] = "1"
            p.environment = entorno
            let salida = Pipe()
            p.standardOutput = salida
            p.standardError = FileHandle.nullDevice
            guard (try? p.run()) != nil else { return nil }
            let limite = DispatchWorkItem { if p.isRunning { p.terminate() } }
            DispatchQueue.global().asyncAfter(deadline: .now() + 60, execute: limite)
            let datos = salida.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            limite.cancel()
            guard p.terminationStatus == 0 else { return nil }
            return String(decoding: datos, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        }.value
    }

    // Once a day (unless it is turned off in the About window), a little after the start.
    @MainActor
    static func revisarSiToca() async {
        let d = UserDefaults.standard
        guard d.object(forKey: "actualizarYtDlp") as? Bool ?? true else { return }
        let ultima = d.double(forKey: "ultimaBusquedaYtDlp"), ahora = Date().timeIntervalSince1970
        guard ahora - ultima >= 24 * 3600 || ahora < ultima else { return }
        d.set(ahora, forKey: "ultimaBusquedaYtDlp")
        _ = try? await actualizar()
    }
}

// MARK: - Self-test

// Haul --self-test: the saved queue, the version logic of Haul and yt-dlp and the checksum lists, with throw-away
// data in a temporary folder, without a window and without touching the user's settings or queue. It runs from
// HaulApp.init, before any window exists, and exits with the number of failures. --red adds a real yt-dlp update
// into the temporary folder.
@MainActor
enum PruebaPropia {
    static var activa: Bool { CommandLine.arguments.contains("--self-test") }

    static func correr() -> Int32 {
        var fallos: Int32 = 0
        func comprobar(_ que: String, _ bien: Bool) {
            print((bien ? "ok   " : "BAD  ") + que)
            if !bien { fallos += 1 }
        }
        let fm = FileManager.default
        let carpeta = fm.temporaryDirectory.appendingPathComponent("haul-self-test-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try? fm.createDirectory(at: carpeta, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: carpeta) }

        // The saved queue
        let archivo = carpeta.appendingPathComponent("queue.json")
        var danado = false
        comprobar("queue: no file is an empty queue", ColaGuardada.cargar(archivo, danado: &danado)?.vacio == true && !danado)
        var estado = EstadoCola()
        estado.enPausa = true
        estado.filas = [
            FilaGuardada(enlace: "https://example.com/v/1", formato: "audio", destino: "/tmp/a", prefijo: "03", nombreLista: "L",
                         posicion: "3/12", etapa: "detenida", titulo: "T", autor: "A", duracion: "1:00",
                         miniatura: "https://example.com/t.jpg", instrumental: true, forzar: true,
                         baseArchivo: "/tmp/a/T [1]", previos: ["/tmp/a/T [1].mp3"]),
            FilaGuardada(enlace: "https://example.com/v/2", destino: "/tmp/b", etapa: "fallo", fallo: "No."),
            FilaGuardada(enlace: "ftp://example.com/x", destino: "/tmp"),
        ]
        estado.enlaces = ["https://example.com/v/3", "javascript:alert(1)"]
        try? ColaGuardada.guardar(estado, en: archivo)
        let leida = ColaGuardada.cargar(archivo, danado: &danado)
        comprobar("queue: rows, links and the pause come back in order", leida?.filas.count == 2 && leida?.filas[0] == estado.filas[0]
                  && leida?.filas[1] == estado.filas[1] && leida?.enlaces == ["https://example.com/v/3"] && leida?.enPausa == true)
        comprobar("queue: only web links come back", leida?.filas.allSatisfy { $0.enlace.hasPrefix("https://") } == true)
        comprobar("queue: no temporary file is left", (try? fm.contentsOfDirectory(atPath: carpeta.path))?.filter { $0 != "queue.json" }.isEmpty == true)
        try? ColaGuardada.guardar(EstadoCola(), en: archivo)
        comprobar("queue: an empty queue removes the file", !fm.fileExists(atPath: archivo.path))
        try? Data("{ not json".utf8).write(to: archivo)
        let rota = ColaGuardada.cargar(archivo, danado: &danado)
        comprobar("queue: a damaged file is set aside and the queue starts empty",
                  danado && rota?.vacio == true && fm.fileExists(atPath: carpeta.appendingPathComponent("queue.damaged.json").path)
                  && !fm.fileExists(atPath: archivo.path))

        // Versions of Haul and yt-dlp
        comprobar("versions: Haul 1.7.0 is newer than 1.6.0", SelfUpdate.isNewer("v1.7.0", than: "1.6.0"))
        comprobar("versions: yt-dlp 2026.09.30 is newer than 2026.08.19", SelfUpdate.isNewer("2026.09.30", than: "2026.08.19"))
        comprobar("versions: yt-dlp 2026.08.19.1 is newer than 2026.08.19", SelfUpdate.isNewer("2026.08.19.1", than: "2026.08.19"))
        comprobar("versions: yt-dlp tags", MotorYtDlp.esEtiqueta("2026.09.30") && MotorYtDlp.esEtiqueta("2026.09.30.232839")
                  && !MotorYtDlp.esEtiqueta("v2026.09.30") && !MotorYtDlp.esEtiqueta("../x") && !MotorYtDlp.esEtiqueta("2026.9"))
        let sumas = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef  yt-dlp\n"
            + "fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210  yt-dlp.exe\n"
        comprobar("checksums: SHA2-256SUMS of yt-dlp", SelfUpdate.hash(for: "yt-dlp", in: sumas)?.hasPrefix("0123") == true)

        // Choosing and cleaning the downloaded copies
        let raiz = carpeta.appendingPathComponent("yt-dlp", isDirectory: true)
        func copia(_ v: String, marcada: Bool) {
            let c = raiz.appendingPathComponent(v, isDirectory: true)
            try? fm.createDirectory(at: c, withIntermediateDirectories: true)
            fm.createFile(atPath: c.appendingPathComponent("yt-dlp").path, contents: Data("x".utf8))
            if marcada { fm.createFile(atPath: c.appendingPathComponent(MotorYtDlp.marca).path, contents: Data()) }
        }
        copia("2026.07.01", marcada: true); copia("2026.09.30", marcada: true); copia("2026.10.15", marcada: false)
        copia("2026.10.15.download", marcada: true)
        let elegida = MotorYtDlp.elegir(raiz, incluida: "2026.08.19")
        comprobar("yt-dlp: the newest verified copy newer than the bundled one", elegida?.version == "2026.09.30")
        comprobar("yt-dlp: no copy newer than the bundled one", MotorYtDlp.elegir(raiz, incluida: "2026.12.01") == nil)
        MotorYtDlp.limpiar(raiz, conservar: elegida?.ruta)
        comprobar("yt-dlp: the other folders are removed", (try? fm.contentsOfDirectory(atPath: raiz.path)) == ["2026.09.30"])

        for (que, bien) in SelfUpdate.selfTest() { comprobar(que, bien) }

        if CommandLine.arguments.contains("--red") {
            let espera = DispatchSemaphore(value: 0)
            var resultado = "?"
            Task.detached { @MainActor in
                do {
                    let r = try await MotorYtDlp.actualizar(en: raiz)
                    resultado = r.nueva ? "updated to \(r.version)" : "already \(r.version)"
                } catch { resultado = "FAILED: \(error.localizedDescription)" }
                espera.signal()
            }
            while espera.wait(timeout: .now()) == .timedOut { RunLoop.main.run(until: Date().addingTimeInterval(0.1)) }
            comprobar("network: yt-dlp update into the temporary folder (\(resultado))", !resultado.hasPrefix("FAILED"))
        }
        print(fallos == 0 ? "self-test: all passed" : "self-test: \(fallos) failed")
        return fallos
    }
}
