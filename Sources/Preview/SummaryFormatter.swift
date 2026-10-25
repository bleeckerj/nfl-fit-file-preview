import Foundation

enum SummaryFormatter {
    static func details(for summary: RouteSummary) -> String {
        var items: [String] = []
        if let date = summary.date {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            items.append(formatter.string(from: date))
        }
        if let distance = summary.distanceMeters {
            let formatter = MeasurementFormatter()
            formatter.unitStyle = .short
            formatter.unitOptions = .providedUnit
            formatter.numberFormatter.maximumFractionDigits = 1
            let unit: UnitLength = Locale.current.measurementSystem == .us ? .miles : .kilometers
            let text = formatter.string(from: Measurement(value: distance, unit: UnitLength.meters).converted(to: unit))
            items.append(summary.distanceIsEstimated ? "Approx. \(text)" : text)
        }
        if let duration = summary.durationSeconds {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute, .second]
            formatter.unitsStyle = .abbreviated
            formatter.maximumUnitCount = 3
            if let text = formatter.string(from: duration) {
                items.append("\(summary.durationIsElapsed ? "Elapsed" : "Activity time"): \(text)")
            }
        }
        return items.isEmpty ? "No recorded summary available" : items.joined(separator: "   ·   ")
    }
}
