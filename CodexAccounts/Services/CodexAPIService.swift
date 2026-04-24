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
    private static let refreshCoordinator = RefreshCoordinator()

    private actor RefreshCoordinator {
        private var inFlightByAccountID: [String: Task<CodexAccount, Error>] = [:]

        func refresh(
            account: CodexAccount,
            now: Date,
            operation: @escaping (CodexAccount, Date) async throws -> CodexAccount
        ) async throws -> CodexAccount {
            if let existingTask = inFlightByAccountID[account.id] {
                return try await existingTask.value
            }

            let task = Task { try await operation(account, now) }
            inFlightByAccountID[account.id] = task

            do {
                let refreshed = try await task.value
                inFlightByAccountID[account.id] = nil
                return refreshed
            } catch {
                inFlightByAccountID[account.id] = nil
                throw error
            }
        }
    }

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

    // MARK: - Models

    struct FetchResult {
        let usage: AccountUsage
        let updatedAccount: CodexAccount?
    }

    struct AuditResult {
        let account: CodexAccount
        let didRefresh: Bool
    }

    enum AuditTrigger {
        case startup
        case timer
        case resume
        case appDidBecomeActive
        case manualRefresh
        case authFileSync
    }

    // MARK: - Public API

    static func fetchUsageWithRefresh(for account: CodexAccount, previous: AccountUsage? = nil) async throws -> FetchResult {
        do {
            let usage = try await fetchUsage(for: account, previous: previous)
            let updated = markUsageSuccess(for: account)
            return FetchResult(usage: usage, updatedAccount: updated)
        } catch APIError.unauthorized {
            let refreshed = try await refreshToken(for: account)
            let usage = try await fetchUsage(for: refreshed, previous: previous)
            let updated = markUsageSuccess(for: refreshed)
            return FetchResult(usage: usage, updatedAccount: updated)
        }
    }

    static func auditSession(
        for account: CodexAccount,
        trigger: AuditTrigger,
        maxTokenAge: TimeInterval,
        staleAfter: TimeInterval,
        refreshBeforeExpiry: TimeInterval,
        now: Date = Date()
    ) async throws -> AuditResult {
        let candidate = markStaleIfNeeded(for: account, staleAfter: staleAfter, now: now)
        let refreshBaseline = candidate.lastSuccessfulTokenRefreshAt ?? candidate.lastTokenRefresh ?? candidate.addedAt
        let accessTokenExpiresSoon = accessTokenExpiresSoon(
            candidate.accessToken,
            refreshBefore: refreshBeforeExpiry,
            now: now
        )
        let shouldRefresh = accessTokenExpiresSoon
            || now.timeIntervalSince(refreshBaseline) >= maxTokenAge

        guard shouldRefresh else {
            if candidate.authState == .degraded,
               let failureAt = candidate.lastRefreshFailureAt,
               now.timeIntervalSince(failureAt) < staleAfter
            {
                return AuditResult(account: candidate, didRefresh: false)
            }

            return AuditResult(account: candidate, didRefresh: false)
        }

        let refreshed = try await refreshToken(for: candidate, now: now)
        return AuditResult(account: refreshed, didRefresh: true)
    }

    private static func accessTokenExpiresSoon(
        _ token: String,
        refreshBefore: TimeInterval,
        now: Date
    ) -> Bool {
        guard let expiry = JWTParser.parse(token)?.expiresAt else { return false }
        return expiry.timeIntervalSince(now) <= refreshBefore
    }

    static func markUsageSuccess(for account: CodexAccount, now: Date = Date()) -> CodexAccount {
        var updated = account
        updated.lastSuccessfulUsageAt = now
        updated.authState = .healthy
        return updated
    }

    static func markRefreshFailure(
        for account: CodexAccount,
        error: APIError,
        now: Date = Date()
    ) -> CodexAccount {
        var updated = account
        updated.lastRefreshAttemptAt = now
        updated.lastRefreshFailureAt = now

        switch error {
        case .unauthorized:
            updated.authState = .needsReauth
        default:
            updated.consecutiveRefreshFailures += 1
            updated.authState = .degraded
        }

        return updated
    }

    static func markStaleIfNeeded(
        for account: CodexAccount,
        staleAfter: TimeInterval,
        now: Date = Date()
    ) -> CodexAccount {
        var updated = account
        guard updated.authState != .needsReauth else { return updated }

        let baseline = updated.lastAuthValidationAt ?? updated.addedAt
        if now.timeIntervalSince(baseline) >= staleAfter {
            updated.authState = .stale
        }
        return updated
    }

    // MARK: - Usage

    static func fetchUsage(for account: CodexAccount, previous: AccountUsage? = nil) async throws -> AccountUsage {
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
                return AccountUsage(from: usageResponse, previous: previous)
            } catch {
                throw APIError.invalidResponse
            }
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.serverError(http.statusCode, responseErrorText(from: data))
        default:
            throw APIError.serverError(http.statusCode, responseErrorText(from: data))
        }
    }

    // MARK: - Refresh

    static func refreshToken(for account: CodexAccount, now: Date = Date()) async throws -> CodexAccount {
        guard !account.refreshToken.isEmpty else {
            throw APIError.unauthorized
        }

        return try await refreshCoordinator.refresh(
            account: account,
            now: now,
            operation: performTokenRefresh(for:now:)
        )
    }

    private static func performTokenRefresh(for account: CodexAccount, now: Date) async throws -> CodexAccount {
        var requestAccount = account
        requestAccount.lastRefreshAttemptAt = now

        guard let url = URL(string: refreshEndpoint) else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        request.httpBody = percentEncodedFormBody([
            ("client_id", clientID),
            ("grant_type", "refresh_token"),
            ("refresh_token", requestAccount.refreshToken),
        ])

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

        guard http.statusCode == 200 else {
            let errorBody = responseErrorText(from: data)
            if isUnauthorizedRefreshResponse(statusCode: http.statusCode, errorBody: errorBody) {
                throw APIError.unauthorized
            }
            throw APIError.serverError(http.statusCode, errorBody)
        }

        let tokenResponse = try JSONDecoder().decode(TokenRefreshResponse.self, from: data)

        var updated = requestAccount
        if let newAccess = tokenResponse.accessToken, !newAccess.isEmpty {
            updated.accessToken = newAccess
        }
        if let newRefresh = tokenResponse.refreshToken, !newRefresh.isEmpty {
            updated.refreshToken = newRefresh
        }
        if let newID = tokenResponse.idToken, !newID.isEmpty {
            updated.idToken = newID
        }
        if let claims = JWTParser.parse(updated.idToken ?? updated.accessToken),
           let refreshedAccountID = claims.accountId,
           !refreshedAccountID.isEmpty
        {
            updated.accountId = refreshedAccountID
        }
        updated.lastTokenRefresh = now
        updated.lastSuccessfulTokenRefreshAt = now
        updated.lastRefreshFailureAt = nil
        updated.consecutiveRefreshFailures = 0
        updated.authState = .healthy
        return updated
    }

    private static func responseErrorText(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let nested = json["error"] as? [String: Any] {
                let code = nested["code"] as? String
                let message = (nested["message"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let code, let message, !message.isEmpty {
                    return "\(code): \(message)"
                }
                if let message, !message.isEmpty {
                    return message
                }
            }

            let code = (json["error"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let description = (json["error_description"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let message = (json["message"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let code, let description, !description.isEmpty {
                return "\(code): \(description)"
            }
            if let description, !description.isEmpty {
                return description
            }
            if let message, !message.isEmpty {
                return message
            }
            if let code, !code.isEmpty {
                return code
            }
        }

        let raw = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let raw, !raw.isEmpty {
            return raw
        }
        return nil
    }

    private static func isUnauthorizedRefreshResponse(statusCode: Int, errorBody: String?) -> Bool {
        if statusCode == 401 || statusCode == 403 {
            return true
        }
        guard statusCode == 400 else { return false }

        let normalized = (errorBody ?? "").lowercased()
        if normalized.contains("invalid_grant") {
            return true
        }
        if normalized.contains("token expired") {
            return true
        }
        if normalized.contains("refresh token"),
           normalized.contains("expired") || normalized.contains("invalid") || normalized.contains("revoked")
        {
            return true
        }
        return false
    }

    private static func percentEncodedFormBody(_ fields: [(String, String)]) -> Data? {
        var components = URLComponents()
        components.queryItems = fields.map { URLQueryItem(name: $0.0, value: $0.1) }
        return components.percentEncodedQuery?.data(using: .utf8)
    }

    // MARK: - Auth File Reading

    static func readAuthFile(codexHome: String? = nil) -> CodexAccount? {
        let codexHome = codexHome
            ?? ProcessInfo.processInfo.environment["CODEX_HOME"]
            ?? "\(NSHomeDirectory())/.codex"
        let path = (codexHome as NSString).appendingPathComponent("auth.json")

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let auth = try? JSONDecoder().decode(AuthFileContents.self, from: data),
              let tokens = auth.tokens,
              let accessToken = tokens.accessToken, !accessToken.isEmpty,
              let refreshToken = tokens.refreshToken, !refreshToken.isEmpty
        else { return nil }

        let tokenToParse = tokens.idToken ?? accessToken
        guard let claims = JWTParser.parse(tokenToParse),
              let email = claims.email
        else { return nil }

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
            lastTokenRefresh: lastRefresh,
            lastSuccessfulTokenRefreshAt: lastRefresh,
            authState: .healthy
        )
    }
}
