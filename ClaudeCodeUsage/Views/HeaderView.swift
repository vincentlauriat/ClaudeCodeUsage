import SwiftUI

struct HeaderView: View {
    @ObservedObject var viewModel: UsageViewModel
    @State private var showingPricingSettings = false

    var body: some View {
        ZStack {
            HStack(spacing: 10) {
                Image(systemName: "asterisk.circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Theme.textPrimary)
                Text("Claude Code Usage")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button {
                    showingPricingSettings = true
                } label: {
                    Label("Pricing", systemImage: "gearshape")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.bordered)
                Button(action: viewModel.rescan) {
                    Label("Rescan", systemImage: "arrow.clockwise")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isScanning)
            }

            VStack(spacing: 2) {
                if let lastUpdated = viewModel.lastUpdated {
                    Text("Updated: \(Formatters.updatedAt(lastUpdated))")
                        .font(.callout)
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    Text("Scanning…")
                        .font(.callout)
                        .foregroundStyle(Theme.textSecondary)
                }
                Text("Auto-refresh in \(viewModel.secondsUntilRefresh)s")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .sheet(isPresented: $showingPricingSettings) {
            PricingSettingsView(viewModel: viewModel)
        }
    }
}
