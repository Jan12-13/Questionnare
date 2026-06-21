import Foundation

enum QuestionType: String, Codable, CaseIterable, Identifiable {
    case shortText
    case longText
    case singleChoice
    case multipleChoice
    case rating
    case yesNo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shortText: "短文"
        case .longText: "長文"
        case .singleChoice: "単一選択"
        case .multipleChoice: "複数選択"
        case .rating: "5段階評価"
        case .yesNo: "はい／いいえ"
        }
    }

    var systemImage: String {
        switch self {
        case .shortText: "text.cursor"
        case .longText: "text.alignleft"
        case .singleChoice: "circle.inset.filled"
        case .multipleChoice: "checkmark.square"
        case .rating: "star"
        case .yesNo: "hand.thumbsup"
        }
    }

    var needsOptions: Bool {
        self == .singleChoice || self == .multipleChoice
    }
}

struct SurveyQuestion: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var type: QuestionType
    var isRequired = false
    var options: [String] = []
}

struct QuestionAnswer: Identifiable, Codable, Hashable {
    var id: UUID { questionID }
    let questionID: UUID
    var values: [String]
}

struct SurveyResponse: Identifiable, Codable, Hashable {
    var id = UUID()
    var submittedAt = Date()
    var answers: [QuestionAnswer]
}

struct Survey: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var details: String
    var createdAt = Date()
    var updatedAt = Date()
    var questions: [SurveyQuestion]
    var responses: [SurveyResponse] = []
}

struct SurveySharePayload: Codable {
    let version: Int
    let title: String
    let details: String
    let questions: [SurveyQuestion]

    init(survey: Survey) {
        version = 1
        title = survey.title
        details = survey.details
        questions = survey.questions
    }

    func makeSurvey() -> Survey {
        Survey(title: title, details: details, questions: questions)
    }
}

struct SurveyTemplate: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let tintName: String
    let questions: [SurveyQuestion]

    static let all: [SurveyTemplate] = [
        SurveyTemplate(
            id: "blank",
            title: "空白から作成",
            subtitle: "自由に質問を追加",
            systemImage: "doc.badge.plus",
            tintName: "blue",
            questions: []
        ),
        SurveyTemplate(
            id: "satisfaction",
            title: "満足度調査",
            subtitle: "商品やサービスの評価",
            systemImage: "star.bubble",
            tintName: "orange",
            questions: [
                SurveyQuestion(title: "総合的な満足度を教えてください", type: .rating, isRequired: true),
                SurveyQuestion(title: "特に良かった点は何ですか？", type: .longText),
                SurveyQuestion(title: "また利用したいと思いますか？", type: .yesNo, isRequired: true)
            ]
        ),
        SurveyTemplate(
            id: "event",
            title: "イベント感想",
            subtitle: "参加後のフィードバック",
            systemImage: "person.3",
            tintName: "purple",
            questions: [
                SurveyQuestion(title: "イベントをどこで知りましたか？", type: .singleChoice, options: ["Webサイト", "SNS", "知人の紹介", "その他"]),
                SurveyQuestion(title: "内容の満足度", type: .rating, isRequired: true),
                SurveyQuestion(title: "今後扱ってほしいテーマ", type: .longText)
            ]
        ),
        SurveyTemplate(
            id: "attendance",
            title: "出欠確認",
            subtitle: "会議や懇親会の参加確認",
            systemImage: "calendar.badge.checkmark",
            tintName: "green",
            questions: [
                SurveyQuestion(title: "お名前", type: .shortText, isRequired: true),
                SurveyQuestion(title: "参加しますか？", type: .yesNo, isRequired: true),
                SurveyQuestion(title: "連絡事項", type: .longText)
            ]
        ),
        SurveyTemplate(
            id: "request",
            title: "社内リクエスト",
            subtitle: "意見や要望の収集",
            systemImage: "lightbulb",
            tintName: "pink",
            questions: [
                SurveyQuestion(title: "対象のカテゴリ", type: .singleChoice, isRequired: true, options: ["設備", "制度", "業務改善", "その他"]),
                SurveyQuestion(title: "ご意見・ご要望", type: .longText, isRequired: true),
                SurveyQuestion(title: "優先度", type: .rating)
            ]
        )
    ]
}
