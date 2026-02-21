//
//  AuthFileWatcher.swift
//  CodexAccounts
//
//  Created by Sameer Bajaj on 2/21/26.
//

import Foundation

/// Polls `~/.codex/auth.json` for modification changes.
/// Uses a lightweight Timer approach (stat check every 2 seconds).
@Observable
final class AuthFileWatcher {
    var isWatching = false
    var onAuthFileChanged: (() -> Void)?

    private var timer: Timer?
    private var lastModified: Date?

    var authFilePath: String {
        let codexHome = ProcessInfo.processInfo.environment["CODEX_HOME"]
            ?? "\(NSHomeDirectory())/.codex"
        return (codexHome as NSString).appendingPathComponent("auth.json")
    }

    func start() {
        guard !isWatching else { return }
        isWatching = true
        lastModified = fileModificationDate()

        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkFile()
        }
    }

    func stop() {
        isWatching = false
        timer?.invalidate()
        timer = nil
    }

    private func checkFile() {
        let currentModified = fileModificationDate()
        if let current = currentModified, current != lastModified {
            lastModified = current
            onAuthFileChanged?()
        }
    }

    private func fileModificationDate() -> Date? {
        let attrs = try? FileManager.default.attributesOfItem(atPath: authFilePath)
        return attrs?[.modificationDate] as? Date
    }
}
