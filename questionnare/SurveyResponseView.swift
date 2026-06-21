import SwiftUI

struct SurveyResponseView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SurveyStore
    let surveyID: UUID
    private let editingResponse: SurveyResponse?
    @State private var answers: [UUID: [String]]
    @State private var showingValidation = false
    @State private var showingCompletion = false

    init(surveyID: UUID, editing response: SurveyResponse? = nil) {
        self.surveyID = surveyID
        editingResponse = response
        _answers = State(initialValue: Dictionary(
            uniqueKeysWithValues: response?.answers.map { ($0.questionID, $0.values) } ?? []
        ))
    }

    var body: some View {
        NavigationStack {
            if let survey = store.survey(withID: surveyID) {
                Form {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(survey.title)
                                .font(.title2.bold())
                            if !survey.details.isEmpty {
                                Text(survey.details)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                    }

                    ForEach(Array(survey.questions.enumerated()), id: \.element.id) { index, question in
                        Section {
                            AnswerInput(question: question, values: binding(for: question.id))
                        } header: {
                            HStack {
                                Text("\(index + 1). \(question.title.isEmpty ? "無題の質問" : question.title)")
                                if question.isRequired {
                                    Text("必須").foregroundStyle(.red)
                                }
                            }
                            .textCase(nil)
                        }
                    }

                    Section {
                        Button {
                            submit(survey)
                        } label: {
                            Text(editingResponse == nil ? "回答を送信" : "変更を保存")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }
                .navigationTitle(editingResponse == nil ? "回答" : "回答を修正")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") { dismiss() }
                    }
                }
                .alert("未回答の必須項目があります", isPresented: $showingValidation) {
                    Button("確認する", role: .cancel) {}
                } message: {
                    Text("「必須」と表示された質問に回答してください。")
                }
                .alert(editingResponse == nil ? "回答を保存しました" : "回答を更新しました", isPresented: $showingCompletion) {
                    Button("完了") { dismiss() }
                } message: {
                    Text("回答はこの端末内に保存されています。")
                }
            }
        }
        .interactiveDismissDisabled()
    }

    private func binding(for questionID: UUID) -> Binding<[String]> {
        Binding(
            get: { answers[questionID, default: []] },
            set: { answers[questionID] = $0 }
        )
    }

    private func submit(_ survey: Survey) {
        let missingRequired = survey.questions.contains { question in
            guard question.isRequired else { return false }
            return answers[question.id, default: []]
                .allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
        guard !missingRequired else {
            showingValidation = true
            return
        }

        let updatedAnswers = survey.questions.map { question in
            QuestionAnswer(questionID: question.id, values: answers[question.id, default: []])
        }
        if var response = editingResponse {
            response.answers = updatedAnswers
            store.updateResponse(response, in: survey.id)
        } else {
            store.submit(SurveyResponse(answers: updatedAnswers), to: survey.id)
        }
        showingCompletion = true
    }
}

private struct AnswerInput: View {
    let question: SurveyQuestion
    @Binding var values: [String]

    var body: some View {
        switch question.type {
        case .shortText:
            TextField("回答を入力", text: firstValue)
        case .longText:
            TextField("回答を入力", text: firstValue, axis: .vertical)
                .lineLimit(3...8)
        case .singleChoice:
            ChoiceGrid(options: question.options, selectedValues: $values, allowsMultipleSelection: false)
        case .multipleChoice:
            ChoiceGrid(options: question.options, selectedValues: $values, allowsMultipleSelection: true)
        case .rating:
            HStack {
                ForEach(1...5, id: \.self) { rating in
                    Button {
                        values = [String(rating)]
                    } label: {
                        Image(systemName: selectedRating >= rating ? "star.fill" : "star")
                            .font(.title2)
                            .foregroundStyle(.yellow)
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 0)
                }
            }
        case .yesNo:
            ChoiceGrid(options: ["はい", "いいえ"], selectedValues: $values, allowsMultipleSelection: false)
        }
    }

    private var firstValue: Binding<String> {
        Binding(
            get: { values.first ?? "" },
            set: { values = [$0] }
        )
    }

    private var selectedRating: Int {
        Int(values.first ?? "") ?? 0
    }
}

private struct ChoiceGrid: View {
    let options: [String]
    @Binding var selectedValues: [String]
    let allowsMultipleSelection: Bool

    private var columns: [GridItem] {
        let columnCount: Int
        switch options.count {
        case ...1: columnCount = 1
        case 2: columnCount = 2
        case 3: columnCount = 3
        case 4: columnCount = 2
        default: columnCount = 3
        }
        return Array(repeating: GridItem(.flexible(), spacing: 8), count: columnCount)
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(options, id: \.self) { option in
                Button {
                    select(option)
                } label: {
                    HStack(spacing: 6) {
                        Text(option)
                            .font(.callout)
                            .foregroundStyle(isSelected(option) ? .blue : .primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 2)
                        Image(systemName: selectionImage(for: option))
                            .foregroundStyle(isSelected(option) ? .blue : .secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(isSelected(option) ? Color.blue.opacity(0.1) : Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected(option) ? Color.blue.opacity(0.55) : Color.secondary.opacity(0.18))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func isSelected(_ option: String) -> Bool {
        selectedValues.contains(option)
    }

    private func selectionImage(for option: String) -> String {
        if allowsMultipleSelection {
            return isSelected(option) ? "checkmark.square.fill" : "square"
        }
        return isSelected(option) ? "circle.inset.filled" : "circle"
    }

    private func select(_ option: String) {
        if allowsMultipleSelection {
            if isSelected(option) {
                selectedValues.removeAll { $0 == option }
            } else {
                selectedValues.append(option)
            }
        } else {
            selectedValues = [option]
        }
    }
}
