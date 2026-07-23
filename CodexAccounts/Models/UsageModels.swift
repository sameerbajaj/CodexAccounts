//
//  UsageModels.swift
//  CodexAccounts
//
//  Created by Sameer Bajaj on 2/21/26.
//

import Foundation

// MARK: - Usage API Response

struct CodexUsageResponse: Decodable {
    let planType: String?
    let rateLimitReachedType: String?
    let rateLimit: RateLimitDetails?
    let spendControl: SpendControlDetails?
    let credits: CreditDetails?

    enum CodingKeys: String, CodingKey {
        case planType = "plan_type"
        case rateLimitReachedType = "rate_limit_reached_type"
        case rateLimit = "rate_limit"
        case spendControl = "spend_control"
        case credits
    }

    struct RateLimitDetails: Decodable {
        let allowed: Bool?
        let limitReached: Bool?
        let rateLimitReachedType: String?
        let primaryWindow: WindowSnapshot?
        let secondaryWindow: WindowSnapshot?

        enum CodingKeys: String, CodingKey {
            case allowed
            case limitReached = "limit_reached"
            case rateLimitReachedType = "rate_limit_reached_type"
            case primaryWindow = "primary_window"
            case secondaryWindow = "secondary_window"
        }
    }

    struct WindowSnapshot: Decodable {
        let usedPercent: Double
        let resetAt: Int?
        let limitWindowSeconds: Int?
        let resetAfterSeconds: Int?

        enum CodingKeys: String, CodingKey {
            case usedPercent = "used_percent"
            case resetAt = "reset_at"
            case limitWindowSeconds = "limit_window_seconds"
            case resetAfterSeconds = "reset_after_seconds"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            if let d = try? container.decode(Double.self, forKey: .usedPercent) {
                self.usedPercent = d
            } else if let i = try? container.decode(Int.self, forKey: .usedPercent) {
                self.usedPercent = Double(i)
            } else {
                self.usedPercent = 0.0
            }

            self.resetAt = try? container.decode(Int.self, forKey: .resetAt)
            self.limitWindowSeconds = try? container.decode(Int.self, forKey: .limitWindowSeconds)
            self.resetAfterSeconds = try? container.decode(Int.self, forKey: .resetAfterSeconds)
        }
    }

    struct SpendControlDetails: Decodable {
        // Tolerant decoding of spend control dictionary if present
        init(from decoder: Decoder) throws {}
    }

    struct CreditDetails: Decodable {
        let hasCredits: Bool
        let unlimited: Bool
        let balance: Double?

        enum CodingKeys: String, CodingKey {
            case hasCredits = "has_credits"
            case unlimited
            case balance
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.hasCredits = (try? container.decode(Bool.self, forKey: .hasCredits)) ?? false
            self.unlimited = (try? container.decode(Bool.self, forKey: .unlimited)) ?? false
            if let b = try? container.decode(Double.self, forKey: .balance) {
                self.balance = b
            } else if let s = try? container.decode(String.self, forKey: .balance),
                      let v = Double(s)
            {
                self.balance = v
            } else {
                self.balance = nil
            }
        }
    }
}

// MARK: - Token Refresh Response

struct TokenRefreshResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let idToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
    }
}

// MARK: - Auth File

struct AuthFileContents: Decodable {
    let authMode: String?
    let tokens: TokenSet?
    let lastRefresh: String?
    let apiKey: String?

    enum CodingKeys: String, CodingKey {
        case authMode = "auth_mode"
        case tokens
        case lastRefresh = "last_refresh"
        case apiKey = "OPENAI_API_KEY"
    }

    struct TokenSet: Decodable {
        let accessToken: String?
        let refreshToken: String?
        let idToken: String?
        let accountId: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case idToken = "id_token"
            case accountId = "account_id"
        }
    }
}

// MARK: - Convenience

extension AccountUsage {
    init(from response: CodexUsageResponse, previous: AccountUsage? = nil) {
        let rateLimit = response.rateLimit
        let allowed = rateLimit?.allowed
        let limitReached = rateLimit?.limitReached
        let rateLimitReachedType = response.rateLimitReachedType ?? rateLimit?.rateLimitReachedType

        func makeWindow(from snapshot: CodexUsageResponse.WindowSnapshot?) -> UsageWindow? {
            guard let snapshot else { return nil }
            let duration = max(0, snapshot.limitWindowSeconds ?? 0)
            let resetDate: Date?
            if let resetAtInt = snapshot.resetAt {
                resetDate = Date(timeIntervalSince1970: TimeInterval(resetAtInt))
            } else if let resetAfterSecs = snapshot.resetAfterSeconds {
                resetDate = Date().addingTimeInterval(TimeInterval(resetAfterSecs))
            } else {
                resetDate = nil
            }
            return UsageWindow(
                usedPercent: snapshot.usedPercent,
                resetAt: resetDate,
                resetAfterSeconds: snapshot.resetAfterSeconds,
                windowDurationSeconds: duration,
                kind: UsageWindowKind.classify(seconds: duration),
                allowed: allowed,
                limitReached: limitReached
            )
        }

        let prim = makeWindow(from: rateLimit?.primaryWindow)
        let sec = makeWindow(from: rateLimit?.secondaryWindow)

        self.primaryWindow = prim
        self.secondaryWindow = sec
        self.additionalWindows = []
        self.allowed = allowed
        self.limitReached = limitReached
        self.rateLimitReachedType = rateLimitReachedType
        self.creditsBalance = response.credits?.balance
        self.hasCredits = response.credits?.hasCredits ?? false
        self.isUnlimited = response.credits?.unlimited ?? false
        self.lastUpdated = Date()
        self.error = nil

        if let prev = previous, let currentPrimary = self.primaryWindow, let prevPrimary = prev.primaryWindow {
            if currentPrimary.usedPercent != prevPrimary.usedPercent {
                self.lastActivityAt = Date()
            } else {
                self.lastActivityAt = prev.lastActivityAt
            }
        } else if let prev = previous, prev.usedPercent != self.usedPercent {
            self.lastActivityAt = Date()
        } else {
            self.lastActivityAt = previous?.lastActivityAt
        }
    }
}
