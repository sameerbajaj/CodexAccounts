//
//  DiagnosticTraceView.swift
//  CodexAccounts
//

import SwiftUI

struct DiagnosticTraceView: View {
    let traces: [ActivationDiagnosticTrace]
    let theme: ThemeColors
    let onClear: () -> Void

    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        return df
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("Diagnostic Activation Traces")
                    .font(AppTypography.headline)
                    .foregroundColor(theme.textPrimary)

                Spacer()

                if !traces.isEmpty {
                    Button(action: onClear) {
                        Text("Clear Traces")
                            .font(AppTypography.caption)
                            .foregroundColor(theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if traces.isEmpty {
                VStack(spacing: AppSpacing.xs) {
                    Image(systemName: "stethoscope")
                        .font(.system(size: 24))
                        .foregroundColor(theme.textTertiary)
                    Text("No diagnostic traces recorded yet.")
                        .font(AppTypography.caption)
                        .foregroundColor(theme.textTertiary)
                    Text("Trigger Experiment 1 or 2 from an account's context menu.")
                        .font(AppTypography.caption)
                        .foregroundColor(theme.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(AppSpacing.lg)
                .background(theme.surfaceSecondary)
                .cornerRadius(AppCornerRadius.md)
            } else {
                ForEach(traces) { trace in
                    traceCard(trace)
                }
            }
        }
    }

    @ViewBuilder
    private func traceCard(_ trace: ActivationDiagnosticTrace) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Header: Experiment Name & Status
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(trace.experimentName)
                        .font(AppTypography.title)
                        .foregroundColor(theme.textPrimary)
                    Text("Account Suffix: ...\(trace.accountIdSuffix) • Started \(dateFormatter.string(from: trace.startedAt))")
                        .font(AppTypography.caption)
                        .foregroundColor(theme.textSecondary)
                }

                Spacer()

                statusBadge(trace.status)
            }

            Divider()
                .background(theme.divider)

            // Metadata Grid
            Grid(alignment: .leading, horizontalSpacing: AppSpacing.md, verticalSpacing: 4) {
                GridRow {
                    Text("Delivery:").font(AppTypography.caption).foregroundColor(theme.textTertiary)
                    Text(trace.deliveryMethod).font(AppTypography.captionMedium).foregroundColor(theme.textPrimary)
                    Text("CLI Version:").font(AppTypography.caption).foregroundColor(theme.textTertiary)
                    Text(trace.cliVersion ?? "N/A").font(AppTypography.captionMedium).foregroundColor(theme.textPrimary)
                }
                GridRow {
                    Text("Exit Code:").font(AppTypography.caption).foregroundColor(theme.textTertiary)
                    Text(trace.exitCode != nil ? "\(trace.exitCode!)" : "N/A").font(AppTypography.captionMedium).foregroundColor(theme.textPrimary)
                    Text("Output Produced:").font(AppTypography.caption).foregroundColor(theme.textTertiary)
                    Text(trace.outputMessageProduced ? "Yes" : "No").font(AppTypography.captionMedium).foregroundColor(trace.outputMessageProduced ? theme.accentPrimary : theme.accentSecondary)
                }
            }

            if let rootPath = trace.runRootPath, !rootPath.isEmpty {
                Text("Temp Workspace: \(rootPath)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(theme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            // Snapshots Table
            if !trace.snapshots.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quota Usage Snapshots")
                        .font(AppTypography.captionMedium)
                        .foregroundColor(theme.textSecondary)
                        .padding(.top, 4)

                    Grid(alignment: .leading, horizontalSpacing: AppSpacing.sm, verticalSpacing: 4) {
                        GridRow {
                            Text("Stage").font(AppTypography.captionMedium).foregroundColor(theme.textTertiary)
                            Text("Time").font(AppTypography.captionMedium).foregroundColor(theme.textTertiary)
                            Text("Used %").font(AppTypography.captionMedium).foregroundColor(theme.textTertiary)
                            Text("Reset After (s)").font(AppTypography.captionMedium).foregroundColor(theme.textTertiary)
                            Text("Plan").font(AppTypography.captionMedium).foregroundColor(theme.textTertiary)
                        }

                        ForEach(trace.snapshots) { snap in
                            GridRow {
                                Text(snap.label)
                                    .font(AppTypography.caption)
                                    .foregroundColor(theme.textPrimary)
                                Text(dateFormatter.string(from: snap.timestamp))
                                    .font(AppTypography.caption)
                                    .foregroundColor(theme.textSecondary)
                                Text(snap.usedPercent != nil ? String(format: "%.1f%%", snap.usedPercent!) : "N/A")
                                    .font(AppTypography.captionMedium)
                                    .foregroundColor(theme.textPrimary)
                                Text(snap.resetAfterSeconds != nil ? "\(Int(snap.resetAfterSeconds!))s" : "N/A")
                                    .font(AppTypography.caption)
                                    .foregroundColor(theme.textSecondary)
                                Text(snap.planType ?? "N/A")
                                    .font(AppTypography.caption)
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(AppSpacing.md)
        .background(theme.surfaceSecondary)
        .cornerRadius(AppCornerRadius.md)
    }

    @ViewBuilder
    private func statusBadge(_ status: ActivationDiagnosticTrace.TraceStatus) -> some View {
        switch status {
        case .inProgress(let step):
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.small)
                Text(step)
                    .font(AppTypography.caption)
                    .foregroundColor(theme.accentPrimary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(theme.accentPrimary.opacity(0.15))
            .cornerRadius(12)
        case .completed:
            Text("Completed")
                .font(AppTypography.captionMedium)
                .foregroundColor(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.green.opacity(0.15))
                .cornerRadius(12)
        case .failed(let reason):
            Text("Failed (\(reason))")
                .font(AppTypography.captionMedium)
                .foregroundColor(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.red.opacity(0.15))
                .cornerRadius(12)
        }
    }
}
