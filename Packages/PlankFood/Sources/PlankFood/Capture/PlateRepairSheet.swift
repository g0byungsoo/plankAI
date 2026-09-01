#if canImport(UIKit)
import SwiftUI

// MARK: - PlateRepairSheet (p61)
//
// **THE FILED PLATE IS CORRECTABLE.** The same editor she used at scan
// time — `PlateEditSession` + the ingredient editor + the share ladder
// — reopened on a plate already in the record. One grammar, two
// moments: correcting a plate the day after feels exactly like
// correcting it the second before "add it".
//
// The repair lands through `FoodLogPersister.updateEntry`: same id
// (the photograph and the cloud row are keyed by it), same day, same
// door, her spoken corrections intact, the numbers re-derived by the
// one arithmetic `persist` uses. `changeNotifier` then repaints every
// listening surface, so the fix is visible the moment it lands.

public struct PlateRepairSheet: View {

    private let entryId: String
    private let dayWord: String
    private let onDone: (_ saved: Bool) -> Void

    @State private var session: PlateEditSession
    @State private var editingItemID: String?
    private let shareLadder: [PlateShare.Rung]

    public init(
        entry: FoodLogPersister.FoodLogEntry,
        dayWord: String,
        onDone: @escaping (_ saved: Bool) -> Void
    ) {
        self.entryId = entry.id
        self.dayWord = dayWord
        self.onDone = onDone
        let food = FoodLogPersister.repairFood(from: entry)
        _session = State(initialValue: PlateEditSession(food: food))
        self.shareLadder = PlateShare.ladder(for: food)
    }

