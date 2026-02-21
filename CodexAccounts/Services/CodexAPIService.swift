//
//  CodexAPIService.swift
//  CodexAccounts
//
//  Created by Sameer Bajaj on 2/21/26.
//

import Foundation

enum CodexAPIService {
    private static let usageURL = "https://chatgpt.com/backend-api/wham/usage"
    private static let refreshEndpoint = "https://auth.openai.com/oauth/token"
    private static let clientID = "app_EMoamEEZ73f0CkXaXp7hrann"

    // MARK: - Errors

    enum APIError: LocalizedError, Equatable {
        case unauthorized
        case invalidResponse
        case serverError(Int, String?)
        case networkError(String)
        case noAuthFile

        var errorDescription: String? {
            switch self {
            case .unauthorized:
                return "Token expired. Run `codex auth` to re-authenticate."
            case .invalidResponse:
                return "Invalid response from OpenAI API."
            case let .serverError(code, message):
                if let message, !message.isEmpty {
                    return "API error \(code): \(String(message.prefix(100)))"
                }
                return "API error \(code)."
            case let .networkError(message):
                return "Network error: \(message)"
            case .noAuthFile:
                return "No auth.json found. Run `codex auth` first."
            }
        }

        static func == (lhs: APIError, rhs: APIError) -> Bool {
            switch (lhs, rhs) {
            case (.unauthorized, .unauthorized): return true
            case (.invalidResponse, .invalidResponse): return true
            case (.noAuthFile, .noAuthFile): return true
            case let (.serverError(a, _), .serverError(b, _)): return a == b
            case let (.networkError(a), .networkError(b)): return a == b
            default: return false
            }
        }
    }

    // MARK: - Usage Fetch Result

    struct FetchResult {
        let usage: AccountUsage
        let updatedAccount: CodexAccount?
    }

    // MARK: - Public API

    /// Fetch usage for an account, automatically refreshing the token if expired.
    static func fetchUsageWithRefresh(for account: CodexAccount) async throws -> FetchResult {
        do {
            let usage = try await fetchUsage(for: account)
            return FetchResult(usage: usage, updatedAccount: nil)
        } catch APIError.unauthorized {
            // Token expired — try refreshing
            let refreshed = try await refreshToken(for: account)
            let usage = try await fetchUsage(for: refreshed)
            return FetchResult(usage: usage, updatedAccount: refreshed)
        }
    }

    /// Fetch usage data for a single account.
    static func fetchUsage(for account: CodexAccount) async throws -> AccountUsage {
        guard let url = URL(string: usageURL) else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("Bearer \(account.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("CodexAccounts/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accountId = account.accountId, !accountId.isEmpty {
            request.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch http.statusCode {
        case 200 ... 299:
            do {
                let usageResponse = try JSONDecoder().decode(CodexUsageResponse.self, from: data)
                return AccountUsage(from: usageResponse)
            } catch {
                throw APIError.invalidResponse
            }
        case 401, 403:
            throw APIError.unauthorized
        default:
            let body = String(data: data, encoding: .utf8)
            throw APIError.serverError(http.statusCode, body)
        }
    }

    /// Refresh OAuth tokens using the refresh_token.
    static func refreshToken(for account: CodexAccount) async throws -> CodexAccount {
        guard !account.refreshToken.isEmpty else {
            throw APIError.unauthorized
        }

        guard let url = URL(string: refreshEndpoint) else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "client_id": clientID,
            "grant_type": "refresh_token",
            "refresh_token": account.refreshToken,
            "scope": "openid profile email",
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if http.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8)
            throw APIError.serverError(http.statusCode, body)
        }

        let tokenResponse = try JSONDecoder().decode(TokenRefreshResponse.self, from: data)

        var updated = account
        if let newAccess = tokenResponse.accessToken, !newAccess.isEmpty {
            updated.accessToken = newAccess
        }
        if let newRefresh = tokenResponse.refreshToken, !newRefresh.isEmpty {
            updated.refreshToken = newRefresh
        }
        if let newId = tokenResponse.idToken, !newId.isEmpty {
            updated.idToken = newId
        }
        updated.lastTokenRefresh = Date()
        return updated
    }

    // MARK: - Auth File Reading

    /// Read the current auth.json and parse it into a CodexAccount.
    static func readAuthFile() -> CodexAccount? {
        let codexHome = ProcessInfo.processInfo.environment["CODEX_HOME"]
            ?? "\(NSHomeDirectory())/.codex"
        let path = (codexHome as NSString).appendingPathComponent("auth.json")

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let auth = try? JSONDecoder().decode(AuthFileContents.self, from: data),
              let tokens = auth.tokens,
              let accessToken = tokens.accessToken, !accessToken.isEmpty,
              let refreshToken = tokens.refreshToken, !refreshToken.isEmpty
        else { return nil }

        // Parse identity from id_token first, then access_token
        let tokenToParse = tokens.idToken ?? accessToken
        guard let claims = JWTParser.parse(tokenToParse),
              let email = claims.email
        else { return nil }

        // Parse last_refresh date
        var lastRefresh: Date?
        if let lr = auth.lastRefresh {
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            lastRefresh = fmt.date(from: lr)
            if lastRefresh == nil {
                fmt.formatOptions = [.withInternetDateTime]
                lastRefresh = fmt.date(from: lr)
            }
        }

        return CodexAccount(
            email: email,
            planType: claims.planType ?? "unknown",
            accessToken: accessToken,
            refreshToken: refreshToken,
            idToken: tokens.idToken,
            accountId: tokens.accountId ?? claims.accountId,
            lastTokenRefresh: lastRefresh
        )
    }
}
