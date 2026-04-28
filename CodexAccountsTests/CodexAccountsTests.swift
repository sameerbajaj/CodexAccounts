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

    @Test func weeklyUsageOverdueUsesGracePeriod() async throws {
        let usage = AccountUsage(
            usedPercent: 0,
            resetAt: Date(timeIntervalSince1970: 1_000),
            primaryWindowSeconds: 5 * 60 * 60,
            weeklyUsedPercent: 0,
            weeklyResetAt: Date(timeIntervalSince1970: 1_000),
            weeklyWindowSeconds: 7 * 24 * 60 * 60,
            creditsBalance: nil,
            hasCredits: false,
            isUnlimited: false,
            lastUpdated: Date(timeIntervalSince1970: 1_050),
            error: nil,
            lastActivityAt: nil
        )

        #expect(!usage.weeklyResetIsOverdue(now: Date(timeIntervalSince1970: 1_120), grace: 180))
        #expect(usage.weeklyResetIsOverdue(now: Date(timeIntervalSince1970: 1_200), grace: 180))
    }

    @Test func codexAccountDecodeBackfillsWeeklyAutoKickDefaults() async throws {
        let json = """
        {
          "id": "test@example.com",
          "email": "test@example.com",
          "planType": "plus",
          "accessToken": "access",
          "refreshToken": "refresh",
          "addedAt": "1970-01-01T00:00:00Z",
          "isPinned": false
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(CodexAccount.self, from: Data(json.utf8))

        #expect(decoded.weeklyAutoKickOverride == .inherit)
        #expect(decoded.weeklyAutoKickAttemptCount == 0)
        #expect(decoded.lastWeeklyAutoKickCycleID == nil)
    }

    @Test func weeklyAutoKickPolicyResolvesGlobalAndPerAccountOverrides() async throws {
        let viewModel = AccountsViewModel()
        let pinned = makeAccount(isPinned: true)
        let forcedOn = makeAccount(
            email: "force-on@example.com",
            weeklyAutoKickOverride: .forceOn
        )
        let forcedOff = makeAccount(
            email: "force-off@example.com",
            isPinned: true,
            weeklyAutoKickOverride: .forceOff
        )

        viewModel.accounts = [pinned, forcedOn, forcedOff]
        viewModel.weeklyAutoKickMode = .pinnedAccounts

        #expect(viewModel.isWeeklyAutoKickEnabled(for: pinned))
        #expect(viewModel.isWeeklyAutoKickEnabled(for: forcedOn))
        #expect(!viewModel.isWeeklyAutoKickEnabled(for: forcedOff))
    }

    @Test func freshWeeklyResetShowsActivationPendingForEligibleAccount() async throws {
        let viewModel = AccountsViewModel()
        let account = makeAccount(weeklyAutoKickOverride: .forceOn)
        let usage = makeUsage(
            weeklyUsedPercent: 0,
            weeklyResetAt: Date().addingTimeInterval(7 * 24 * 60 * 60 - 30 * 60)
        )

        viewModel.accounts = [account]
        viewModel.usageData[account.id] = usage

        let indicator = viewModel.weeklyAutoKickIndicator(for: account, usage: usage)

        #expect(indicator?.help == "Fresh weekly reset detected. Activation pending.")
    }

    @Test func freshWeeklyResetDoesNotShowPendingAfterCycleAttemptRecorded() async throws {
        let resetAt = Date().addingTimeInterval(7 * 24 * 60 * 60 - 30 * 60)
        let usage = makeUsage(
            weeklyUsedPercent: 0,
            weeklyResetAt: resetAt
        )
        let account = makeAccount(
            weeklyAutoKickOverride: .forceOn,
            lastWeeklyAutoKickCycleID: String(Int(resetAt.timeIntervalSince1970))
        )
        let viewModel = AccountsViewModel()

        viewModel.accounts = [account]
        viewModel.usageData[account.id] = usage

        let indicator = viewModel.weeklyAutoKickIndicator(for: account, usage: usage)

        #expect(indicator?.help != "Fresh weekly reset detected. Activation pending.")
    }

    @Test func pinnedAccountsRespectManualPinnedOrderBeforeSortedAccounts() async throws {
        let viewModel = AccountsViewModel()
        let firstPinned = makeAccount(
            email: "first@example.com",
            isPinned: true,
            pinnedOrder: 1
        )
        let secondPinned = makeAccount(
            email: "second@example.com",
            isPinned: true,
            pinnedOrder: 0
        )
        let unpinned = makeAccount(email: "third@example.com")

        viewModel.accounts = [firstPinned, secondPinned, unpinned]

        #expect(viewModel.sortedAccounts.map(\.email) == [
            "second@example.com",
            "first@example.com",
            "third@example.com",
        ])
    }

    @Test func movePinnedAccountReordersPinnedSectionOnly() async throws {
        let viewModel = AccountsViewModel()
        let firstPinned = makeAccount(
            email: "first@example.com",
            isPinned: true,
            pinnedOrder: 0
        )
        let secondPinned = makeAccount(
            email: "second@example.com",
            isPinned: true,
            pinnedOrder: 1
        )
        let unpinned = makeAccount(email: "third@example.com")

        viewModel.accounts = [firstPinned, secondPinned, unpinned]
        viewModel.movePinnedAccount("second@example.com", before: "first@example.com")

        #expect(viewModel.sortedAccounts.map(\.email) == [
            "second@example.com",
            "first@example.com",
            "third@example.com",
        ])
    }

    private func makeAccount(
        email: String = "test@example.com",
        lastSuccessfulTokenRefreshAt: Date? = nil,
        lastRefreshFailureAt: Date? = nil,
        consecutiveRefreshFailures: Int = 0,
        authState: AuthState = .healthy,
        isPinned: Bool = false,
        pinnedOrder: Int? = nil,
        weeklyAutoKickOverride: WeeklyAutoKickOverride = .inherit,
        lastWeeklyAutoKickCycleID: String? = nil
    ) -> CodexAccount {
        CodexAccount(
            email: email,
            planType: "plus",
            accessToken: "access",
            refreshToken: "refresh",
            accountId: "acct_123",
            lastTokenRefresh: lastSuccessfulTokenRefreshAt,
            lastSuccessfulTokenRefreshAt: lastSuccessfulTokenRefreshAt,
            lastRefreshFailureAt: lastRefreshFailureAt,
            consecutiveRefreshFailures: consecutiveRefreshFailures,
            authState: authState,
            addedAt: Date(timeIntervalSince1970: 0),
            isPinned: isPinned,
            pinnedOrder: pinnedOrder,
            weeklyAutoKickOverride: weeklyAutoKickOverride,
            lastWeeklyAutoKickCycleID: lastWeeklyAutoKickCycleID
        )
    }

    private func makeUsage(
        weeklyUsedPercent: Double,
        weeklyResetAt: Date
    ) -> AccountUsage {
        AccountUsage(
            usedPercent: weeklyUsedPercent,
            resetAt: weeklyResetAt,
            primaryWindowSeconds: 7 * 24 * 60 * 60,
            weeklyUsedPercent: weeklyUsedPercent,
            weeklyResetAt: weeklyResetAt,
            weeklyWindowSeconds: 7 * 24 * 60 * 60,
            creditsBalance: nil,
            hasCredits: false,
            isUnlimited: false,
            lastUpdated: Date(),
            error: nil,
            lastActivityAt: nil
        )
    }

}
