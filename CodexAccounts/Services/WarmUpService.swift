//
//  WarmUpService.swift
//  CodexAccounts
//
//  Created by Sameer Bajaj on 2/22/26.
//

import Foundation

enum WarmUpService {
    // Codex CLI uses the OpenAI Responses API internally.
    private static let responsesURL = "https://api.openai.com/v1/responses"

    // MARK: - Errors

    enum WarmUpError: LocalizedError {
        case networkError(String)
        case serverError(Int, String?)

        var errorDescription: String? {
            switch self {
            case .networkError(let msg):
                return "Network: \(msg)"
            case .serverError(let code, let body):
                let hint = body.flatMap { String($0.prefix(80)) } ?? ""
                return "Server \(code)\(hint.isEmpty ? "" : ": \(hint)")"
            }
        }
    }

    // MARK: - Warm-up

    /// Sends a minimal 1-token request to `codex-mini-latest` using the
    /// account's OAuth Bearer token, forcing the model container to spin up.
    static func warmUp(account: CodexAccount) async throws {
        guard let url = URL(string: responsesURL) else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 45
        req.setValue("Bearer \(account.accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("CodexAccounts/1.0", forHTTPHeaderField: "User-Agent")

        let body: [String: Any] = [
            "model": "codex-mini-latest",
            "input": "hi",
            "max_output_tokens": 8
        ]

        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw WarmUpError.networkError(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else { return }

        // 2xx = success (model responded → it's warm)
        guard http.statusCode >= 200 && http.statusCode < 300 else {
            let bodyStr = String(data: data, encoding: .utf8)
            throw WarmUpError.serverError(http.statusCode, bodyStr)
        }
    }
}
