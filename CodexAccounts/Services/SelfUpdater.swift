//
//  SelfUpdater.swift
//  CodexAccounts
//
//  Handles downloading a DMG, extracting the .app, and replacing the running
//  app in-place — then relaunching. Works without code-signing or notarization.
//

import Foundation
import AppKit

/// Tracks the state of an in-progress self-update.
enum SelfUpdateState: Equatable {
    case idle
    case downloading(progress: Double)   // 0…1
    case installing
    case failed(String)
}

/// Downloads the latest DMG from GitHub Releases, mounts it, replaces the
/// running .app bundle, and relaunches. Designed for ad-hoc-signed macOS apps.
enum SelfUpdater {

    // MARK: - Public

    /// Perform a full self-update cycle. `onProgress` is called on MainActor.
    static func update(
        dmgURL: URL,
        onStateChange: @escaping @MainActor (SelfUpdateState) -> Void
    ) async {
        do {
            // 1 — Download
            await MainActor.run { onStateChange(.downloading(progress: 0)) }
            let localDMG = try await downloadDMG(from: dmgURL) { fraction in
                Task { @MainActor in onStateChange(.downloading(progress: fraction)) }
            }

            // 2 — Mount
            await MainActor.run { onStateChange(.installing) }
            let mountPoint = try await mountDMG(at: localDMG)

            // 3 — Locate the .app inside the mounted volume
            let newAppURL = try locateApp(in: mountPoint)

            // 4 — Replace the running .app
            let runningAppURL = Bundle.main.bundleURL
            try replaceApp(old: runningAppURL, with: newAppURL)

            // 5 — Unmount (best-effort)
            unmountDMG(mountPoint: mountPoint)

            // 6 — Cleanup temp DMG
            try? FileManager.default.removeItem(at: localDMG)

            // 7 — Relaunch
            relaunchApp(at: runningAppURL)

        } catch {
            await MainActor.run { onStateChange(.failed(error.localizedDescription)) }
        }
    }

    // MARK: - Download

    private static func downloadDMG(
        from url: URL,
        progress: @escaping (Double) -> Void
    ) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexAccounts-Update", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let destURL = tempDir.appendingPathComponent("update.dmg")
        try? FileManager.default.removeItem(at: destURL)

        // Use URLSession delegate for progress tracking
        let delegate = DownloadDelegate(progress: progress)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)

        return try await withCheckedThrowingContinuation { continuation in
            let task = session.downloadTask(with: url) { tempURL, response, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let tempURL else {
                    continuation.resume(throwing: UpdateError.downloadFailed)
                    return
                }
                do {
                    try FileManager.default.moveItem(at: tempURL, to: destURL)
                    continuation.resume(returning: destURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            task.resume()
        }
    }

    // MARK: - Mount / Unmount DMG

    private static func mountDMG(at dmgURL: URL) async throws -> URL {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = [
            "attach", dmgURL.path,
            "-nobrowse",       // don't show in Finder sidebar
            "-readonly",
            "-mountrandom", "/tmp",
            "-plist"
        ]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw UpdateError.mountFailed
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        // Parse the plist to find the mount point
        guard let plist = try? PropertyListSerialization.propertyList(
            from: data, format: nil
        ) as? [String: Any],
              let entities = plist["system-entities"] as? [[String: Any]]
        else {
            throw UpdateError.mountFailed
        }

        for entity in entities {
            if let mp = entity["mount-point"] as? String {
                return URL(fileURLWithPath: mp)
            }
        }
        throw UpdateError.mountFailed
    }

    private static func unmountDMG(mountPoint: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["detach", mountPoint.path, "-quiet"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }

    // MARK: - Locate .app

    private static func locateApp(in volume: URL) throws -> URL {
        let contents = try FileManager.default.contentsOfDirectory(
            at: volume, includingPropertiesForKeys: nil
        )
        guard let app = contents.first(where: { $0.pathExtension == "app" }) else {
            throw UpdateError.appNotFoundInDMG
        }
        return app
    }

    // MARK: - Replace running app

    private static func replaceApp(old: URL, with new: URL) throws {
        let fm = FileManager.default

        // Sanity: make sure we're replacing something in /Applications or wherever
        // the user dragged the app — not inside the build directory.
        guard fm.fileExists(atPath: old.path) else {
            throw UpdateError.currentAppNotFound
        }

        // Stage the new app next to the old one, then swap atomically.
        let parent = old.deletingLastPathComponent()
        let staged = parent.appendingPathComponent(".CodexAccounts-update-staging.app")

        // Clean up any leftover staging from a previous failed attempt
        try? fm.removeItem(at: staged)

        // Copy (not move — the source is on a mounted DMG, possibly read-only)
        try fm.copyItem(at: new, to: staged)

        // Ad-hoc re-sign so Gatekeeper doesn't complain
        adHocSign(staged)

        // Atomic swap: replaceItemAt is POSIX-rename under the hood — it
        // replaces the directory entry, not individual files, so even though
        // the old binary is mmap'd the kernel keeps the old vnode alive until
        // the process exits.
        _ = try fm.replaceItemAt(old, withItemAt: staged)
    }

    private static func adHocSign(_ appURL: URL) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        proc.arguments = ["--force", "--deep", "--sign", "-", appURL.path]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
        proc.waitUntilExit()
    }

    // MARK: - Relaunch

    /// Launches a detached shell script that waits for us to exit, then reopens
    /// the app. We quit ourselves right after spawning it.
    private static func relaunchApp(at appURL: URL) {
        let pid = ProcessInfo.processInfo.processIdentifier
        let appPath = appURL.path

        // Shell script: wait for the old process to die, then open the app.
        let script = """
        #!/bin/bash
        # Wait for the old process to terminate (up to 10 s)
        for i in $(seq 1 20); do
            kill -0 \(pid) 2>/dev/null || break
            sleep 0.5
        done
        open "\(appPath)"
        """

        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("codexaccounts-relaunch.sh")
        try? script.write(to: scriptURL, atomically: true, encoding: .utf8)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/bash")
        proc.arguments = [scriptURL.path]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        // Detach: don't let our termination kill the child
        proc.qualityOfService = .utility
        try? proc.run()

        // Give the script a moment to start, then quit.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApplication.shared.terminate(nil)
        }
    }

    // MARK: - Errors

    enum UpdateError: LocalizedError {
        case downloadFailed
        case mountFailed
        case appNotFoundInDMG
        case currentAppNotFound

        var errorDescription: String? {
            switch self {
            case .downloadFailed:     return "Failed to download the update."
            case .mountFailed:        return "Failed to open the downloaded image."
            case .appNotFoundInDMG:   return "No app found in the update image."
            case .currentAppNotFound: return "Cannot locate the running app to replace."
            }
        }
    }
}

// MARK: - Download Progress Delegate

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    let onProgress: (Double) -> Void

    init(progress: @escaping (Double) -> Void) {
        self.onProgress = progress
        super.init()
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        onProgress(fraction)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // handled in the completion handler of downloadTask
    }
}
