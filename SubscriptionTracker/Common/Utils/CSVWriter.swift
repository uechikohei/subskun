import Foundation

struct CSVWriter {
    func makeCSV(headers: [String], rows: [[String]]) -> String {
        var lines = [serialize(row: headers)]
        lines.append(contentsOf: rows.map(serialize))
        return lines.joined(separator: "\n")
    }

    private func serialize(row: [String]) -> String {
        row.map(escape).joined(separator: ",")
    }

    private func escape(_ value: String) -> String {
        if value.contains(",") || value.contains("\n") || value.contains("\"") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
