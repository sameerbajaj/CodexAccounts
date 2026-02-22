//
//  UpdateChecker.swift
//  CodexAccounts
//

import Foundation

struct UpdateInfo {
    let version: String          // e.g. "1.2.0"
    let tagName: String          // e.g. "v1.2.0"
    let releaseURL: URL
    let releaseNotes: String?
}

enum UpdateChecker {
    static let githubRepo = "sameerbajaj/CodexAccounts"
    static let releasesPage = URL(string: "https://github.com/\(githubRepo)/releases")!

    // Returns an UpdateInfo if a newer version is available, nil otherwise.
    static func check() async -> UpdateInfo? {
        let apiURL = URL(string: "https://api.github.com/repos/\(githubRepo)/releases")!
        var req = URLRequest(url: apiURL)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        req.timeoutInterval = 10

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let releases = try? JSONDecoder().decode([GitHubRelease].self, from: data)
        else { return nil }

        // Ignore pre-releases tagged "latest" — those are rolling CI builds.
        // Pick the newest stable release (non-prerelease, non-draft).
        guard let newest = releases.first(where: { !$0.draft && !$0.prerelease && $0.tagName != "latest" })
        else { return nil }

        let remoteVersion = normalise(newest.tagName)
        let localVersion  = normalise(currentVersion)

        guard isNewer(remoteVersion, than: localVersion) else { return nil }

        return UpdateInfo(
            version: remoteVersion,
            tagName: newest.tagName,
            releaseURL: URL(string: newest.htmlURL) ?? releasesPage,
            releaseNotes: newest.body
        )
    }

    // MARK: - Helpers

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// Strips a leading "v" and normalises to dotted numerics.
    private static func normalise(_ tag: String) -> String {
        var s = tag
        if s.hasPrefix("v") { s = String(s.dropFirst()) }
        return s
    }

    /// Returns true if `a` > `b` using numeric component comparison.
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
}

// MARK: - GitHub API models

private struct GitHubRelease: Decodable {
    let tagName:  String
    let htmlURL:  String
    let draft:    Bool
    let prerelease: Bool
    let body:     String?

    enum CodingKeys: String, CodingKey {
        case tagName   = "tag_name"
        case htmlURL   = "html_url"
        case draft, prerelease, body
    }
}
