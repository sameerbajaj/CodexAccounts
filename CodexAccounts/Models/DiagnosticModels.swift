//
//  DiagnosticModels.swift
//  CodexAccounts
//

import Foundation

struct DiagnosticUsageSnapshot: Codable, Equatable, Identifiable {
    var id: String { label }
    let label: String // "Pre-activation (+0s)", "+30s", "+2m", "+10m"
    let timestamp: Date
    let usedPercent: Double?
    let resetAt: Date?
    let resetAfterSeconds: Double?
    let planType: String?
}

struct ActivationDiagnosticTrace: Codable, Identifiable, Equatable {
    let id: UUID
    let accountIdSuffix: String
    let experimentName: String
    let deliveryMethod: String
    let cliVersion: String?
    let exitCode: Int?
    let outputMessageProduced: Bool
    let runRootPath: String?
    let startedAt: Date
    var snapshots: [DiagnosticUsageSnapshot]
    var status: TraceStatus

    enum TraceStatus: Codable, Equatable {
        case inProgress(currentStep: String)
        case completed
        case failed(reason: String)

        enum CodingKeys: String, CodingKey {
            case kind, currentStep, reason
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .inProgress(let step):
                try container.encode("inProgress", forKey: .kind)
                try container.encode(step, forKey: .currentStep)
            case .completed:
                try container.encode("completed", forKey: .kind)
            case .failed(let reason):
                try container.encode("failed", forKey: .kind)
                try container.encode(reason, forKey: .reason)
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let kind = try container.decode(String.self, forKey: .kind)
            switch kind {
            case "inProgress":
                let step = (try? container.decode(String.self, forKey: .currentStep)) ?? "Running..."
                self = .inProgress(currentStep: step)
            case "completed":
                self = .completed
            case "failed":
                let reason = (try? container.decode(String.self, forKey: .reason)) ?? "Failed"
                self = .failed(reason: reason)
            default:
                self = .completed
            }
        }
    }
}

enum DiagnosticExperiment: String, CaseIterable, Identifiable {
    case ephemeralPrompt = "Experiment 1: Ephemeral Prompt"
    case normalSmallTask = "Experiment 2: Normal Small Task"

    var id: String { rawValue }

    var title: String { rawValue }

    var isEphemeral: Bool {
        switch self {
        case .ephemeralPrompt: return true
        case .normalSmallTask: return false
        }
    }

    var description: String {
        switch self {
        case .ephemeralPrompt:
            return "Current minimal activation prompt with --ephemeral CLI flag."
        case .normalSmallTask:
            return "Small normal Codex session task without --ephemeral CLI flag."
        }
    }
}
