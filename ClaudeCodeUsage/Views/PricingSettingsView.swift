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

            ratesTable

            ScrollView {
                VStack(spacing: 12) {
                    explanationDisclosure
                    howToUpdateDisclosure
                }
            }
        }
        .padding(24)
        .background(Theme.background)
        .frame(minWidth: 620, minHeight: 460)
    }

    /// One row per model tier, one column per rate — replaces 4 stacked panels (16 rows) with a
    /// single 5-row table so all rates are visible without scrolling.
    private var ratesTable: some View {
        Grid(alignment: .trailing, horizontalSpacing: 16, verticalSpacing: 12) {
            GridRow {
                Text("")
                columnHeader("Input")
                columnHeader("Output")
                columnHeader("Cache Write")
                columnHeader("Cache Read")
            }
            Divider().gridCellColumns(5).gridCellUnsizedAxes(.horizontal)
            tierRow(title: "Opus", pricing: $viewModel.pricingSettings.opus)
            tierRow(title: "Sonnet", pricing: $viewModel.pricingSettings.sonnet)
            tierRow(title: "Haiku", pricing: $viewModel.pricingSettings.haiku)
            tierRow(title: "Fable", pricing: $viewModel.pricingSettings.fable)
        }
        .panelStyle()
    }

    private func columnHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(Theme.textSecondary)
    }

    private func tierRow(title: String, pricing: Binding<ModelPricing>) -> some View {
        GridRow {
            Text(title.uppercased())
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.textSecondary)
                .gridColumnAlignment(.leading)
            rateCell(pricing.inputPerMTok)
            rateCell(pricing.outputPerMTok)
            rateCell(pricing.cacheWritePerMTok)
            rateCell(pricing.cacheReadPerMTok)
        }
    }

    private func rateCell(_ value: Binding<Double>) -> some View {
        HStack(spacing: 2) {
            Text("$")
                .foregroundStyle(Theme.textSecondary)
            TextField("", value: value, format: .number.precision(.fractionLength(0...2)))
                .multilineTextAlignment(.trailing)
                .frame(width: 60)
        }
        .font(.callout)
    }

    /// Explains where the token counts come from and how the 4 rates relate to each other, so
    /// editing "Input" without touching the other 3 columns looks like an obvious mistake rather
    /// than an oversight. Collapsed by default to keep the sheet short.
    private var explanationDisclosure: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 6) {
                Text("Token counts come straight from Claude Code's own transcripts (~/.claude/projects) — the real input/output/cache numbers the API returned, not an estimate.")
                Text("The dollar cost *is* an estimate: only \"Input\" is an independently published price per model. Output, Cache Write, and Cache Read are derived from it using ratios that hold across every current Anthropic model — Output ≈ 5× Input, Cache Write (5-min TTL) ≈ 1.25× Input, Cache Read ≈ 0.1× Input.")
            }
            .font(.caption2)
            .foregroundStyle(Theme.textSecondary)
            .padding(.top, 8)
        } label: {
            Text("How this is calculated")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelStyle()
    }

    /// Step-by-step guidance for keeping rates current, including how to reflect a temporary
    /// promotional rate without losing track of when it expires. Collapsed by default.
    private var howToUpdateDisclosure: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 6) {
                Text("1. Check the official rate card: platform.claude.com/docs/en/pricing (or ask Claude Code — its claude-api skill keeps a cached, dated price table).")
                Text("2. Update only \"Input\" for the changed tier. Recompute the other 3 fields: Output = Input × 5, Cache Write = Input × 1.25, Cache Read = Input × 0.1.")
                Text("3. Promotional / introductory rates (e.g. a limited-time discount with an end date): enter the promo Input rate here now, then manually revert to the standard rate once it expires — this screen has no concept of an expiry date and won't do it for you.")
                Text("4. \"Reset to Defaults\" restores the rates hardcoded in PricingSettings.swift (PricingSettings.default), not necessarily today's live pricing — if the official price moved, edit that file's default values too, or this reset button will restore the stale numbers next time someone clicks it.")
            }
            .font(.caption2)
            .foregroundStyle(Theme.textSecondary)
            .padding(.top, 8)
        } label: {
            Text("Keeping prices up to date")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelStyle()
    }
}
