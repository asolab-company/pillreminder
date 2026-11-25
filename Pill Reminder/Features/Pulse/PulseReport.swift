import CoreTransferable
import Foundation
import UIKit
import UniformTypeIdentifiers

nonisolated struct PulseReport: Transferable {
    enum Format { case pdf, csv }
    let entries: [PulseMeasurementEntry]
    let format: Format

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pdf) { report in
            await report.pdf()
        }
        .exportingCondition { $0.format == .pdf }
        .suggestedFileName("Pulse history.pdf")
        DataRepresentation(exportedContentType: .commaSeparatedText) { report in
            report.csv()
        }
        .exportingCondition { $0.format == .csv }
        .suggestedFileName("Pulse history.csv")
    }

    func csv() -> Data {
        let rows = entries.map { "\($0.measuredAt.ISO8601Format()),\($0.bpm)" }
        return Data((["Time (UTC),Pulse (bpm)"] + rows + [""]).joined(separator: "\r\n").utf8)
    }

    @MainActor func pdf() -> Data {
        let paper = CGRect(x: 0, y: 0, width: 595, height: 842)
        let time = DateFormatter()
        time.dateStyle = .medium
        time.timeStyle = .medium
        time.timeZone = .current
        return UIGraphicsPDFRenderer(bounds: paper).pdfData { context in
            let rowsPerPage = 30
            let pageCount = max(1, (entries.count + rowsPerPage - 1) / rowsPerPage)
            func draw(_ text: String, x: CGFloat, y: CGFloat, font: UIFont) {
                (text as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: [.font: font, .foregroundColor: UIColor.black])
            }
            for page in 0..<pageCount {
                context.beginPage()
                draw("Pulse history", x: 42, y: 34, font: .boldSystemFont(ofSize: 24))
                draw("Dates shown in \(time.timeZone.identifier)", x: 42, y: 70, font: .systemFont(ofSize: 11))
                draw("Date and time", x: 42, y: 99, font: .boldSystemFont(ofSize: 13))
                draw("Pulse (bpm)", x: 425, y: 99, font: .boldSystemFont(ofSize: 13))
                let start = page * rowsPerPage
                for (row, entry) in entries.dropFirst(start).prefix(rowsPerPage).enumerated() {
                    let y = CGFloat(128 + row * 21)
                    draw(time.string(from: entry.measuredAt), x: 42, y: y, font: .systemFont(ofSize: 12))
                    draw(String(entry.bpm), x: 425, y: y, font: .monospacedDigitSystemFont(ofSize: 12, weight: .medium))
                }
                draw("\(page + 1) / \(pageCount)", x: 42, y: 789, font: .systemFont(ofSize: 11))
            }
        }
    }
}
