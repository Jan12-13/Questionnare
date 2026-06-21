import SwiftUI

struct SurveyResultsView: View {
    @EnvironmentObject private var store: SurveyStore
    let surveyID: UUID

    var body: some View {
        Group {
            if let survey = store.survey(withID: surveyID) {
                if survey.responses.isEmpty {
                    ContentUnavailableView(
                        "回答はまだありません",
                        systemImage: "chart.bar.xaxis",
                        description: Text("回答が保存されると、ここに集計結果が表示されます。")
                    )
                } else {
                    List {
                        Section {
                            HStack(spacing: 12) {
                                StatCard(title: "回答", value: "\(survey.responses.count)", image: "person.2.fill")
                                StatCard(title: "質問", value: "\(survey.questions.count)", image: "questionmark.circle.fill")
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        }

                        ForEach(survey.questions) { question in
                            Section(question.title.isEmpty ? "無題の質問" : question.title) {
                                QuestionSummary(question: question, responses: survey.responses)
                            }
                        }

                        Section("個別の回答") {
                            ForEach(Array(survey.responses.enumerated()), id: \.element.id) { index, response in
                                NavigationLink {
                                    ResponseDetailView(
                                        surveyID: survey.id,
                                        responseID: response.id,
                                        number: survey.responses.count - index
                                    )
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("回答 \(survey.responses.count - index)")
                                        Text(response.submittedAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .swipeActions {
                                    Button("削除", systemImage: "trash", role: .destructive) {
                                        store.deleteResponse(response.id, from: survey.id)
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView("アンケートがありません", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle("集計結果")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let image: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: image)
                .font(.title2)
                .foregroundStyle(.blue)
            VStack(alignment: .leading) {
                Text(value).font(.title2.bold())
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).stroke(.quaternary) }
    }
}

private struct QuestionSummary: View {
    let question: SurveyQuestion
    let responses: [SurveyResponse]

    private var values: [String] {
        responses.flatMap { response in
            response.answers.first(where: { $0.questionID == question.id })?.values ?? []
        }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        switch question.type {
        case .singleChoice, .multipleChoice, .yesNo:
            let choices = question.type == .yesNo ? ["はい", "いいえ"] : question.options
            ForEach(choices, id: \.self) { choice in
                let count = values.filter { $0 == choice }.count
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(choice)
                        Spacer()
                        Text("\(count)件").foregroundStyle(.secondary)
                    }
                    ProgressView(value: Double(count), total: Double(max(values.count, 1)))
                }
                .padding(.vertical, 2)
            }
        case .rating:
            let ratings = values.compactMap(Double.init)
            let average = ratings.isEmpty ? 0 : ratings.reduce(0, +) / Double(ratings.count)
            HStack {
                Label(String(format: "%.1f", average), systemImage: "star.fill")
                    .font(.title2.bold())
                    .foregroundStyle(.orange)
                Spacer()
                Text("5点満点・\(ratings.count)件")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .shortText, .longText:
            if values.isEmpty {
                Text("回答なし").foregroundStyle(.secondary)
            } else {
                ForEach(Array(values.prefix(3).enumerated()), id: \.offset) { _, value in
                    Text(value).lineLimit(3)
                }
                if values.count > 3 {
                    Text("ほか \(values.count - 3)件")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct ResponseDetailView: View {
    @EnvironmentObject private var store: SurveyStore
    @Environment(\.dismiss) private var dismiss
    let surveyID: UUID
    let responseID: UUID
    let number: Int
    @State private var showingDeleteConfirmation = false
    @State private var showingEditor = false

    var body: some View {
        Group {
            if let survey = store.survey(withID: surveyID),
               let response = survey.responses.first(where: { $0.id == responseID }) {
                List {
                    Section {
                        LabeledContent("保存日時", value: response.submittedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    ForEach(survey.questions) { question in
                        Section(question.title.isEmpty ? "無題の質問" : question.title) {
                            let values = response.answers.first(where: { $0.questionID == question.id })?.values ?? []
                            Text(values.filter { !$0.isEmpty }.isEmpty ? "未回答" : values.joined(separator: "、"))
                                .foregroundStyle(values.filter { !$0.isEmpty }.isEmpty ? .secondary : .primary)
                        }
                    }
                }
                .sheet(isPresented: $showingEditor) {
                    SurveyResponseView(surveyID: surveyID, editing: response)
                }
            } else {
                ContentUnavailableView("回答がありません", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle("回答 \(number)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("修正", systemImage: "pencil") {
                    showingEditor = true
                }
                Button("削除", systemImage: "trash", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            }
        }
        .confirmationDialog("この回答を削除しますか？", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("削除", role: .destructive) {
                store.deleteResponse(responseID, from: surveyID)
                dismiss()
            }
        }
    }
}
