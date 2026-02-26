//
//  TestMessageService.swift
//  CodexAccounts
//
//  Created by Sameer Bajaj on 2/25/26.
//

import Foundation

struct TestMessageResult: Equatable {
    let success: Bool
    let message: String
    let timestamp: Date

    static func ok(_ text: String) -> TestMessageResult {
        TestMessageResult(success: true, message: text, timestamp: Date())
    }

    static func fail(_ text: String) -> TestMessageResult {
        TestMessageResult(success: false, message: text, timestamp: Date())
    }
}

enum TestMessageService {
    private static let cliTimeout: TimeInterval = 45
    private static let primaryResponsesURL = "https://api.openai.com/v1/responses"
    private static let fallbackResponsesURL = "https://chatgpt.com/backend-api/responses"

    static func send(account: CodexAccount) async -> TestMessageResult {
        if let cliResult = await sendViaCLI(account: account) {
            return cliResult
        }

        return await sendViaAPI(account: account)
    }

    private static func sendViaCLI(account: CodexAccount) async -> TestMessageResult? {
        let fm = FileManager.default
        let runRoot = fm.temporaryDirectory.appendingPathComponent("CodexAccounts-Test-\(UUID().uuidString)")
        let codexHome = runRoot.appendingPathComponent(".codex")
        let authURL = codexHome.appendingPathComponent("auth.json")
        let outputURL = runRoot.appendingPathComponent("last-message.txt")

        do {
            try fm.createDirectory(at: codexHome, withIntermediateDirectories: true)
            try writeAuthFile(account: account, to: authURL)
        } catch {
            return nil
        }

        defer {
            try? fm.removeItem(at: runRoot)
        }

        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "codex", "exec",
            "--skip-git-repo-check",
            "--ephemeral",
            "--sandbox", "read-only",
            "--color", "never",
            "--output-last-message", outputURL.path,
            "-C", runRoot.path,
            "Reply with exactly: OK"
        ]

