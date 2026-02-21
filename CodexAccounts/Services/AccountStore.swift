//
//  AccountStore.swift
//  CodexAccounts
//
//  Created by Sameer Bajaj on 2/21/26.
//

import Foundation

enum AccountStore {
    private static var storeDirectory: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport.appendingPathComponent("CodexAccounts")
    }

    private static var storeURL: URL {
        storeDirectory.appendingPathComponent("accounts.json")
    }

    static func load() -> [CodexAccount] {
        guard let data = try? Data(contentsOf: storeURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([CodexAccount].self, from: data)) ?? []
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
