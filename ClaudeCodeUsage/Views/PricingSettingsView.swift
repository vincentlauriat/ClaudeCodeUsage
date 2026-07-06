import SwiftUI

/// Editable per-model-family pricing sheet — changes apply immediately (and persist) to every
/// Est. Cost figure in the app.
struct PricingSettingsView: View {
    @ObservedObject var viewModel: UsageViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Pricing")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button("Reset to Defaults") {
                    viewModel.resetPricingToDefaults()
                }
                Button("Done", action: dismiss.callAsFunction)
            }

            Text("USD per million tokens. Applies immediately to Est. Cost everywhere in the app.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)

            ScrollView {
                VStack(spacing: 12) {
                    tierEditor(title: "Opus", pricing: $viewModel.pricingSettings.opus)
                    tierEditor(title: "Sonnet", pricing: $viewModel.pricingSettings.sonnet)
                    tierEditor(title: "Haiku", pricing: $viewModel.pricingSettings.haiku)
                    tierEditor(title: "Fable", pricing: $viewModel.pricingSettings.fable)
                }
            }
        }
        .padding(24)
        .background(Theme.background)
        .frame(minWidth: 480, minHeight: 560)
    }

    private func tierEditor(title: String, pricing: Binding<ModelPricing>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.textSecondary)
            rateField("Input", value: pricing.inputPerMTok)
            rateField("Output", value: pricing.outputPerMTok)
            rateField("Cache Write", value: pricing.cacheWritePerMTok)
            rateField("Cache Read", value: pricing.cacheReadPerMTok)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelStyle()
    }

    private func rateField(_ label: String, value: Binding<Double>) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text("$")
                .foregroundStyle(Theme.textSecondary)
            TextField("", value: value, format: .number.precision(.fractionLength(0...2)))
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Text("/ M tok")
                .foregroundStyle(Theme.textSecondary)
        }
        .font(.callout)
    }
}
