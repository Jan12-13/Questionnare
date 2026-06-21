import SwiftUI

struct SurveyEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SurveyStore
    @State private var draft: Survey
    @State private var showingQuestionTypes = false

    init(survey: Survey) {
        _draft = State(initialValue: survey)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
                    TextField("アンケート名", text: $draft.title)
                    TextField("説明（任意）", text: $draft.details, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section {
                    if draft.questions.isEmpty {
                        Text("質問はまだありません")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(draft.questions) { question in
                        NavigationLink {
                            QuestionEditorView(question: question) { updatedQuestion in
                                guard let index = draft.questions.firstIndex(where: { $0.id == updatedQuestion.id }) else { return }
                                draft.questions[index] = updatedQuestion
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: question.type.systemImage)
                                    .foregroundStyle(.blue)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(question.title.isEmpty ? "無題の質問" : question.title)
                                        .lineLimit(2)
                                    Text(question.type.title + (question.isRequired ? "・必須" : ""))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete { draft.questions.remove(atOffsets: $0) }
                    .onMove { draft.questions.move(fromOffsets: $0, toOffset: $1) }

                    Button {
                        showingQuestionTypes = true
                    } label: {
                        Label("質問を追加", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("質問（\(draft.questions.count)）")
                } footer: {
                    Text("質問を長押しして並べ替えられます。")
                }
            }
            .navigationTitle("アンケートを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        draft.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.update(draft)
                        dismiss()
                    }
                    .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingQuestionTypes) {
                QuestionTypePicker { type in
                    var options: [String] = []
                    if type.needsOptions {
                        options = ["選択肢 1", "選択肢 2"]
                    }
                    draft.questions.append(
                        SurveyQuestion(title: "", type: type, options: options)
                    )
                    showingQuestionTypes = false
                }
                .presentationDetents([.medium])
            }
        }
        .interactiveDismissDisabled()
    }
}

private struct QuestionTypePicker: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (QuestionType) -> Void

    var body: some View {
        NavigationStack {
            List(QuestionType.allCases) { type in
                Button {
                    onSelect(type)
                } label: {
                    Label(type.title, systemImage: type.systemImage)
                }
            }
            .navigationTitle("質問の種類")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }
}

private struct QuestionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var question: SurveyQuestion
    @FocusState private var isQuestionFocused: Bool
    let onSave: (SurveyQuestion) -> Void

    init(question: SurveyQuestion, onSave: @escaping (SurveyQuestion) -> Void) {
        _question = State(initialValue: question)
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section("質問") {
                TextField("質問を入力", text: $question.title)
                    .focused($isQuestionFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        isQuestionFocused = false
                        onSave(question)
                    }
                Picker("回答形式", selection: $question.type) {
                    ForEach(QuestionType.allCases) { type in
                        Label(type.title, systemImage: type.systemImage)
                            .tag(type)
                    }
                }
                Toggle("回答を必須にする", isOn: $question.isRequired)
            }

            if question.type.needsOptions {
                Section("選択肢") {
                    ForEach($question.options.indices, id: \.self) { index in
                        HStack {
                            TextField("選択肢 \(index + 1)", text: $question.options[index])
                            if question.options.count > 1 {
                                Button(role: .destructive) {
                                    question.options.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Button {
                        question.options.append("選択肢 \(question.options.count + 1)")
                    } label: {
                        Label("選択肢を追加", systemImage: "plus.circle")
                    }
                }
            }
        }
        .navigationTitle("質問を編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完了") {
                    isQuestionFocused = false
                    onSave(question)
                    dismiss()
                }
            }
        }
        .onChange(of: question.type) { _, newType in
            if newType.needsOptions && question.options.isEmpty {
                question.options = ["選択肢 1", "選択肢 2"]
            }
        }
        .onDisappear {
            onSave(question)
        }
    }
}
