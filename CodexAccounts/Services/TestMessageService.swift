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
    /// Same endpoint the Codex CLI hits internally.
    private static let responsesURL = "https://api.openai.com/v1/responses"

    /// Sends a minimal test prompt to `codex-mini-latest` using the account's
    /// OAuth Bearer token and returns the full model response or error text.
    static func send(account: CodexAccount) async -> TestMessageResult {
        guard let url = URL(string: responsesURL) else {
            return .fail("Invalid API URL")
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 30
        req.setValue("Bearer \(account.accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("CodexAccounts/1.0", forHTTPHeaderField: "User-Agent")

        let body: [String: Any] = [
            "model": "codex-mini-latest",
            "input": "Reply with exactly: OK",
            "max_output_tokens": 16
        ]

        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return .fail("Failed to encode request")
        }

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
