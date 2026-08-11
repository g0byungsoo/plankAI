import SwiftUI
import PlankFood
import Auth

// MARK: - FirstPlateWelcomeView (v25 E5 — THE WALL, EARNED)
//
// The wall's opening beat when she arrives having just logged a real
// plate. Same wall, same prices, same controls, same exit-intent chain
// — the only change is that it stops asking cold.
//
// It follows ExpiredWelcomeView's shape on purpose (JKScreenChrome →
// hero → receipt rows → safe-area CTA): the wall already had a
// two-state precedent for "say something true first, then show plans",
// and reusing it means PaywallView is not touched at all. The 5.6
// rejection stands as law here — every control on this screen does
// something the user can see.
//
// What it may say is bounded by FirstPlateReadingEngine, which is
// table-tested for honesty: protein leads, no floor without a weight on
// file, no percentages, no verdict.

struct FirstPlateWelcomeView: View {

    let onSeePlans: () -> Void
    let onRestore: () -> Void

    @State private var auth = AuthService.shared

    var body: some View {
        JKScreenChrome {
            VStack(spacing: 0) {
                Spacer()

                // Her own plate, quietly. The receipt states the fact;
                // the photograph is why she believes it. One 68pt
                // thumbnail is the only image the wall carries, and it
                // is hers — not stock, not an icon.
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 68, height: 68)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Palette.hairlineCocoa, lineWidth: 0.5)
                        )
                        .padding(.bottom, Space.lg)
                        .accessibilityHidden(true)
                        .jkBeat1()
                }

                VStack(spacing: Space.md) {
                    ItalicAccentText(
                        "one plate in. already counted.",
                        italic: ["counted."],
                        baseFont: Typo.heroHeadline,
                        italicFont: Typo.heroHeadlineItalic,
                        alignment: .center
                    )
                    .lineSpacing(Typo.heroHeadlineLineGap)
                    .kerning(-0.4)
                    .padding(.horizontal, Space.lg)
                    .jkBeat1()

                    Text(subhead)
                        .font(Typo.teachSub)
                        .lineSpacing(Typo.teachSubLineSpacing)
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Space.lg + Space.sm)
                        .jkBeat2()
                }

                if let plate {
                    VStack(spacing: 0) {
                        JKReceiptRow(
                            lead: "you logged",
                            punch: plate.title,
                            showsRule: false
                        )
                        JKReceiptRow(
                            lead: "which is",
                            punch: reading.headline,
                            punchItalic: []
                        )
                        if let short = reading.meaningShort {
                            JKReceiptRow(
                                lead: "against your floor",
                                punch: short,
                                punchItalic: []
                            )
                        }
                    }
                    .padding(.horizontal, Space.lg + Space.sm)
                    .padding(.top, Space.xl)
                    .jkBeat2(extraDelay: 0.15)
                }

                Spacer()
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                JFContinueButton(
                    label: "see the whole program",
                    action: onSeePlans
                )
                Button(action: onRestore) {
                    Text("i already subscribed · restore")
                        .font(.custom("DMSans-Medium", size: 14))
                        .foregroundStyle(Palette.textSecondary)
                        .tappableArea()
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.md)
        }
    }

    // MARK: - Her record

    private var plate: FoodLogPersister.FoodLogEntry? {
        guard let uid = auth.currentUser?.id.uuidString else { return nil }
        return FoodLogPersister.allEntries(userId: uid)
            .max(by: { $0.loggedAt < $1.loggedAt })
    }

    private var photo: UIImage? {
        plate.flatMap { FoodPhotoStore.photo(entryId: $0.id) }
    }

    private var reading: FirstPlateReading {
        FirstPlateReadingEngine.compose(
            proteinG: plate.map(\.protein),
            kcal: plate.map(\.kcal),
            floorG: floorG
        )
    }

    private var floorG: Int? {
        let kg = UserDefaults.standard.double(forKey: "onboardingCurrentWeightKg")
        guard kg > 0 else { return nil }
        return TargetsService.proteinTargetG(
            weightKg: kg, careProtocol: CareProtocolStore.current
        )
    }

    /// The trust line, and it is literally true: the entry is persisted
    /// under her user id before this screen mounts. If she subscribes
    /// later, her first plate is already in the record she opens.
    private var subhead: String {
        "that plate is yours. it stays on the record whether you go on or not."
    }
}
