import SwiftUI

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var systemImage: String
}

struct BannerToastView: View {
    let message: ToastMessage

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: message.systemImage)
                .font(.body.weight(.semibold))
            Text(message.text)
                .font(.callout)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
    }
}
