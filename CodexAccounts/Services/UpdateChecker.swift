//
//  UpdateChecker.swift
//  CodexAccounts
//

import Foundation

struct UpdateInfo {
    let version: String          // e.g. "1.2.0" or "latest"
    let tagName: String          // e.g. "v1.2.0" or "latest"
    let releaseURL: URL
    let downloadURL: URL?
    let releaseNotes: String?
    let isRolling: Bool          // true for the "latest" CI build
}

enum UpdateChecker {
    static let githubRepo = "sameerbajaj/CodexAccounts"
    static let releasesPage = URL(string: "https://github.com/\(githubRepo)/releases")!

    // Returns an UpdateInfo if a newer version (or newer rolling build) is available.
    static func check() async -> UpdateInfo? {
        let apiURL = URL(string: "https://api.github.com/repos/\(githubRepo)/releases")!
        var req = URLRequest(url: apiURL)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        req.setValue("CodexAccounts", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 10

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let releases = try? JSONDecoder().decode([GitHubRelease].self, from: data)
        else { return nil }

        // 1. Check stable releases first
        if let newest = releases.first(where: { !$0.draft && !$0.prerelease && $0.tagName != "latest" }) {
            let remoteVersion = normalise(newest.tagName)
            let localVersion  = normalise(currentVersion)
            if isNewer(remoteVersion, than: localVersion) {
                return UpdateInfo(
                    version: remoteVersion,
                    tagName: newest.tagName,
                    releaseURL: URL(string: newest.htmlURL) ?? releasesPage,
                    downloadURL: preferredDMGURL(in: newest),
                    releaseNotes: newest.body,
                    isRolling: false
                )
            }
        }

        // 2. Check the rolling "latest" pre-release — compare published_at
        //    against the most recent known baseline. That baseline is the
        //    greater of:
        //     a) CFBundleVersion (build timestamp stamped by CI), and
        //     b) the published_at we saved after the last self-update.
        //    Without (b) the app enters an infinite update loop because
        //    published_at is always later than build timestamp (the release
        //    is created *after* the build finishes in CI).
        if let latest = releases.first(where: { $0.tagName == "latest" }),
           let publishedAt = latest.publishedAt {
            let baseline = max(buildTimestamp, lastInstalledRollingTimestamp)
            if baseline > 0 && publishedAt > baseline + 60 {
                // Remote is at least 1 min newer — a real push happened
                return UpdateInfo(
                    version: "latest",
                    tagName: "latest",
                    releaseURL: URL(string: latest.htmlURL) ?? releasesPage,
                    downloadURL: preferredDMGURL(in: latest),
                    releaseNotes: latest.body,
                    isRolling: true
                )
            }
        }

        return nil
    }

    // MARK: - Helpers

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// CFBundleVersion is stamped as a Unix timestamp by build-dmg.sh
    static var buildTimestamp: TimeInterval {
        guard let s = Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
              let ts = TimeInterval(s) else { return 0 }
        return ts
    }

    // MARK: - Last-installed rolling timestamp

    private static let lastInstalledKey = "lastInstalledRollingTimestamp"

    /// The `published_at` of the rolling release we last self-updated to.
    /// Persisted in UserDefaults so it survives relaunch.
    static var lastInstalledRollingTimestamp: TimeInterval {
        UserDefaults.standard.double(forKey: lastInstalledKey)
    }

    /// Call after a successful self-update from a rolling release to prevent
    /// the checker from re-detecting the same build as an update.
    static func recordInstalledRollingTimestamp(_ publishedAt: TimeInterval) {
        UserDefaults.standard.set(publishedAt, forKey: lastInstalledKey)
    }

    private static func normalise(_ tag: String) -> String {
        var s = tag
        if s.hasPrefix("v") { s = String(s.dropFirst()) }
        return s
    }

    private static func isNewer(_ a: String, than b: String) -> Bool {
        let av = a.split(separator: ".").compactMap { Int($0) }
        let bv = b.split(separator: ".").compactMap { Int($0) }
        let count = max(av.count, bv.count)
        for i in 0..<count {
            let ai = i < av.count ? av[i] : 0
            let bi = i < bv.count ? bv[i] : 0
            if ai != bi { return ai > bi }
        }
        return false
    }

    private static func preferredDMGURL(in release: GitHubRelease) -> URL? {
        let dmg = release.assets.first { $0.name.lowercased().hasSuffix(".dmg") }
        return dmg.flatMap { URL(string: $0.browserDownloadURL) }
    }
}

// MARK: - GitHub API models

private struct GitHubRelease: Decodable {
    let tagName:     String
    let htmlURL:     String
    let draft:       Bool
    let prerelease:  Bool
    let body:        String?
    let publishedAt: TimeInterval?   // decoded from ISO-8601 string
    let assets:      [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName    = "tag_name"
        case htmlURL    = "html_url"
        case draft, prerelease, body
        case publishedAt = "published_at"
        case assets
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tagName    = try c.decode(String.self, forKey: .tagName)
        htmlURL    = try c.decode(String.self, forKey: .htmlURL)
        draft      = try c.decode(Bool.self,   forKey: .draft)
        prerelease = try c.decode(Bool.self,   forKey: .prerelease)
        body       = try c.decodeIfPresent(String.self, forKey: .body)
        assets     = try c.decodeIfPresent([GitHubAsset].self, forKey: .assets) ?? []
        if let iso = try c.decodeIfPresent(String.self, forKey: .publishedAt) {
            let fmt = ISO8601DateFormatter()
            publishedAt = fmt.date(from: iso)?.timeIntervalSince1970
        } else {
            publishedAt = nil
        }
    }
}

private struct GitHubAsset: Decodable {
    let name: String
    let browserDownloadURL: String

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}
