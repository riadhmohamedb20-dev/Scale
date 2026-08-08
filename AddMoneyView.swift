import SwiftUI

struct AddMoneyView: View {
    @ObservedObject var viewModel: TimeCircleViewModel
    @Environment(\.colorScheme) private var colorScheme

    private var cardBackground: Color {
        colorScheme == .light ? Color.black.opacity(0.08) : Color.white.opacity(0.14)
    }

    private var isFormValid: Bool {
        guard let amount = Double(viewModel.newMoneyAmountText) else { return false }
        return amount > 0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.top, 20)

                Text("Add Money")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(.primary)
                    .padding(.top, 24)

                Text("Top up your budget without changing its total.")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                sectionLabel("AMOUNT")
                    .padding(.top, 24)

                HStack(spacing: 4) {
                    TextField("0.00", text: $viewModel.newMoneyAmountText)
                        .font(.system(size: 17))
                        #if canImport(UIKit)
                        .keyboardType(.decimalPad)
                        #endif

                    Text("DA")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(cardBackground)
                )
                .padding(.top, 8)

                sectionLabel("DATE")
                    .padding(.top, 24)

                DatePicker("", selection: $viewModel.newMoneyDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(cardBackground)
                    )
                    .padding(.top, 8)

                if !viewModel.moneyTopUpsForSelectedDay.isEmpty {
                    sectionLabel("HISTORY")
                        .padding(.top, 24)

                    historyList
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color(activityPickerSystemBackground).ignoresSafeArea())
    }

    /// Each row (icon + padding) is exactly this tall, including the `listRowInsets` below —
    /// matches the AMOUNT/DATE fields' own height now that the row uses the same vertical
    /// padding and background as they do.
    private let historyRowHeight: CGFloat = 64

    /// A native `List` (rather than this screen's usual custom `VStack` rows) so swipe-to-delete
    /// can use the system's own `.swipeActions` — the same gesture and reveal behavior users get
    /// everywhere else on iOS, rather than a bespoke reimplementation.
    ///
    /// A `List` nested in this screen's outer `ScrollView` has no intrinsic height of its own —
    /// given only a `maxHeight`, SwiftUI can resolve it down to zero, so the rows exist in the
    /// hierarchy but never actually get drawn (the "HISTORY" label above it, being a plain `Text`,
    /// isn't affected and still shows normally — which is exactly the "section is visible but
    /// empty" symptom). Giving it an explicit height computed from the row count fixes that: the
    /// outer `ScrollView` handles all scrolling, so the List reports its full content height
    /// rather than trying to also scroll internally within an ambiguous space.
    private var historyList: some View {
        List {
            ForEach(viewModel.moneyTopUpsForSelectedDay) { topUp in
                historyRow(topUp)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            viewModel.deleteMoneyTopUp(id: topUp.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollDisabled(true)
        .scrollContentBackground(.hidden)
        .frame(height: CGFloat(viewModel.moneyTopUpsForSelectedDay.count) * historyRowHeight)
    }

    private func historyRow(_ topUp: MoneyTopUp) -> some View {
        HStack(spacing: 10) {
            Text("+\(MoneyFormat.currency(topUp.amount))")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(MoneyFormat.transactionDateTime(topUp.date))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(cardBackground)
        )
    }

    private var header: some View {
        HStack {
            Button {
                viewModel.closeAddMoneySheet()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                viewModel.saveMoneyForm()
            } label: {
                Text("Done")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(cardBackground))
            }
            .buttonStyle(.plain)
            .disabled(!isFormValid)
            .opacity(isFormValid ? 1 : 0.4)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .tracking(0.5)
    }
}
