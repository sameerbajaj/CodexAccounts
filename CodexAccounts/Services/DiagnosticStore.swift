//
//  DiagnosticStore.swift
//  CodexAccounts
//

import Foundation

enum DiagnosticStore {
    private static var tracesURL: URL {
        AccountStore.storeDirectory.appendingPathComponent("diagnostic_traces.json")
    }

    static func loadTraces() -> [ActivationDiagnosticTrace] {
        guard let data = try? Data(contentsOf: tracesURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([ActivationDiagnosticTrace].self, from: data)) ?? []
    }

    static func saveTraces(_ traces: [ActivationDiagnosticTrace]) {
        do {
            try FileManager.default.createDirectory(
                at: AccountStore.storeDirectory,
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(traces)
            try data.write(to: tracesURL, options: .atomic)
        } catch {
            print("DiagnosticStore: Failed to save traces: \(error)")
        }
    }
}
