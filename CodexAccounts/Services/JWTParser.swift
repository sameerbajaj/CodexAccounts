//
//  JWTParser.swift
//  CodexAccounts
//
//  Created by Sameer Bajaj on 2/21/26.
//

import Foundation

enum JWTParser {
    struct Claims {
        var email: String?
        var planType: String?
        var accountId: String?
        var userId: String?
    }

    static func parse(_ token: String) -> Claims? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }

        var padded = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while padded.count % 4 != 0 {
            padded.append("=")
        }

        guard let data = Data(base64Encoded: padded),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        var claims = Claims()

        // Extract email from top-level or profile namespace
        claims.email = json["email"] as? String
        if claims.email == nil,
           let profile = json["https://api.openai.com/profile"] as? [String: Any]
        {
            claims.email = profile["email"] as? String
        }

        // Extract plan type and account info from auth namespace
        if let auth = json["https://api.openai.com/auth"] as? [String: Any] {
            claims.planType = auth["chatgpt_plan_type"] as? String
            claims.accountId = auth["chatgpt_account_id"] as? String
            claims.userId = auth["chatgpt_user_id"] as? String
        }
        if claims.planType == nil {
            claims.planType = json["chatgpt_plan_type"] as? String
        }

        return claims
    }
}
