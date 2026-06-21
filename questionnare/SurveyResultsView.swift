import SwiftUI

struct SurveyResultsView: View {
    @EnvironmentObject private var store: SurveyStore
    @AppStorage(AppSettings.administratorModeKey)
    private var isAdministratorMode = AppSettings.defaultAdministratorMode
    let surveyID: UUID
    @State private var exportURL: URL?
    @State private var exportErrorMessage: String?
    @State private var responsePendingDeletion: SurveyResponse?

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

                        Section("書き出し") {
                            if let exportURL {
                                ShareLink(item: exportURL) {
                                    Label("CSVを書き出す（Excel対応）", systemImage: "tablecells")
                                }
                            } else {
                                Button {
                                    prepareExport(for: survey)
                                } label: {
                                    Label("CSVを準備", systemImage: "tablecells")
                                }
                            }

                        }

                        ForEach(survey.questions) { question in
                            Section(question.title.isEmpty ? "無題の質問" : question.title) {
                                QuestionSummary(question: question, responses: survey.responses)
                            }
                        }

                        Section("個別の回答") {
                            ForEach(Array(survey.responses.enumerated()), id: \.element.id) { index, response in
                                let isPendingDeletion = responsePendingDeletion?.id == response.id
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
                                .offset(x: isPendingDeletion ? -DeletionPendingBackground.width : 0)
                                .animation(.easeInOut(duration: 0.2), value: isPendingDeletion)
                                .listRowBackground(isPendingDeletion ? DeletionPendingBackground() : nil)
                                .swipeActions(allowsFullSwipe: true) {
                                    if isAdministratorMode {
                                        Button("削除", systemImage: "trash", role: .destructive) {
                                            responsePendingDeletion = response
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .task(id: survey.updatedAt) {
                        prepareExport(for: survey)
                    }
                }
            } else {
                ContentUnavailableView("アンケートがありません", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle("集計結果")
        .navigationBarTitleDisplayMode(.inline)
        .alert("CSVを書き出せません", isPresented: exportErrorIsPresented) {
            Button("OK") { exportErrorMessage = nil }
        } message: {
            Text(exportErrorMessage ?? "不明なエラーが発生しました。")
        }
        .alert("この回答を削除しますか？", isPresented: responseDeleteIsPresented) {
            Button("キャンセル", role: .cancel) {
                responsePendingDeletion = nil
            }
            Button("削除", role: .destructive) {
                if isAdministratorMode, let responsePendingDeletion {
                    store.deleteResponse(responsePendingDeletion.id, from: surveyID)
                }
                responsePendingDeletion = nil
            }
        } message: {
            Text("選択した回答を削除します。この操作は取り消せません。")
        }
        .onChange(of: isAdministratorMode) {
            if !isAdministratorMode {
                responsePendingDeletion = nil
            }
        }
    }

    private var exportErrorIsPresented: Binding<Bool> {
        Binding(
            get: { exportErrorMessage != nil },
            set: { isPresented in
                if !isPresented { exportErrorMessage = nil }
            }
        )
    }

    private var responseDeleteIsPresented: Binding<Bool> {
        Binding(
            get: { responsePendingDeletion != nil },
            set: { isPresented in
                if !isPresented { responsePendingDeletion = nil }
            }
        )
    }

    private func prepareExport(for survey: Survey) {
        do {
            exportURL = try SurveyCSVExporter.writeFile(for: survey)
            exportErrorMessage = nil
        } catch {
            exportURL = nil
            exportErrorMessage = error.localizedDescription
        }
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
            NavigationLink {
                TextAnswerListView(question: question, responses: responses)
            } label: {
                HStack {
                    Label(
                        "回答を見る",
                        systemImage: question.type == .shortText ? "text.cursor" : "text.alignleft"
                    )
                    Spacer()
                    Text("\(values.count)件")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct TextAnswerItem: Identifiable {
    let id: UUID
    let number: Int
    let submittedAt: Date
    let value: String
}

private struct TextAnswerListView: View {
    let question: SurveyQuestion
    let responses: [SurveyResponse]

    private var items: [TextAnswerItem] {
        responses.enumerated().compactMap { index, response in
            let values = response.answers
                .first(where: { $0.questionID == question.id })?
                .values
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? []
            guard !values.isEmpty else { return nil }

            return TextAnswerItem(
                id: response.id,
                number: responses.count - index,
                submittedAt: response.submittedAt,
                value: values.joined(separator: "\n")
            )
        }
    }

    var body: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView(
                    "回答はありません",
                    systemImage: "text.bubble",
                    description: Text("この質問へのテキスト回答はまだありません。")
                )
            } else {
                List {
                    Section("質問") {
                        Text(question.title.isEmpty ? "無題の質問" : question.title)
                    }

                    Section("回答（\(items.count)件）") {
                        ForEach(items) { item in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(item.value)
                                    .textSelection(.enabled)

                                HStack {
                                    Text("回答 \(item.number)")
                                    Spacer()
                                    Text(item.submittedAt.formatted(date: .abbreviated, time: .shortened))
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .navigationTitle("回答一覧")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ResponseDetailView: View {
    @EnvironmentObject private var store: SurveyStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettings.administratorModeKey)
    private var isAdministratorMode = AppSettings.defaultAdministratorMode
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
                if isAdministratorMode {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label(
                            showingDeleteConfirmation ? "削除確認中" : "削除",
                            systemImage: showingDeleteConfirmation ? "trash.fill" : "trash"
                        )
                    }
                }
            }
        }
        .alert("この回答を削除しますか？", isPresented: $showingDeleteConfirmation) {
            Button("キャンセル", role: .cancel) {
                showingDeleteConfirmation = false
            }
            Button("削除", role: .destructive) {
                if isAdministratorMode {
                    store.deleteResponse(responseID, from: surveyID)
                }
                showingDeleteConfirmation = false
                if isAdministratorMode {
                    dismiss()
                }
            }
        } message: {
            Text("保存済みの回答を削除します。この操作は取り消せません。")
        }
        .onChange(of: isAdministratorMode) {
            if !isAdministratorMode {
                showingDeleteConfirmation = false
            }
        }
    }
}
