import SwiftUI

struct DeletionPendingBackground: View {
    static let width: CGFloat = 104

    var body: some View {
        HStack {
            Spacer()
            Label("確認中", systemImage: "trash.fill")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: Self.width)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.red)
    }
}
