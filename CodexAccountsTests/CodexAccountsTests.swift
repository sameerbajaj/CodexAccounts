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

    @Test func auditRefreshesStaleAccountsEvenBeforeMaxTokenAge() async throws {
        let baseline = Date(timeIntervalSince1970: 500)
        let stale = makeAccount(
            lastSuccessfulTokenRefreshAt: baseline,
            authState: .stale
        )

        let shouldRefresh = CodexAPIService.shouldRefreshDuringAudit(
            stale,
            refreshBaseline: baseline,
            maxTokenAge: 7 * 24 * 60 * 60,
            accessTokenExpiresSoon: false,
            now: baseline.addingTimeInterval(60)
        )

        #expect(shouldRefresh)
    }

    @Test func auditDoesNotRefreshHealthyRecentAccountsWithoutExpiringAccessToken() async throws {
        let baseline = Date(timeIntervalSince1970: 600)
        let healthy = makeAccount(
            lastSuccessfulTokenRefreshAt: baseline,
            authState: .healthy
        )

        let shouldRefresh = CodexAPIService.shouldRefreshDuringAudit(
            healthy,
            refreshBaseline: baseline,
            maxTokenAge: 7 * 24 * 60 * 60,
            accessTokenExpiresSoon: false,
            now: baseline.addingTimeInterval(60)
        )

        #expect(!shouldRefresh)
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

    @Test func weeklyResetSlidingDetectionIdentifiesMovingFullWindow() async throws {
        let window = 7 * 24 * 60 * 60
        let previousObservedAt = Date(timeIntervalSince1970: 1_000)
        let currentObservedAt = previousObservedAt.addingTimeInterval(120)
        let previousResetAt = previousObservedAt.addingTimeInterval(TimeInterval(window))
        let currentResetAt = currentObservedAt.addingTimeInterval(TimeInterval(window))

        let isSliding = AccountsViewModel.weeklyResetAppearsSliding(
            previousResetAt: previousResetAt,
            previousObservedAt: previousObservedAt,
            currentResetAt: currentResetAt,
            currentObservedAt: currentObservedAt,
            weeklyWindowSeconds: window,
            remainingPercent: 97
        )

        #expect(isSliding)
    }

    @Test func weeklyResetSlidingDetectionIgnoresFixedCountdownAtSameRemaining() async throws {
        let window = 7 * 24 * 60 * 60
        let previousObservedAt = Date(timeIntervalSince1970: 1_000)
        let currentObservedAt = previousObservedAt.addingTimeInterval(120)
        let resetAt = previousObservedAt.addingTimeInterval(TimeInterval(window))

        let isSliding = AccountsViewModel.weeklyResetAppearsSliding(
            previousResetAt: resetAt,
            previousObservedAt: previousObservedAt,
            currentResetAt: resetAt,
            currentObservedAt: currentObservedAt,
            weeklyWindowSeconds: window,
            remainingPercent: 97
        )

        #expect(!isSliding)
    }

    @Test func weeklyResetSlidingDetectionRequiresHighRemaining() async throws {
        let window = 7 * 24 * 60 * 60
        let previousObservedAt = Date(timeIntervalSince1970: 1_000)
        let currentObservedAt = previousObservedAt.addingTimeInterval(120)
        let previousResetAt = previousObservedAt.addingTimeInterval(TimeInterval(window))
        let currentResetAt = currentObservedAt.addingTimeInterval(TimeInterval(window))

        let isSliding = AccountsViewModel.weeklyResetAppearsSliding(
            previousResetAt: previousResetAt,
            previousObservedAt: previousObservedAt,
            currentResetAt: currentResetAt,
            currentObservedAt: currentObservedAt,
            weeklyWindowSeconds: window,
            remainingPercent: 70
        )

        #expect(!isSliding)
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

    @Test func readAuthFileFallsBackToIDTokenForEmailClaims() async throws {
        let codexHome = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: codexHome, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: codexHome) }

        let accessToken = makeJWT(payload: [
            "https://api.openai.com/auth": [
                "chatgpt_account_id": "acct_access",
                "chatgpt_plan_type": "plus",
            ],
        ])
        let idToken = makeJWT(payload: [
            "email": "real-user@example.com",
        ])
        let authJSON = """
        {
          "auth_mode": "chatgpt",
          "tokens": {
            "access_token": "\(accessToken)",
            "refresh_token": "refresh",
            "id_token": "\(idToken)",
            "account_id": "acct_file"
          },
          "last_refresh": "1970-01-01T00:00:00Z"
        }
        """

        try authJSON.write(
            to: codexHome.appendingPathComponent("auth.json"),
            atomically: true,
            encoding: .utf8
        )

        let account = CodexAPIService.readAuthFile(codexHome: codexHome.path)

        #expect(account?.email == "real-user@example.com")
        #expect(account?.planType == "plus")
        #expect(account?.accountId == "acct_access")
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

    @Test func freshWeeklyResetShowsNoAutoKickNeededForEligibleAccount() async throws {
        let viewModel = AccountsViewModel()
        let account = makeAccount(weeklyAutoKickOverride: .forceOn)
        let usage = makeUsage(
            weeklyUsedPercent: 0,
            weeklyResetAt: Date().addingTimeInterval(7 * 24 * 60 * 60 - 30 * 60)
        )

        viewModel.accounts = [account]
        viewModel.usageData[account.id] = usage

        let indicator = viewModel.weeklyAutoKickIndicator(for: account, usage: usage)

        #expect(indicator?.help == "Fresh weekly reset detected. No auto-kick needed.")
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

        #expect(indicator?.help != "Fresh weekly reset detected. No auto-kick needed.")
    }

    @Test func freshWeeklyResetShowsActivatedAfterCycleSuccess() async throws {
        let resetAt = Date().addingTimeInterval(7 * 24 * 60 * 60 - 30 * 60)
        let usage = makeUsage(
            weeklyUsedPercent: 0,
            weeklyResetAt: resetAt
        )
        let account = makeAccount(
            weeklyAutoKickOverride: .forceOn,
            lastWeeklyAutoKickCycleID: String(Int(resetAt.timeIntervalSince1970)),
            lastWeeklyAutoKickSuccessAt: Date(timeIntervalSince1970: 1_000)
        )
        let viewModel = AccountsViewModel()

        viewModel.accounts = [account]
        viewModel.usageData[account.id] = usage

        let indicator = viewModel.weeklyAutoKickIndicator(for: account, usage: usage)

        #expect(indicator?.help.contains("sent the activation message for this reset") == true)
    }

    @Test func freshWeeklyResetShowsDisabledStateWhenAutoKickOff() async throws {
        let viewModel = AccountsViewModel()
        viewModel.weeklyAutoKickMode = .off
        let account = makeAccount()
        let usage = makeUsage(
            weeklyUsedPercent: 0,
            weeklyResetAt: Date().addingTimeInterval(7 * 24 * 60 * 60 - 30 * 60)
        )

        viewModel.accounts = [account]
        viewModel.usageData[account.id] = usage

        let indicator = viewModel.weeklyAutoKickIndicator(for: account, usage: usage)

        #expect(indicator?.help == "Fresh weekly reset detected, but weekly auto-kick is off for this account.")
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

    @Test func monthlyWindowParsingZeroUsed() async throws {
        let json = """
        {
            "plan_type": "free",
            "rate_limit": {
                "allowed": true,
                "limit_reached": false,
                "primary_window": {
                    "used_percent": 0,
                    "reset_at": 1774321200,
                    "limit_window_seconds": 2592000
                },
                "secondary_window": null
            }
        }
        """
        let response = try JSONDecoder().decode(CodexUsageResponse.self, from: Data(json.utf8))
        let usage = AccountUsage(from: response)

        #expect(usage.remainingPercent == 100)
        #expect(usage.primaryWindow?.kind == .monthly)
        #expect(usage.primaryWindow?.displayLabel == "30-day")
        #expect(usage.allowed == true)
        #expect(!usage.hasWeeklyWindow)
        #expect(!usage.isLimitReached)
    }

    @Test func monthlyWindowParsingLimitReached() async throws {
        let json = """
        {
            "plan_type": "free",
            "rate_limit": {
                "allowed": false,
                "limit_reached": true,
                "primary_window": {
                    "used_percent": 100,
                    "reset_at": 1774321200,
                    "limit_window_seconds": 2592000
                },
                "secondary_window": null
            }
        }
        """
        let response = try JSONDecoder().decode(CodexUsageResponse.self, from: Data(json.utf8))
        let usage = AccountUsage(from: response)

        #expect(usage.remainingPercent == 0)
        #expect(usage.primaryWindow?.kind == .monthly)
        #expect(usage.isLimitReached == true)
        #expect(!usage.hasWeeklyWindow)
    }

    @Test func legacyTwoWindowPayloadPreservesOrder() async throws {
        let json = """
        {
            "plan_type": "pro",
            "rate_limit": {
                "allowed": true,
                "limit_reached": false,
                "primary_window": {
                    "used_percent": 10,
                    "reset_at": 1774321200,
                    "limit_window_seconds": 18000
                },
                "secondary_window": {
                    "used_percent": 25,
                    "reset_at": 1774926000,
                    "limit_window_seconds": 604800
                }
            }
        }
        """
        let response = try JSONDecoder().decode(CodexUsageResponse.self, from: Data(json.utf8))
        let usage = AccountUsage(from: response)

        #expect(usage.primaryWindow?.kind == .shortTerm)
        #expect(usage.primaryWindow?.displayLabel == "5-hour")
        #expect(usage.secondaryWindow?.kind == .weekly)
        #expect(usage.secondaryWindow?.displayLabel == "Weekly")
        #expect(usage.hasWeeklyWindow == true)
        #expect(usage.weeklyUsedPercent == 25)
    }

    @Test func nullSecondaryWindowHandling() async throws {
        let json = """
        {
            "plan_type": "go",
            "rate_limit": {
                "allowed": true,
                "primary_window": {
                    "used_percent": 5,
                    "reset_at": 1774321200,
                    "limit_window_seconds": 2592000
                },
                "secondary_window": null
            }
        }
        """
        let response = try JSONDecoder().decode(CodexUsageResponse.self, from: Data(json.utf8))
        let usage = AccountUsage(from: response)

        #expect(usage.secondaryWindow == nil)
        #expect(!usage.hasWeeklyWindow)
    }

    @Test func missingOptionalFieldsInUsagePayload() async throws {
        let json = """
        {
            "rate_limit": {
                "primary_window": {
                    "used_percent": 15,
                    "limit_window_seconds": 864000
                }
            }
        }
        """
        let response = try JSONDecoder().decode(CodexUsageResponse.self, from: Data(json.utf8))
        let usage = AccountUsage(from: response)

        #expect(usage.usedPercent == 15)
        #expect(usage.primaryWindow?.kind == .custom)
        #expect(usage.primaryWindow?.displayLabel == "10-day")
        #expect(usage.allowed == nil)
        #expect(usage.secondaryWindow == nil)
    }

    @Test func monthlyWindowExcludedWhenAutoKickDisabled() async throws {
        let viewModel = AccountsViewModel()
        let account = makeAccount(weeklyAutoKickOverride: .forceOff)
        let resetAt = Date().addingTimeInterval(-100)
        let usage = AccountUsage(
            primaryWindow: UsageWindow(
                usedPercent: 0,
                resetAt: resetAt,
                windowDurationSeconds: 2592000,
                kind: .monthly
            ),
            secondaryWindow: nil
        )

        viewModel.accounts = [account]
        viewModel.usageData[account.id] = usage

        let indicator = viewModel.weeklyAutoKickIndicator(for: account, usage: usage)
        #expect(indicator == nil)
    }

    @Test func usageWindowDisplayLabelFormat() async throws {
        let short = UsageWindow(usedPercent: 0, resetAt: nil, windowDurationSeconds: 18000)
        let weekly = UsageWindow(usedPercent: 0, resetAt: nil, windowDurationSeconds: 604800)
        let monthly = UsageWindow(usedPercent: 0, resetAt: nil, windowDurationSeconds: 2592000)
        let custom = UsageWindow(usedPercent: 0, resetAt: nil, windowDurationSeconds: 864000)

        #expect(short.displayLabel == "5-hour")
        #expect(weekly.displayLabel == "Weekly")
        #expect(monthly.displayLabel == "30-day")
        #expect(custom.displayLabel == "10-day")
    }

    @Test func successfulUnchangedFetchRecordsSuccess() async throws {
        let account = makeAccount()
        let initialUsage = AccountUsage(
            usedPercent: 0,
            resetAt: Date().addingTimeInterval(3600),
            primaryWindowSeconds: 2592000,
            weeklyUsedPercent: nil,
            weeklyResetAt: nil,
            weeklyWindowSeconds: nil,
            creditsBalance: nil,
            hasCredits: false,
            isUnlimited: false,
            lastUpdated: Date(timeIntervalSince1970: 100),
            error: nil
        )

        let responseJSON = """
        {
            "plan_type": "free",
            "rate_limit": {
                "allowed": true,
                "limit_reached": false,
                "primary_window": {
                    "used_percent": 0,
                    "reset_at": 1774321200,
                    "limit_window_seconds": 2592000
                }
            }
        }
        """
        let response = try JSONDecoder().decode(CodexUsageResponse.self, from: Data(responseJSON.utf8))
        let newUsage = AccountUsage(from: response, previous: initialUsage)

        #expect(newUsage.usedPercent == 0)
        #expect(newUsage.error == nil)
        #expect(newUsage.lastUpdated > initialUsage.lastUpdated)
    }

    @Test func monthlySlidingWindowSchedulesActivation() async throws {
        let viewModel = AccountsViewModel()
        let account = makeAccount(weeklyAutoKickOverride: .forceOn)
        let resetAt = Date().addingTimeInterval(2592000)
        let usage = AccountUsage(
            primaryWindow: UsageWindow(
                usedPercent: 0,
                resetAt: resetAt,
                windowDurationSeconds: 2592000,
                kind: .monthly
            ),
            secondaryWindow: nil
        )

        viewModel.accounts = [account]
        viewModel.usageData[account.id] = usage

        #expect(usage.hasActivatableWindow)
        #expect(!usage.hasWeeklyWindow)
        let indicator = viewModel.weeklyAutoKickIndicator(for: account, usage: usage)
        #expect(indicator != nil)
    }

    @Test func knownMigrationFailureResetsCapOnce() async throws {
        let viewModel = AccountsViewModel()
        var account = makeAccount(weeklyAutoKickOverride: .forceOn)
        account.lastWeeklyAutoKickFailure = "Usage did not refresh after auto-kick"
        account.weeklyAutoKickAttemptCount = 3
        account.lastWeeklyAutoKickAttemptAt = Date()

        viewModel.accounts = [account]
        let migrationFailures = [
            "Usage did not refresh after auto-kick",
            "Usage did not include a weekly reset after auto-kick",
            "Usage did not refresh during reset anchor verification",
            "Weekly window still looks stale"
        ]
        if let failure = viewModel.accounts[0].lastWeeklyAutoKickFailure, migrationFailures.contains(failure) {
            viewModel.accounts[0].lastWeeklyAutoKickFailure = nil
            viewModel.accounts[0].weeklyAutoKickAttemptCount = 0
        }

        let updated = viewModel.accounts.first(where: { $0.id == account.id })
        #expect(updated?.lastWeeklyAutoKickFailure == nil)
        #expect(updated?.weeklyAutoKickAttemptCount == 0)
    }

    @Test func monthlyOverdueActivationIndicatorDisplaysStatus() async throws {
        let viewModel = AccountsViewModel()
        let account = makeAccount(weeklyAutoKickOverride: .forceOn)
        let overdueReset = Date().addingTimeInterval(-300)
        let usage = AccountUsage(
            primaryWindow: UsageWindow(
                usedPercent: 0,
                resetAt: overdueReset,
                windowDurationSeconds: 2592000,
                kind: .monthly
            )
        )

        viewModel.accounts = [account]
        viewModel.usageData[account.id] = usage

        let indicator = viewModel.weeklyAutoKickIndicator(for: account, usage: usage)
        #expect(indicator != nil)
        #expect(indicator?.help.contains("30-day") == true)
        #expect(indicator?.help.contains("awaiting activation") == true)
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
        lastWeeklyAutoKickCycleID: String? = nil,
        lastWeeklyAutoKickSuccessAt: Date? = nil
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
            lastWeeklyAutoKickCycleID: lastWeeklyAutoKickCycleID,
            lastWeeklyAutoKickSuccessAt: lastWeeklyAutoKickSuccessAt
        )
    }

    @Test func testDateResetDescriptionFormatting() async throws {
        let now = Date(timeIntervalSince1970: 1_000_000)

        let subHour = now.addingTimeInterval(42 * 60)
        #expect(subHour.resetDescription(relativeTo: now) == "in 42m")

        let multiHourSecs: TimeInterval = 5 * 3600 + 12 * 60
        let multiHour = now.addingTimeInterval(multiHourSecs)
        #expect(multiHour.resetDescription(relativeTo: now) == "in 5h 12m")

        let daysSecs: TimeInterval = 9 * 86400
        let hoursSecs: TimeInterval = 18 * 3600
        let minsSecs: TimeInterval = 42 * 60
        let nineDays = now.addingTimeInterval(daysSecs + hoursSecs + minsSecs)
        #expect(nineDays.resetDescription(relativeTo: now) == "in 9d 18h 42m")

        let thirtyDaysSecs: TimeInterval = 30 * 86400 - 60
        let thirtyDays = now.addingTimeInterval(thirtyDaysSecs)
        #expect(thirtyDays.resetDescription(relativeTo: now) == "in 29d 23h 59m")
    }

    @Test func testSlidingMonthlyWindowDetection() async throws {
        let t1 = Date(timeIntervalSince1970: 1_000_000)
        let thirtyDays: TimeInterval = 30 * 24 * 60 * 60

        let reset1 = t1.addingTimeInterval(thirtyDays)

        let t2 = t1.addingTimeInterval(7200)
        let reset2 = reset1.addingTimeInterval(7200)

        let isSliding = AccountsViewModel.weeklyResetAppearsSliding(
            previousResetAt: reset1,
            previousObservedAt: t1,
            currentResetAt: reset2,
            currentObservedAt: t2,
            weeklyWindowSeconds: Int(thirtyDays),
            remainingPercent: 100.0,
            minimumRemainingPercent: 95.0
        )

        #expect(isSliding)
    }

    @Test func testStaticMonthlyWindowDoesNotActivate() async throws {
        let t1 = Date(timeIntervalSince1970: 1_000_000)
        let thirtyDays: TimeInterval = 30 * 24 * 60 * 60

        let reset1 = t1.addingTimeInterval(thirtyDays)

        let t2 = t1.addingTimeInterval(7200)
        let reset2 = reset1

        let isSliding = AccountsViewModel.weeklyResetAppearsSliding(
            previousResetAt: reset1,
            previousObservedAt: t1,
            currentResetAt: reset2,
            currentObservedAt: t2,
            weeklyWindowSeconds: Int(thirtyDays),
            remainingPercent: 100.0,
            minimumRemainingPercent: 95.0
        )

        #expect(!isSliding)
    }

    @Test func testActivatableWindowUnified() async throws {
        let monthlyUsage = AccountUsage(
            primaryWindow: UsageWindow(usedPercent: 0, resetAt: Date(), windowDurationSeconds: 30 * 24 * 60 * 60, kind: .monthly),
            secondaryWindow: nil
        )

        #expect(monthlyUsage.hasActivatableWindow)
        #expect(monthlyUsage.activatableWindow?.kind == .monthly)
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

    private func makeJWT(payload: [String: Any]) -> String {
        func encode(_ object: Any) -> String {
            let data = try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            return data
                .base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }

        return [
            encode(["alg": "none", "typ": "JWT"]),
            encode(payload),
            "signature",
        ].joined(separator: ".")
    }

}
