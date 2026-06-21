import Foundation
import Combine

@MainActor
final class SurveyStore: ObservableObject {
    @Published private(set) var surveys: [Survey] = []

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = baseURL.appendingPathComponent("Questionnaire", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("surveys.json")

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        load()
    }

    func addSurvey(from template: SurveyTemplate) -> Survey {
        let survey = Survey(
            title: template.id == "blank" ? "無題のアンケート" : template.title,
            details: "",
            questions: template.questions
        )
        surveys.insert(survey, at: 0)
        save()
        return survey
    }

    @discardableResult
    func importSurvey(_ payload: SurveySharePayload) -> Survey {
        let survey = payload.makeSurvey()
        surveys.insert(survey, at: 0)
        save()
        return survey
    }

    func update(_ survey: Survey) {
        guard let index = surveys.firstIndex(where: { $0.id == survey.id }) else { return }
        var updated = survey
        updated.updatedAt = Date()
        surveys[index] = updated
        sortSurveys()
        save()
    }

    func delete(at offsets: IndexSet) {
        guard AppSettings.isAdministratorMode else { return }
        for index in offsets.sorted(by: >) {
            surveys.remove(at: index)
        }
        save()
    }

    func delete(_ survey: Survey) {
        guard AppSettings.isAdministratorMode else { return }
        surveys.removeAll { $0.id == survey.id }
        save()
    }

    func submit(_ response: SurveyResponse, to surveyID: UUID) {
        guard let index = surveys.firstIndex(where: { $0.id == surveyID }) else { return }
        surveys[index].responses.insert(response, at: 0)
        surveys[index].updatedAt = Date()
        save()
    }

    func updateResponse(_ response: SurveyResponse, in surveyID: UUID) {
        guard let surveyIndex = surveys.firstIndex(where: { $0.id == surveyID }),
              let responseIndex = surveys[surveyIndex].responses.firstIndex(where: { $0.id == response.id }) else { return }
        surveys[surveyIndex].responses[responseIndex] = response
        surveys[surveyIndex].updatedAt = Date()
        save()
    }

    func deleteResponse(_ responseID: UUID, from surveyID: UUID) {
        guard AppSettings.isAdministratorMode else { return }
        guard let index = surveys.firstIndex(where: { $0.id == surveyID }) else { return }
        surveys[index].responses.removeAll { $0.id == responseID }
        save()
    }

    func survey(withID id: UUID) -> Survey? {
        surveys.first { $0.id == id }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? decoder.decode([Survey].self, from: data) else { return }
        surveys = decoded
        sortSurveys()
    }

    private func save() {
        guard let data = try? encoder.encode(surveys) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func sortSurveys() {
        surveys.sort { $0.updatedAt > $1.updatedAt }
    }
}
