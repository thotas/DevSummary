import SwiftUI

struct EmptyStateView: View {
    let message: String
    let isError: Bool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: isError ? "exclamationmark.circle" : "tray")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)

            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(isError ? .red : .secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
