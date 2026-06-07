#if canImport(UIKit)
import SwiftUI

// MARK: - QuickAddView
//
// Per v5 D20 + §Calorie scan Screen 5: 2x3 grid of 6 cohort
// beverages. Each tap opens a 3-tap edit sheet (size / milk /
// sweetness), then logs via FoodCapture.quickAdd. 6 not 12 —
// less choice paralysis; cover 90% of cohort beverage volume.
//
// Tile order matches canonical_pantry seed priority per v3 §Audience-
// specific tools: matcha latte (oat) is #1 because it's the cohort's
// most-logged beverage.
//
// Each tile is keyed to a canonical_pantry slug. The Supabase
// canonical_pantry table is the source of truth; tiles surface the
// most-common variants. Sub-variants (size/milk/sweetness) refine
// to a per-row pantry entry (e.g. matcha_latte_oat_m_regular).

public struct QuickAddView: View {

    public let onLogged: (CapturedFood) -> Void
    public let onScanInstead: () -> Void
    public let onDismiss: () -> Void

    @State private var selectedTile: QuickAddTile?
    @State private var searchText: String = ""
    @FocusState private var searchFocused: Bool

    public init(
        onLogged: @escaping (CapturedFood) -> Void,
        onScanInstead: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.onLogged = onLogged
        self.onScanInstead = onScanInstead
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: FoodTheme.Space.lg) {
            topBar
            header
            searchField
            // v1.0.7 round 17: when search is non-empty, results
            // replace the tile grid. Empty search keeps the
            // existing 6-tile "what girls are having" grid.
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                cohortGridEyebrow
                tileGrid
                Spacer(minLength: 0)
            } else {
                searchResults
            }
            scanInsteadLink
        }
        .padding(FoodTheme.Space.screenPadding)
        .background(FoodTheme.bgPrimary.ignoresSafeArea())
        .sheet(item: $selectedTile) { tile in
            QuickAddEditSheet(
                tile: tile,
                onConfirm: { variant in
                    selectedTile = nil
                    // Dispatch the .quickAdd capture; the dispatcher
                    // routes through W2-T4 NutritionLookupService which
                    // hits canonical_pantry first (priority 1).
                    Task { await logQuickAdd(variant) }
                },
                onCancel: { selectedTile = nil }
            )
        }
    }

    // MARK: - Subviews

    @ViewBuilder private var topBar: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(FoodTheme.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("back")
            Spacer()
        }
    }

    @ViewBuilder private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            (Text("what'd you ")
                .font(.custom("Fraunces72pt-SemiBold", size: 24))
             + Text("have")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 24))
             + Text("? ♥")
                .font(.custom("Fraunces72pt-SemiBold", size: 24)))
                .foregroundStyle(FoodTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// v1.0.7 round 17 search input — per Cal AI + WL expert
    /// briefs the single highest-leverage fix for the food log
    /// surface. Searches across CohortCatalog (50 hand-curated
    /// cohort items) on every keystroke; results render inline
    /// below replacing the tile grid.
    @ViewBuilder private var searchField: some View {
        HStack(spacing: FoodTheme.Space.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(FoodTheme.textSecondary)
            TextField("search anything you ate ♥", text: $searchText)
                .focused($searchFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .submitLabel(.search)
                .font(.system(size: 15))
                .foregroundStyle(FoodTheme.textPrimary)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(FoodTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("clear search")
            }
        }
        .padding(.horizontal, FoodTheme.Space.md)
        .padding(.vertical, 11)
        .background(FoodTheme.bgElevated)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(FoodTheme.textPrimary.opacity(0.08), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// "what girls are *having*" eyebrow above the existing 6-tile
    /// grid — per the WL expert's voice-locked copy spec. Replaces
    /// the implicit "you have to pick from these 6" framing.
    @ViewBuilder private var cohortGridEyebrow: some View {
        (Text("what girls are ")
            .font(.custom("DMSans-Regular", size: 13))
         + Text("having")
            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13)))
            .foregroundStyle(FoodTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Search results list — renders when searchText is non-empty.
    /// Tap any row to log it directly (no edit sheet — these are
    /// already specific enough; size customization can come from
    /// v1.0.7.1 edit-sheet wiring).
    @ViewBuilder private var searchResults: some View {
        let results = CohortCatalog.search(searchText)
        if results.isEmpty {
            VStack(alignment: .leading, spacing: FoodTheme.Space.md) {
                Text("hmm, not finding that.")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 18))
                    .foregroundStyle(FoodTheme.textPrimary)
                Text("wanna scan it?")
                    .font(.custom("DMSans-Regular", size: 14))
                    .foregroundStyle(FoodTheme.textSecondary)
                Button(action: onScanInstead) {
                    HStack(spacing: 6) {
                        Image(systemName: "camera")
                            .font(.system(size: 13, weight: .semibold))
                        Text("snap it instead")
                            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(FoodTheme.bgPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(FoodTheme.textPrimary))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, FoodTheme.Space.sm)
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(results) { item in
                        searchResultRow(item)
                        if item.id != results.last?.id {
                            Rectangle()
                                .fill(FoodTheme.textPrimary.opacity(0.08))
                                .frame(height: 0.5)
                                .padding(.horizontal, FoodTheme.Space.sm)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private func searchResultRow(_ item: CatalogItem) -> some View {
        Button {
            Task { await logCatalogItem(item) }
        } label: {
            HStack(spacing: FoodTheme.Space.md) {
                Text(item.emoji)
                    .font(.system(size: 24))
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(FoodTheme.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text(item.kcalRangeDisplay)
                        .font(.system(size: 12))
                        .foregroundStyle(FoodTheme.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(FoodTheme.textPrimary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, FoodTheme.Space.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.name), \(item.kcalRangeDisplay)")
    }

    @ViewBuilder private var tileGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: FoodTheme.Space.sm),
            GridItem(.flexible(), spacing: FoodTheme.Space.sm),
            GridItem(.flexible(), spacing: FoodTheme.Space.sm),
        ]
        LazyVGrid(columns: columns, spacing: FoodTheme.Space.sm) {
            ForEach(QuickAddTile.allTiles) { tile in
                tileButton(tile)
            }
        }
    }

    @ViewBuilder
    private func tileButton(_ tile: QuickAddTile) -> some View {
        Button {
            selectedTile = tile
        } label: {
            VStack(spacing: 8) {
                Text(tile.emoji)
                    .font(.system(size: 32))
                Text(tile.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FoodTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 96)
            .padding(FoodTheme.Space.sm)
            .background(FoodTheme.bgElevated)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(FoodTheme.textPrimary.opacity(0.08), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tile.name)
    }

    @ViewBuilder private var scanInsteadLink: some View {
        // v1.0.7 round 17: voice-locked copy per WL expert brief
        // ("snap it instead" reads as cohort-native; "not here?
        // scan instead" implied the grid was the answer, but
        // search now is).
        Button(action: onScanInstead) {
            Text("snap it instead →")
                .font(.system(size: 14))
                .foregroundStyle(FoodTheme.textSecondary)
        }
        .padding(.bottom, FoodTheme.Space.md)
    }

    // MARK: - Actions

    /// Log a CohortCatalog item directly. Builds a CapturedFood
    /// with .quickAdd source + .single plateType + an inline
    /// CapturedItem carrying the catalog item's name + kcal.
    /// Bypasses the dispatcher's pantry resolution path since the
    /// catalog item already has its kcal value.
    private func logCatalogItem(_ item: CatalogItem) async {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let capturedItem = CapturedItem(
            id: item.id,
            name: item.name,
            portionGrams: 0,
            portionGramsLow: 0,
            portionGramsHigh: 0,
            usdaSearchTerms: [],
            preparation: nil,
            cuisineHint: nil,
            confidence: nil,
            notes: nil,
            kcal: Double(item.kcal),
            proteinG: nil,
            carbsG: nil,
            fatG: nil,
            fiberG: nil,
            nutritionSource: nil
        )
        let food = CapturedFood(
            items: [capturedItem],
            plateType: .single,
            source: .quickAdd,
            confidence: nil,
            needsSecondPhoto: false,
            secondPhotoHint: nil,
            kcalLow: Double(item.kcalLow),
            kcalHigh: Double(item.kcalHigh)
        )
        onLogged(food)
    }

    private func logQuickAdd(_ variant: QuickAddVariant) async {
        // Build a CapturedFood directly from the variant's known
        // density (canonical_pantry entry is already resolved — no
        // LLM call needed for quick-add). Dispatcher route below
        // handles the persistence + telemetry.
        let pantryID = PantryItemID(variant.pantryRowID)
        let dispatcher = FoodCaptureDispatcher()
        do {
            let food = try await dispatcher.dispatch(.quickAdd(pantryID))
            onLogged(food)
        } catch {
            // For W3-T3 we just dismiss on error. W3-T4 / W4-T1 will
            // surface a transient error banner.
            #if DEBUG
            print("[QuickAdd] dispatch failed: \(error)")
            #endif
        }
    }
}

// MARK: - QuickAddTile

public struct QuickAddTile: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let emoji: String
    public let pantrySlugBase: String

    /// Default size / milk / sweetness for this tile. Used as the
    /// pre-selected sheet state.
    public let defaultSize: SizeOption
    public let defaultMilk: MilkOption?
    public let defaultSweetness: SweetnessOption?

    /// Whether this tile's edit sheet shows the milk row at all.
    /// (Iced coffee shows milk; protein shake doesn't.)
    public let hasMilk: Bool
    public let hasSweetness: Bool

    public static let allTiles: [QuickAddTile] = [
        QuickAddTile(
            id: "matcha_latte",
            name: "matcha latte",
            emoji: "☕",
            pantrySlugBase: "matcha_latte",
            defaultSize: .medium,
            defaultMilk: .oat,
            defaultSweetness: .regular,
            hasMilk: true,
            hasSweetness: true
        ),
        QuickAddTile(
            id: "oat_latte",
            name: "oat milk latte",
            emoji: "🥛",
            pantrySlugBase: "oat_milk_latte",
            defaultSize: .medium,
            defaultMilk: .oat,
            defaultSweetness: .none,
            hasMilk: true,
            hasSweetness: false
        ),
        QuickAddTile(
            id: "iced_coffee",
            name: "iced coffee",
            emoji: "🥤",
            pantrySlugBase: "iced_coffee",
            defaultSize: .medium,
            defaultMilk: .whole,
            defaultSweetness: .none,
            hasMilk: true,
            hasSweetness: true
        ),
        QuickAddTile(
            id: "boba",
            name: "brown sugar boba",
            emoji: "🧋",
            pantrySlugBase: "brown_sugar_boba",
            defaultSize: .medium,
            defaultMilk: nil,
            defaultSweetness: .regular,
            hasMilk: false,
            hasSweetness: true
        ),
        QuickAddTile(
            id: "protein_shake",
            name: "protein shake",
            emoji: "💪",
            pantrySlugBase: "protein_shake",
            defaultSize: .medium,
            defaultMilk: nil,
            defaultSweetness: nil,
            hasMilk: false,
            hasSweetness: false
        ),
        QuickAddTile(
            id: "smoothie",
            name: "smoothie",
            emoji: "🥤",
            pantrySlugBase: "smoothie",
            defaultSize: .medium,
            defaultMilk: nil,
            defaultSweetness: nil,
            hasMilk: false,
            hasSweetness: false
        ),
    ]
}

// MARK: - Variant options

public enum SizeOption: String, Sendable, CaseIterable, Identifiable {
    case small, medium, large
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .small: return "S"
        case .medium: return "M"
        case .large: return "L"
        }
    }
}

public enum MilkOption: String, Sendable, CaseIterable, Identifiable {
    case whole, oat, almond, none
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .whole: return "whole"
        case .oat: return "oat"
        case .almond: return "almond"
        case .none: return "no milk"
        }
    }
}

public enum SweetnessOption: String, Sendable, CaseIterable, Identifiable {
    case regular, half, none
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .regular: return "regular"
        case .half: return "half"
        case .none: return "unsweet"
        }
    }
}

// MARK: - QuickAddVariant

public struct QuickAddVariant: Sendable {
    public let tile: QuickAddTile
    public let size: SizeOption
    public let milk: MilkOption?
    public let sweetness: SweetnessOption?

    /// Pantry row id resolved from the variant. Pattern:
    /// `<base>_<size>` plus optional `_<milk>` and `_<sweetness>`
    /// suffixes. The canonical_pantry seed must include all matching
    /// rows or NutritionLookup falls through to USDA.
    public var pantryRowID: String {
        var parts = [tile.pantrySlugBase, size.rawValue]
        if let milk { parts.append(milk.rawValue) }
        if let sweetness { parts.append(sweetness.rawValue) }
        return parts.joined(separator: "_")
    }
}

// MARK: - QuickAddEditSheet

/// 3-tap edit sheet shown on tile tap. Size + (optional) milk +
/// (optional) sweetness. Each row is a horizontal scroll of chips.
/// Confirm logs the variant.
private struct QuickAddEditSheet: View {

    let tile: QuickAddTile
    let onConfirm: (QuickAddVariant) -> Void
    let onCancel: () -> Void

    @State private var size: SizeOption
    @State private var milk: MilkOption?
    @State private var sweetness: SweetnessOption?

    init(
        tile: QuickAddTile,
        onConfirm: @escaping (QuickAddVariant) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.tile = tile
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        self._size = State(initialValue: tile.defaultSize)
        self._milk = State(initialValue: tile.defaultMilk)
        self._sweetness = State(initialValue: tile.defaultSweetness)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FoodTheme.Space.lg) {
            HStack(spacing: FoodTheme.Space.sm) {
                Text(tile.emoji)
                    .font(.system(size: 36))
                Text(tile.name)
                    .font(.custom("Fraunces72pt-SemiBold", size: 22))
                    .foregroundStyle(FoodTheme.textPrimary)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(FoodTheme.textSecondary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("cancel")
            }

            chipRow(label: "size", options: SizeOption.allCases, selection: $size)

            if tile.hasMilk {
                chipRow(
                    label: "milk",
                    options: MilkOption.allCases,
                    selection: Binding(
                        get: { milk ?? .whole },
                        set: { milk = $0 }
                    )
                )
            }

            if tile.hasSweetness {
                chipRow(
                    label: "sweetness",
                    options: SweetnessOption.allCases,
                    selection: Binding(
                        get: { sweetness ?? .regular },
                        set: { sweetness = $0 }
                    )
                )
            }

            Spacer(minLength: FoodTheme.Space.md)

            Button {
                let variant = QuickAddVariant(
                    tile: tile,
                    size: size,
                    milk: tile.hasMilk ? milk : nil,
                    sweetness: tile.hasSweetness ? sweetness : nil
                )
                onConfirm(variant)
            } label: {
                Text("log it")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FoodTheme.bgPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(FoodTheme.textPrimary))
            }
        }
        .padding(FoodTheme.Space.lg)
        .background(FoodTheme.bgPrimary)
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private func chipRow<T: Identifiable & Hashable>(
        label: String,
        options: [T],
        selection: Binding<T>
    ) -> some View where T.ID == String {
        VStack(alignment: .leading, spacing: FoodTheme.Space.sm) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(FoodTheme.textSecondary)
                .tracking(1.5)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FoodTheme.Space.sm) {
                    ForEach(options) { option in
                        chipButton(option, selection: selection)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func chipButton<T: Identifiable & Hashable>(
        _ option: T,
        selection: Binding<T>
    ) -> some View where T.ID == String {
        let isSelected = selection.wrappedValue == option
        let label = labelFor(option)

        Button {
            selection.wrappedValue = option
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isSelected ? FoodTheme.bgPrimary : FoodTheme.textPrimary)
                .padding(.horizontal, FoodTheme.Space.md)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(
                        isSelected ? FoodTheme.textPrimary : FoodTheme.bgElevated
                    )
                )
        }
        .buttonStyle(.plain)
    }

    private func labelFor<T: Identifiable & Hashable>(_ option: T) -> String where T.ID == String {
        if let size = option as? SizeOption { return size.label }
        if let milk = option as? MilkOption { return milk.label }
        if let sweet = option as? SweetnessOption { return sweet.label }
        return String(describing: option)
    }
}

// MARK: - Preview

#Preview("QuickAddView") {
    QuickAddView(
        onLogged: { _ in print("logged") },
        onScanInstead: { print("scan") },
        onDismiss: { print("dismiss") }
    )
}

#endif  // canImport(UIKit)
