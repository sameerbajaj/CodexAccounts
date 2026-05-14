//
//  AccountStore.swift
//  CodexAccounts
//
//  Created by Sameer Bajaj on 2/21/26.
//

import Foundation

enum AccountStore {
    static var storeDirectory: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport.appendingPathComponent("CodexAccounts")
    }

    static var codexHomesDirectory: URL {
        storeDirectory.appendingPathComponent("CodexHomes")
    }

    private static var storeURL: URL {
        storeDirectory.appendingPathComponent("accounts.json")
    }

    static func codexHomeURL(for account: CodexAccount) -> URL {
        let stableID = account.accountId?.isEmpty == false ? account.accountId! : account.id
        let safeID = stableID
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        return codexHomesDirectory.appendingPathComponent(safeID, isDirectory: true)
    }

    static func load() -> [CodexAccount] {
        guard let data = try? Data(contentsOf: storeURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let accounts = try? decoder.decode([CodexAccount].self, from: data) {
            return accounts
        }

        guard let rawRows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return rawRows.compactMap { row in
            guard JSONSerialization.isValidJSONObject(row),
                  let rowData = try? JSONSerialization.data(withJSONObject: row),
                  let account = try? decoder.decode(CodexAccount.self, from: rowData)
            else { return nil }
            return account
        }
    }

    static func save(_ accounts: [CodexAccount]) {
        do {
            try FileManager.default.createDirectory(
                at: storeDirectory,
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(accounts)
            try data.write(to: storeURL, options: .atomic)
        } catch {
            print("AccountStore: Failed to save accounts: \(error)")
        }
    }
}
