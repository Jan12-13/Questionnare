import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

enum SurveyQRCodeError: LocalizedError {
    case invalidFormat
    case unsupportedVersion
    case tooLarge

    var errorDescription: String? {
        switch self {
        case .invalidFormat: "このアプリで作成されたQRコードではありません。"
        case .unsupportedVersion: "このQRコードは現在のアプリでは読み込めません。"
        case .tooLarge: "質問や選択肢が多すぎるため、1つのQRコードに収まりません。"
        }
    }
}

enum SurveyQRCodeCodec {
    private static let prefix = "questionnaire:v1:"

    static func encode(_ survey: Survey) throws -> String {
        let data = try JSONEncoder().encode(SurveySharePayload(survey: survey))
        let compressed = try (data as NSData).compressed(using: .lzfse) as Data
        let encoded = compressed.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return prefix + encoded
    }

    static func decode(_ value: String) throws -> SurveySharePayload {
        guard value.hasPrefix(prefix) else { throw SurveyQRCodeError.invalidFormat }
        var encoded = String(value.dropFirst(prefix.count))
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        encoded += String(repeating: "=", count: (4 - encoded.count % 4) % 4)
        guard let compressed = Data(base64Encoded: encoded),
              let data = try? (compressed as NSData).decompressed(using: .lzfse) as Data,
              let payload = try? JSONDecoder().decode(SurveySharePayload.self, from: data) else {
            throw SurveyQRCodeError.invalidFormat
        }
        guard payload.version == 1 else { throw SurveyQRCodeError.unsupportedVersion }
        return payload
    }
}

struct SurveyQRCodeView: View {
    let survey: Survey
    @State private var qrImage: UIImage?
    @State private var shareURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "iphone.and.arrow.forward")
                        .font(.largeTitle)
                        .foregroundStyle(.blue)
                    Text(survey.title)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text("別の端末で読み取ると、質問内容をその端末へコピーできます。回答データは共有されません。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if let qrImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 320)
                        .padding(20)
                        .background(.white, in: RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.08), radius: 16, y: 6)

                    if let shareURL {
                        ShareLink(item: shareURL) {
                            Label("QR画像を共有", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if let errorMessage {
                    ContentUnavailableView(
                        "QRコードを作成できません",
                        systemImage: "qrcode",
                        description: Text(errorMessage)
                    )
                } else {
                    ProgressView("QRコードを作成中…")
                }

                Label("QRコードはアンケート内容を直接保持するため、インターネットを使用しません", systemImage: "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("QRコードで共有")
        .navigationBarTitleDisplayMode(.inline)
        .task { createQRCode() }
    }

    private func createQRCode() {
        do {
            let value = try SurveyQRCodeCodec.encode(survey)
            let filter = CIFilter.qrCodeGenerator()
            filter.message = Data(value.utf8)
            filter.correctionLevel = "L"
            guard let outputImage = filter.outputImage else { throw SurveyQRCodeError.tooLarge }
            let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
            let context = CIContext()
            guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else {
                throw SurveyQRCodeError.tooLarge
            }
            let image = UIImage(cgImage: cgImage)
            qrImage = image

            if let data = image.pngData() {
                let safeTitle = survey.title.replacingOccurrences(of: "/", with: "-")
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeTitle)-QR.png")
                try data.write(to: url, options: .atomic)
                shareURL = url
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
