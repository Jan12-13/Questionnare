import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: SurveyStore
    @AppStorage(AppSettings.administratorModeKey)
    private var isAdministratorMode = AppSettings.defaultAdministratorMode
    @State private var showingTemplates = false
    @State private var showingScanner = false
    @State private var showingSettings = false
    @State private var editingSurveyID: UUID?
    @State private var importedSurveyID: UUID?
    @State private var importError: String?
    @State private var surveyPendingDeletion: Survey?

    var body: some View {
        NavigationStack {
            Group {
                if store.surveys.isEmpty {
                    emptyState
                } else {
                    surveyList
                }
            }
            .navigationTitle("アンケート")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("設定", systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingScanner = true
                    } label: {
                        Label("QRを読み取る", systemImage: "qrcode.viewfinder")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingTemplates = true
                    } label: {
                        Label("新規作成", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingTemplates) {
                TemplatePickerView { template in
                    let survey = store.addSurvey(from: template)
                    showingTemplates = false
                    editingSurveyID = survey.id
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(item: $editingSurveyID) { id in
                if let survey = store.survey(withID: id) {
                    SurveyEditorView(survey: survey)
                }
            }
            .fullScreenCover(isPresented: $showingScanner) {
                QRScannerView { value in
                    do {
                        let payload = try SurveyQRCodeCodec.decode(value)
                        let survey = store.importSurvey(payload)
                        showingScanner = false
                        importedSurveyID = survey.id
                    } catch {
                        showingScanner = false
                        importError = error.localizedDescription
                    }
                }
            }
            .alert("アンケートを読み込みました", isPresented: Binding(
                get: { importedSurveyID != nil },
                set: { if !$0 { importedSurveyID = nil } }
            )) {
                Button("編集する") {
                    editingSurveyID = importedSurveyID
                    importedSurveyID = nil
                }
                Button("完了", role: .cancel) { importedSurveyID = nil }
            } message: {
                Text("この端末内に新しいアンケートとして保存しました。")
            }
            .alert("QRコードを読み込めませんでした", isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("OK", role: .cancel) { importError = nil }
            } message: {
                Text(importError ?? "対応していないQRコードです。")
            }
            .alert("このアンケートを削除しますか？", isPresented: surveyDeleteIsPresented) {
                Button("キャンセル", role: .cancel) {
                    surveyPendingDeletion = nil
                }
                Button("削除", role: .destructive) {
                    if isAdministratorMode, let surveyPendingDeletion {
                        store.delete(surveyPendingDeletion)
                    }
                    surveyPendingDeletion = nil
                }
            } message: {
                if let surveyPendingDeletion {
                    Text("「\(surveyPendingDeletion.title)」と\(surveyPendingDeletion.responses.count)件の回答を削除します。この操作は取り消せません。")
                }
            }
            .onChange(of: isAdministratorMode) {
                if !isAdministratorMode {
                    surveyPendingDeletion = nil
                }
            }
        }
    }

    private var surveyDeleteIsPresented: Binding<Bool> {
        Binding(
            get: { surveyPendingDeletion != nil },
            set: { isPresented in
                if !isPresented { surveyPendingDeletion = nil }
            }
        )
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("最初のアンケートを作成", systemImage: "list.clipboard")
        } description: {
            Text("テンプレートを選ぶか、空白から自由に作成できます。\nデータはこの端末内だけに保存されます。")
        } actions: {
            Button("アンケートを作成") {
                showingTemplates = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var surveyList: some View {
        List {
            if !isAdministratorMode {
                Section {
                    Label("管理者状態OFF：削除操作は無効です", systemImage: "lock.shield.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }

            Section("作成したアンケート") {
                ForEach(store.surveys) { survey in
                    let isPendingDeletion = surveyPendingDeletion?.id == survey.id
                    NavigationLink {
                        SurveyDetailView(surveyID: survey.id)
                    } label: {
                        SurveyRow(survey: survey)
                    }
                    .offset(x: isPendingDeletion ? -DeletionPendingBackground.width : 0)
                    .animation(.easeInOut(duration: 0.2), value: isPendingDeletion)
                    .listRowBackground(isPendingDeletion ? DeletionPendingBackground() : nil)
                    .swipeActions(edge: .leading) {
                        Button("編集", systemImage: "pencil") {
                            editingSurveyID = survey.id
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if isAdministratorMode {
                            Button("削除", systemImage: "trash", role: .destructive) {
                                surveyPendingDeletion = survey
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct SurveyRow: View {
    let survey: Survey

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "list.clipboard.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 5) {
                Text(survey.title)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 10) {
                    Label("\(survey.questions.count)問", systemImage: "questionmark.circle")
                    Label("\(survey.responses.count)件", systemImage: "person.2")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct SurveyDetailView: View {
    @EnvironmentObject private var store: SurveyStore
    let surveyID: UUID
    @State private var showingEditor = false
    @State private var showingResponse = false

    var body: some View {
        Group {
            if let survey = store.survey(withID: surveyID) {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(survey.title).font(.title2.bold())
                            if !survey.details.isEmpty {
                                Text(survey.details).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                    }

                    Section {
                        Button {
                            showingResponse = true
                        } label: {
                            Label("このアンケートに回答する", systemImage: "square.and.pencil")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(survey.questions.isEmpty)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }

                    Section("概要") {
                        LabeledContent("質問数", value: "\(survey.questions.count)")
                        LabeledContent("回答数", value: "\(survey.responses.count)")
                    }

                    Section("結果") {
                        NavigationLink {
                            SurveyResultsView(surveyID: surveyID)
                        } label: {
                            Label("集計結果を見る", systemImage: "chart.bar.xaxis")
                        }
                    }

                    Section("共有") {
                        NavigationLink {
                            SurveyQRCodeView(survey: survey)
                        } label: {
                            Label("QRコードで共有", systemImage: "qrcode")
                        }
                    }
                }
                .navigationTitle("詳細")
                .toolbar {
                    Button("編集") { showingEditor = true }
                }
                .sheet(isPresented: $showingEditor) {
                    SurveyEditorView(survey: survey)
                }
                .fullScreenCover(isPresented: $showingResponse) {
                    SurveyResponseView(surveyID: surveyID)
                }
            } else {
                ContentUnavailableView("アンケートがありません", systemImage: "exclamationmark.triangle")
            }
        }
    }
}

struct TemplatePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (SurveyTemplate) -> Void

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(SurveyTemplate.all) { template in
                        Button {
                            onSelect(template)
                        } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                Image(systemName: template.systemImage)
                                    .font(.title)
                                    .foregroundStyle(color(for: template.tintName))
                                Spacer(minLength: 8)
                                Text(template.title)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(template.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
                            .padding()
                            .background(.background, in: RoundedRectangle(cornerRadius: 16))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(.quaternary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("テンプレート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }

    private func color(for name: String) -> Color {
        switch name {
        case "orange": .orange
        case "purple": .purple
        case "green": .green
        case "pink": .pink
        default: .blue
        }
    }
}

extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}
