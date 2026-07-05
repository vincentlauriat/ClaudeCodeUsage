import SwiftUI

struct StatCardView: View {
    let title: String
    let value: String
    let subtitle: String
    var valueColor: Color = Theme.textPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(valueColor)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.panel)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.panelBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
