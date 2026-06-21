import Foundation

enum SurveyCSVExporter {
    static func writeFile(for survey: Survey) throws -> URL {
        let header = ["回答番号", "回答日時"] + survey.questions.map { question in
            question.title.isEmpty ? "無題の質問" : question.title
        }

        let rows = survey.responses.reversed().enumerated().map { offset, response in
            [
                String(offset + 1),
                response.submittedAt.formatted(.iso8601)
            ] + survey.questions.map { question in
                response.answers
                    .first(where: { $0.questionID == question.id })?
                    .values
                    .filter { !$0.isEmpty }
                    .joined(separator: "、") ?? ""
            }
        }

        let csv = ([header] + rows)
            .map { $0.map(escaped).joined(separator: ",") }
            .joined(separator: "\r\n")
        let data = Data(("\u{FEFF}" + csv + "\r\n").utf8)

        let fileName = sanitizedFileName(survey.title) + "-回答結果.csv"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    nonisolated private static func escaped(_ value: String) -> String {
        let formulaPrefixes: Set<Character> = ["=", "+", "-", "@"]
        let trimmed = value.drop(while: { $0.isWhitespace })
        let safeValue = trimmed.first.map(formulaPrefixes.contains) == true ? "'" + value : value
        return "\"" + safeValue.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    nonisolated private static func sanitizedFileName(_ value: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\:?%*|\"<>\n\r\t")
        let sanitized = value
            .components(separatedBy: invalidCharacters)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.isEmpty ? "アンケート" : sanitized
    }
}
