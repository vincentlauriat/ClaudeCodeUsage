import SwiftUI

struct FilterBarView: View {
    @ObservedObject var viewModel: UsageViewModel

    var body: some View {
        HStack(spacing: 24) {
            HStack(spacing: 10) {
                Text("MODELS")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.textSecondary)

                Picker("", selection: $viewModel.selectedModel) {
                    Text("All models").tag(String?.none)
                    ForEach(viewModel.availableModels, id: \.self) { model in
                        Text(model).tag(String?.some(model))
                    }
                }
                .pickerStyle(.menu)
                .frame(minWidth: 160)
                .labelsHidden()
            }

            Divider().frame(height: 20)

            HStack(spacing: 10) {
                Text("PROJECT")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.textSecondary)

                Picker("", selection: $viewModel.selectedProject) {
                    Text("All projects").tag(String?.none)
                    ForEach(viewModel.availableProjects, id: \.self) { project in
                        Text(Formatters.shortenPath(project)).tag(String?.some(project))
                    }
                }
                .pickerStyle(.menu)
                .frame(minWidth: 200)
                .labelsHidden()
            }

            Divider().frame(height: 20)

            HStack(spacing: 10) {
                Text("RANGE")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.textSecondary)

                HStack(spacing: 4) {
                    ForEach(DateRangeFilter.allCases) { range in
                        rangeButton(range)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    private func rangeButton(_ range: DateRangeFilter) -> some View {
        let isSelected = viewModel.selectedRange == range
        return Button {
            viewModel.selectedRange = range
        } label: {
            Text(range.rawValue)
                .font(.caption)
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundStyle(isSelected ? Theme.background : Theme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? Theme.textPrimary : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}