        var env = ProcessInfo.processInfo.environment
        env["CODEX_HOME"] = codexHome.path
        env.removeValue(forKey: "OPENAI_API_KEY")
        env.removeValue(forKey: "OPENAI_ORG_ID")
        env.removeValue(forKey: "OPENAI_PROJECT_ID")
        env.removeValue(forKey: "OPENAI_BASE_URL")
        process.environment = env
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            return nil
        }

        let finished = await waitForProcess(process, timeout: cliTimeout)
        if !finished {
            process.terminate()
            return .fail("Codex CLI timed out")
        }

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let outputMessage = (try? String(contentsOf: outputURL, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if process.terminationStatus == 0 {
            let msg = !outputMessage.isEmpty
                ? outputMessage
                : (!stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                    : "OK")
            return .ok(msg)
        }

        let errorText = pickErrorText(outputMessage: outputMessage, stderr: stderr, stdout: stdout)
        return .fail(errorText)
    }

    private static func sendViaAPI(account: CodexAccount) async -> TestMessageResult {
        let body: [String: Any] = [
            "model": "codex-mini-latest",
            "input": "Reply with exactly: OK",
            "max_output_tokens": 16
        ]

        let payload: Data
        do {
            payload = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return .fail("Failed to encode request")
        }

        let primary = await sendOnce(
            urlString: primaryResponsesURL,
            payload: payload,
            account: account
        )

        if primary.success {
            return primary
        }

        // If the primary path is rejected for permission/auth reasons, try the
        // chatgpt backend route used by ChatGPT OAuth-backed flows.
        if shouldTryFallback(for: primary.message) {
            let fallback = await sendOnce(
                urlString: fallbackResponsesURL,
                payload: payload,
                account: account
            )
            if fallback.success {
                return fallback
            }
            // Return whichever error is more actionable.
            if fallback.message.count > primary.message.count {
                return fallback
            }
        }

        return primary
    }

    private static func waitForProcess(_ process: Process, timeout: TimeInterval) async -> Bool {
        await withCheckedContinuation { continuation in
            let queue = DispatchQueue.global(qos: .userInitiated)
            queue.async {
                let deadline = Date().addingTimeInterval(timeout)
                while process.isRunning && Date() < deadline {
                    Thread.sleep(forTimeInterval: 0.1)
                }
                continuation.resume(returning: !process.isRunning)
            }
        }
    }

    private static func writeAuthFile(account: CodexAccount, to url: URL) throws {
        var tokenMap: [String: Any] = [
            "access_token": account.accessToken,
            "refresh_token": account.refreshToken,
        ]
        if let idToken = account.idToken, !idToken.isEmpty {
            tokenMap["id_token"] = idToken
        }
        if let accountId = account.accountId, !accountId.isEmpty {
            tokenMap["account_id"] = accountId
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let authMap: [String: Any] = [
            "auth_mode": "chatgpt",
            "tokens": tokenMap,
            "last_refresh": formatter.string(from: account.lastTokenRefresh ?? Date()),
        ]

        let data = try JSONSerialization.data(withJSONObject: authMap)
        try data.write(to: url, options: .atomic)
    }

    private static func pickErrorText(outputMessage: String, stderr: String, stdout: String) -> String {
        let cleanedOutput = outputMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanedOutput.isEmpty { return cleanedOutput }

        let cleanedStderr = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanedStderr.isEmpty { return cleanedStderr }

        let cleanedStdout = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanedStdout.isEmpty { return cleanedStdout }

        return "Codex CLI failed"
    }

    private static func sendOnce(
        urlString: String,
        payload: Data,
        account: CodexAccount
    ) async -> TestMessageResult {
        guard let url = URL(string: urlString) else {
            return .fail("Invalid API URL")
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 30
        req.setValue("Bearer \(account.accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("CodexAccounts/1.0", forHTTPHeaderField: "User-Agent")
        if let accountId = account.accountId, !accountId.isEmpty {
            req.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-Id")
        }
        req.httpBody = payload

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            return .fail("Network error: \(error.localizedDescription)")
        }

        guard let http = response as? HTTPURLResponse else {
            return .fail("Invalid response")
        }

        let bodyString = String(data: data, encoding: .utf8) ?? "(empty)"

        guard http.statusCode >= 200, http.statusCode < 300 else {
            // Try to extract a useful error message from the JSON body
            let errorMessage = Self.extractErrorMessage(from: data)
                ?? "HTTP \(http.statusCode): \(bodyString.prefix(200))"
            return .fail(errorMessage)
        }

        // Extract the model's output text from the response
        let outputText = Self.extractOutputText(from: data) ?? bodyString.prefix(200).description
        return .ok(outputText)
    }

    private static func shouldTryFallback(for message: String) -> Bool {
        let lower = message.lowercased()
        return lower.contains("insufficient")
            || lower.contains("permission")
            || lower.contains("forbidden")
            || lower.contains("not allowed")
            || lower.contains("auth")
            || lower.contains("401")
            || lower.contains("403")
    }

    // MARK: - JSON Parsing Helpers

    private static func extractErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        // OpenAI error shape: { "error": { "message": "...", "code": "..." } }
        if let error = json["error"] as? [String: Any] {
            let code = error["code"] as? String ?? ""
            let message = error["message"] as? String ?? ""
            if !code.isEmpty && !message.isEmpty {
                return "\(code): \(message)"
            }
            return message.isEmpty ? code : message
        }
        return nil
    }

    private static func extractOutputText(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        // Responses API shape: { "output": [ { "type": "message", "content": [ { "text": "..." } ] } ] }
        if let output = json["output"] as? [[String: Any]] {
            for item in output {
                if let content = item["content"] as? [[String: Any]] {
                    for block in content {
                        if let text = block["text"] as? String {
                            return text
                        }
                    }
                }
            }
        }
        return nil
    }
}
