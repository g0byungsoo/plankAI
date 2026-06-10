import SwiftUI

// MARK: - RoastCardView (DEPRECATED — pre-rebrand share card)
//
// v8 P8.10 audit (2026-06-10): zero callers anywhere in the project.
// The shipped post-session share is the v1.0.9 D3.C 9:16 share built
// into PostSessionView (see commit a075150). RoastCardView dates from
// the pre-JeniFit rebrand and references "Plank Coach" voice + uses
// an em-dash byline that violates current voice rules.
//
// FILE INTENTIONALLY KEPT AS A STUB until a future Xcode-project pass
// removes the pbxproj reference (deleting the .swift file alone breaks
// the build with "Build input file cannot be found"). When that pass
// happens, this file + the parent /Share folder can both be deleted.

struct RoastCardView: View {
    var body: some View {
        EmptyView()
    }
}
