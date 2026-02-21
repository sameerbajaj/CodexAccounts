//
//  DateExtensions.swift
//  CodexAccounts
//
//  Created by Sameer Bajaj on 2/21/26.
//

import Foundation

extension Date {
    /// Human-readable relative time, e.g. "2 min. ago"
    var relativeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    /// Countdown description for reset times, e.g. "in 2h 15m"
    var resetDescription: String {
        let interval = self.timeIntervalSince(Date())
        if interval <= 0 { return "now" }

        let totalMinutes = Int(interval / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours >= 24 {
            let days = hours / 24
            let remainingHours = hours % 24
            return "in \(days)d \(remainingHours)h"
        } else if hours > 0 {
            return "in \(hours)h \(minutes)m"
        } else {
            return "in \(minutes)m"
        }
    }
}
