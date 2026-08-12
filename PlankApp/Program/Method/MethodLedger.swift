import Foundation

// MARK: - MethodLedger
//
// What Jeni told her, when, why, and what happened next.
//
// Three jobs, in order of importance:
//
//   1. COOLDOWNS. Without a memory the engine would say the same true
//      thing every day until it became wallpaper.
//   2. THE RECORD SHE CAN READ. A note she was shown is a thing she was
//      told; the browse surface is this list, not a library. That is the
//      answer to "preserve a way to revisit useful material" — her own,
//      rather than a shelf of things she has never seen.
//   3. FALSIFICATION. Each entry stores the pre-registered proximal
//      outcome and whether it was later observed IN HER RECORD. That is
//      the only way to answer "did this help" instead of "was this
//      opened".
//
// Storage is a UserDefaults-backed JSON array. No migration, no cloud
// row: it is small, device-local, and cheap to reason about. It is
// deliberately NOT synced this pass — a note history is a record of what
// a system said to a person, and moving it to a server is a privacy
// decision, not a convenience one.
//
// PRIVACY. Entries carry ids, a trigger name, a date and a boolean.
// They never carry the rendered sentence, a food name, a weight, or a
// symptom. "Do not log sensitive raw health content merely for
// analytics" applies to local records too, because local records get
// backed up.

@MainActor
enum MethodLedger {

    private static let key = "method.ledger.v1"
    private static let maxEntries = 200

    struct Entry: Codable, Equatable {
        let noteId: String
        let trigger: String
        /// The note's own version, so a later rewrite never rewrites
        /// what she was actually told.
        let noteVersion: Int
        let catalogVersion: Int
        let shownAt: Date
        /// True once she tapped into the note rather than dismissing it.
        var opened: Bool = false
        /// True once the note's action door was taken.
        var actionTaken: Bool = false
        /// The pre-registered proximal outcome for this note.
        let followUp: String
        /// nil until the window closes, then true/false. Set by
        /// `settleFollowUps` against her own record.
        var followUpMet: Bool? = nil
        /// `careTeam` content is marked so a patient — and any later
        /// analysis — can separate what a clinician told her from what
        /// Jeni did.
        let fromCareTeam: Bool
    }

    // MARK: - Read

    static func entries() -> [Entry] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let rows = try? JSONDecoder().decode([Entry].self, from: data)
        else { return [] }
        return rows.sorted { $0.shownAt > $1.shownAt }
    }

    /// Days since each note was last shown — the cooldown input the
    /// engine reads. A note shown today is 0.
    static func shownDaysAgoById() -> [String: Int] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        var out: [String: Int] = [:]
        for entry in entries() {
            let day = cal.startOfDay(for: entry.shownAt)
            let ago = cal.dateComponents([.day], from: day, to: today).day ?? 0
            // entries() is newest-first, so the first write wins and is
            // the most recent showing.
            if out[entry.noteId] == nil { out[entry.noteId] = max(0, ago) }
        }
        return out
    }

    // MARK: - Write

    static func markShown(_ resolved: ResolvedMethodNote) {
        var rows = entries()
        // Idempotent per day: the cover can mount twice in one session
        // (a backgrounded relaunch), and two rows would read as two
        // separate tellings.
        let cal = Calendar.current
        if rows.contains(where: {
            $0.noteId == resolved.note.id
                && cal.isDateInToday($0.shownAt)
        }) { return }
        rows.insert(
            Entry(
                noteId: resolved.note.id,
                trigger: resolved.note.trigger.rawValue,
                noteVersion: resolved.note.version,
                catalogVersion: MethodCatalog.version,
                shownAt: .now,
                followUp: resolved.note.followUp.rawValue,
                fromCareTeam: resolved.note.authority.isCareTeam
            ),
            at: 0
        )
        save(rows)
    }

    static func markOpened(_ noteId: String) { mutateLatest(noteId) { $0.opened = true } }

    static func markActionTaken(_ noteId: String) {
        mutateLatest(noteId) { $0.opened = true; $0.actionTaken = true }
    }

    /// Close out proximal outcomes whose window has passed.
    ///
    /// Called with facts read from her record at launch. Deliberately
    /// one-way: once settled, an entry is never re-judged, because the
    /// window closing is the measurement.
    static func settleFollowUps(
        plateLoggedToday: Bool,
        proteinFloorMetToday: Bool,
        lastWeighInDaysAgo: Int?,
        movementRecordedDaysAgo: Int?,
        relogUsedDaysAgo: Int?
    ) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        var rows = entries()
        var changed = false
        for index in rows.indices where rows[index].followUpMet == nil {
            let shownDay = cal.startOfDay(for: rows[index].shownAt)
            let ago = cal.dateComponents([.day], from: shownDay, to: today).day ?? 0
            guard let follow = MethodNote.FollowUp(rawValue: rows[index].followUp) else {
                continue
            }
            switch follow {
            case .none:
                // Nothing observable was promised. Settle it as such so
                // it never counts either way.
                rows[index].followUpMet = nil
                continue
            case .plateLoggedToday, .proteinFloorMetToday:
                if ago == 0 {
                    let met = follow == .plateLoggedToday
                        ? plateLoggedToday : proteinFloorMetToday
                    if met { rows[index].followUpMet = true; changed = true }
                } else if ago >= 1 {
                    // The window was the day it was shown. It closed.
                    rows[index].followUpMet = false; changed = true
                }
            case .weighedInWithinThreeDays:
                if let d = lastWeighInDaysAgo, d <= ago, ago <= 3 {
                    rows[index].followUpMet = true; changed = true
                } else if ago > 3 { rows[index].followUpMet = false; changed = true }
            case .movementRecordedWithinTwoDays:
                if let d = movementRecordedDaysAgo, d <= ago, ago <= 2 {
                    rows[index].followUpMet = true; changed = true
                } else if ago > 2 { rows[index].followUpMet = false; changed = true }
            case .openedAgainWithinThreeDays:
                if let d = relogUsedDaysAgo, d <= ago, ago <= 3 {
                    rows[index].followUpMet = true; changed = true
                } else if ago > 3 { rows[index].followUpMet = false; changed = true }
            }
        }
        if changed { save(rows) }
    }

    /// The delete-account + QA sweep.
    static func wipe() { UserDefaults.standard.removeObject(forKey: key) }

    // MARK: - Internals

    private static func mutateLatest(_ noteId: String, _ change: (inout Entry) -> Void) {
        var rows = entries()
        guard let index = rows.firstIndex(where: { $0.noteId == noteId }) else { return }
        change(&rows[index])
        save(rows)
    }

    private static func save(_ rows: [Entry]) {
        let trimmed = Array(rows.prefix(maxEntries))
        guard let data = try? JSONEncoder().encode(trimmed) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
