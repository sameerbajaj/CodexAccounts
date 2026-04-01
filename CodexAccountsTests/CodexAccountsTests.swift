//
//  CodexAccountsTests.swift
//  CodexAccountsTests
//
//  Created by Sameer Bajaj on 2/21/26.
//

import Foundation
import Testing
@testable import CodexAccounts

@MainActor
struct CodexAccountsTests {
    @Test func markRefreshFailureSetsNeedsReauthOnUnauthorized() async throws {
        let account = makeAccount()

        let updated = CodexAPIService.markRefreshFailure(
            for: account,
            error: .unauthorized,
            now: Date(timeIntervalSince1970: 100)
        )

        #expect(updated.authState == .needsReauth)
        #expect(updated.lastRefreshFailureAt == Date(timeIntervalSince1970: 100))
        #expect(updated.consecutiveRefreshFailures == 0)
    }

    @Test func markRefreshFailureMarksDegradedForNetworkIssues() async throws {
        let account = makeAccount()

        let updated = CodexAPIService.markRefreshFailure(
            for: account,
            error: .networkError("offline"),
            now: Date(timeIntervalSince1970: 200)
        )

        #expect(updated.authState == .degraded)
        #expect(updated.consecutiveRefreshFailures == 1)
        #expect(updated.lastRefreshAttemptAt == Date(timeIntervalSince1970: 200))
    }

    @Test func markStaleIfNeededMarksAgedSessionsStale() async throws {
        let baseline = Date(timeIntervalSince1970: 300)
        let account = makeAccount(
            lastSuccessfulTokenRefreshAt: baseline,
            authState: .healthy
        )

        let updated = CodexAPIService.markStaleIfNeeded(
            for: account,
            staleAfter: 60,
            now: baseline.addingTimeInterval(61)
        )

        #expect(updated.authState == .stale)
    }

    @Test func markUsageSuccessRestoresHealthyState() async throws {
        let account = makeAccount(
            lastRefreshFailureAt: Date(timeIntervalSince1970: 400),
            consecutiveRefreshFailures: 2,
            authState: .degraded
        )

        let updated = CodexAPIService.markUsageSuccess(
            for: account,
            now: Date(timeIntervalSince1970: 450)
        )

        #expect(updated.authState == .healthy)
        #expect(updated.lastSuccessfulUsageAt == Date(timeIntervalSince1970: 450))
    }

    private func makeAccount(
        lastSuccessfulTokenRefreshAt: Date? = nil,
        lastRefreshFailureAt: Date? = nil,
        consecutiveRefreshFailures: Int = 0,
        authState: AuthState = .healthy
    ) -> CodexAccount {
        CodexAccount(
            email: "test@example.com",
            planType: "plus",
            accessToken: "access",
            refreshToken: "refresh",
            accountId: "acct_123",
            lastTokenRefresh: lastSuccessfulTokenRefreshAt,
            lastSuccessfulTokenRefreshAt: lastSuccessfulTokenRefreshAt,
            lastRefreshFailureAt: lastRefreshFailureAt,
            consecutiveRefreshFailures: consecutiveRefreshFailures,
            authState: authState,
            addedAt: Date(timeIntervalSince1970: 0)
        )
    }

}
