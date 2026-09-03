import Foundation

// MARK: - SpokenDayReference (p72 — the stated day survives the words door)
//
// "last night i had a bowl of chicken soup" used to file as a plate at
// the wall-clock moment she typed it — "snack · 11:43pm", TODAY. Her
// stated numbers have survived the words door verbatim since p61
// (`StatedPlate`), and her stated qualifiers since p53 ("half a turkey
// sandwich" never matches the whole one), but her stated DAY was
// silently discarded: today's remainder dial dropped for a meal she ate
// yesterday, and yesterday's record stayed empty. Both days wrong, from
// a sentence that said the day plainly.
//
// This is the detector, and it is deliberately narrow. V1 understands
// exactly one past day — yesterday ("yesterday", "yesterday's", "last
// night") — because the forgotten-dinner backfill is the case users
// actually live (the day-move row on the plate page covers the rest,
// 14 days back). It REFUSES rather than guesses:
//
//   · a same-day word alongside ("today", "tonight", "this morning…")
//     reads as a mixed or present-tense statement → nil;
//   · "same as yesterday", "like last night", "more than yesterday"
//     are comparisons about TODAY's food → nil;
//   · "leftovers from last night" is yesterday's food eaten TODAY →
//     any "from <day>" or "leftover" reads as provenance, not timing
//     → nil;
//   · "the day before yesterday" is two days back, which V1 does not
//     speak → nil (never a wrong guess).
//
// nil means "file to today", the exact behavior before this file — the
// detector can only ever move a plate to the day she herself named.
public enum SpokenDayReference {

    /// 1 = yesterday. nil = no confident past-day statement.
    public static func daysAgo(in text: String) -> Int? {
        let lower = text.lowercased()

        guard matches(lower, #"\byesterday\b"#)
            || matches(lower, #"\blast night\b"#)
        else { return nil }

        // Same-day words → a mixed or present statement. "tonight" and
        // "this morning" also catch "last night vs tonight" comparisons.
        for present in [#"\btoday\b"#, #"\btonight\b"#,
                        #"\bthis morning\b"#, #"\bthis afternoon\b"#,
                        #"\bthis evening\b"#] where matches(lower, present) {
            return nil
        }

        // Comparison / provenance shapes: the day names WHAT the food
        // is, not WHEN she ate it.
        for refusal in [#"\b(as|than|like|since|from|before)\s+yesterday\b"#,
                        #"\b(as|than|like|since|from|before)\s+last night\b"#,
                        #"\bleftover"#] where matches(lower, refusal) {
            return nil
        }

        return 1
    }

    private static func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }
}
