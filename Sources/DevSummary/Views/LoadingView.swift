import SwiftUI

struct LoadingView: View {
    let scanning: Bool

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)

            Text(scanning ? "Scanning for repositories..." : "Analyzing your commits...")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