    private var isDirty: Bool { !session.derivedEditNotes.isEmpty }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    itemRows
                        .padding(.top, 18)
                    if shareLadder.count > 1 {
                        fractionBlock
                            .padding(.top, 22)
                    }
                    Text("your fix replaces the estimate everywhere — today's totals, the book, the week.")
                        .font(.custom("DMSans-Regular", size: 12.5, relativeTo: .caption))
                        .foregroundStyle(FoodTheme.textSecondary.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 22)
                }
                .padding(.horizontal, FoodTheme.Space.screenPadding)
                .padding(.top, 24)
                .padding(.bottom, 12)
            }
            actionBar
        }
        .background(FoodTheme.bgPrimary.ignoresSafeArea())
        .sheet(item: editingBinding) { box in
            IngredientEditorSheet(
                original: box.item,
                scanBaseline: session.baselineItem(box.item.id),
                onSave: { updated in
                    withAnimation(.easeOut(duration: 0.22)) {
                        session.replace(updated)
                    }
                    editingItemID = nil
                },
                onRemove: {
                    withAnimation(.easeOut(duration: 0.22)) {
                        session.remove(box.item.id)
                    }
                    editingItemID = nil
                },
                onCancel: { editingItemID = nil }
            )
            .presentationDetents([.fraction(0.72), .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Header

    @ViewBuilder private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            (Text("fix ")
                .font(.custom("JeniHeroSerif-Regular", size: 24, relativeTo: .title2))
             + Text("this plate")
                .font(.custom("JeniHeroSerif-Italic", size: 24, relativeTo: .title2)))
                .foregroundStyle(FoodTheme.textPrimary)
            Text("\(dayWord) \u{00B7} tap anything that looks off")
                .font(.custom("DMSans-Regular", size: 13, relativeTo: .footnote))
                .foregroundStyle(FoodTheme.textSecondary)
        }
    }

    // MARK: - Items

    @ViewBuilder private var itemRows: some View {
        VStack(spacing: 0) {
            ForEach(session.effectiveItems) { item in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    editingItemID = item.id
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.custom("DMSans-Medium", size: 15, relativeTo: .body))
                                .foregroundStyle(FoodTheme.textPrimary)
                                .multilineTextAlignment(.leading)
                            if item.portionGrams > 0 {
                                Text("\(Int(item.portionGrams.rounded())) g")
                                    .font(.custom("DMSans-Regular", size: 12.5, relativeTo: .caption))
                                    .foregroundStyle(FoodTheme.textSecondary)
                                    .monospacedDigit()
                            }
                        }
                        Spacer(minLength: 8)
                        if let kcal = item.kcal {
                            Text("\(Int(kcal.rounded())) cal")
                                .font(.custom("DMSans-Medium", size: 14, relativeTo: .callout))
                                .foregroundStyle(FoodTheme.textPrimary.opacity(0.75))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                        } else {
                            Text("not counted")
                                .font(.custom("DMSans-Regular", size: 13, relativeTo: .footnote))
                                .foregroundStyle(FoodTheme.textSecondary.opacity(0.85))
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(FoodTheme.textSecondary.opacity(0.55))
                    }
                    .padding(.vertical, 13)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(item.name), tap to fix its numbers")
                if item.id != session.effectiveItems.last?.id {
                    Rectangle()
                        .fill(FoodTheme.textPrimary.opacity(0.08))
                        .frame(height: 0.5)
                }
            }
        }
        .animation(.easeOut(duration: 0.22), value: session.effectiveItems.map(\.id))
    }

    // MARK: - Fraction

    @ViewBuilder private var fractionBlock: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("how much of it you ate")
                .font(.custom("DMSans-Medium", size: 12, relativeTo: .caption))
                .foregroundStyle(FoodTheme.textSecondary)
                .textCase(.lowercase)
            FoodChipFlow(spacing: 7) {
                ForEach(shareLadder) { f in
                    fractionChip(f)
                }
            }
        }
    }

    @ViewBuilder
    private func fractionChip(_ f: PlateShare.Rung) -> some View {
        let isOn = abs(session.fraction - f.value) < 0.01
        Button {
            guard !isOn else { return }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            withAnimation(.easeOut(duration: 0.22)) {
                session.setFraction(f.value)
            }
        } label: {
            (Text(f.label)
                .font(.custom("DMSans-Medium", size: 12))
            + Text(f.punch)
                .font(.custom("JeniHeroSerif-Italic", size: 13)))
                .foregroundStyle(isOn ? FoodTheme.bgPrimary : FoodTheme.textPrimary.opacity(0.75))
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 11)
                .frame(height: 33)
                .background(
                    Capsule().fill(isOn ? FoodTheme.textPrimary : Color.white.opacity(0.55))
                )
                .overlay(
                    Capsule().stroke(
                        FoodTheme.textPrimary.opacity(isOn ? 0 : 0.12),
                        lineWidth: 0.75
                    )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Action bar

    @ViewBuilder private var actionBar: some View {
        VStack(spacing: 10) {
            Button {
                let saved = FoodLogPersister.updateEntry(
                    id: entryId,
                    with: session.rebuiltFood(),
                    editNotes: session.derivedEditNotes
                )
                if saved {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
                onDone(saved)
            } label: {
                Text("keep the fix")
                    .font(.custom("DMSans-SemiBold", size: 16, relativeTo: .body))
                    .foregroundStyle(FoodTheme.bgPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        Capsule().fill(
                            FoodTheme.textPrimary.opacity(isDirty ? 1 : 0.35)
                        )
                    )
            }
            .buttonStyle(.plain)
            .disabled(!isDirty)
            .animation(.easeOut(duration: 0.18), value: isDirty)
            Button {
                onDone(false)
            } label: {
                Text("leave it as it was")
                    .font(.custom("DMSans-Regular", size: 14, relativeTo: .callout))
                    .foregroundStyle(FoodTheme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, FoodTheme.Space.screenPadding)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(FoodTheme.bgPrimary)
    }

    // MARK: - Editor plumbing (the reading's own pattern)

    private struct EditingBox: Identifiable {
        let item: CapturedItem
        var id: String { item.id }
    }

    private var editingBinding: Binding<EditingBox?> {
        Binding(
            get: {
                guard let id = editingItemID,
                      let item = session.item(id) else { return nil }
                return EditingBox(item: item)
            },
            set: { editingItemID = $0?.id }
        )
    }
}
#endif
