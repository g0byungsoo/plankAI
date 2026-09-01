import SwiftUI

// MARK: - JFDeviceDemoFrame
//
// The welcome hero: a realistic device frame cycling three live
// SwiftUI mocks of the actual product (daily plan · snap camera ·
// steps). Ported from the founder-approved v4.5 welcomeDemoFrame
// (that private twin dies with the v4.5 sweep). Round 2 upgrades:
// the camera scene shows the founder's real poke plate with the
// demo's honest 500-cal read — screen one whispers the exact moment
// the mid-flow snap demo cashes.

struct JFDeviceDemoFrame: View {
    let height: CGFloat
    /// v6 P4 — pin the frame to one scene (0 plan · 1 camera ·
    /// 2 steps) with no cycling. The first-week beat shows tomorrow
    /// morning's checklist as a still object, not a carousel.
    var lockedScene: Int? = nil

    @State private var page = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let width = height * 0.482
        let outerRadius = height * 0.118

        return ZStack {
            RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                .fill(Color(red: 0.13, green: 0.11, blue: 0.11))
                .overlay(
                    RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )

            ZStack {
                RoundedRectangle(cornerRadius: outerRadius - 4, style: .continuous)
                    .fill(Palette.bgPrimary)

                Group {
                    switch lockedScene ?? page {
                    case 1: cameraScene
                    case 2: stepsScene
                    default: planScene
                    }
                }
                .transition(.opacity)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .padding(.top, 24)
            }
            .clipShape(RoundedRectangle(cornerRadius: outerRadius - 4, style: .continuous))
            .padding(4)

            VStack {
                Capsule()
                    .fill(Color.black)
                    .frame(width: width * 0.30, height: 14)
                    .padding(.top, 13)
                Spacer()
            }
        }
        .frame(width: width, height: height)
        .overlay(alignment: .topLeading) {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color(red: 0.10, green: 0.08, blue: 0.08))
                    .frame(width: 2.5, height: height * 0.045)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color(red: 0.10, green: 0.08, blue: 0.08))
                    .frame(width: 2.5, height: height * 0.085)
            }
            .offset(x: -2.5, y: height * 0.20)
        }
        .overlay(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(red: 0.10, green: 0.08, blue: 0.08))
                .frame(width: 2.5, height: height * 0.12)
                .offset(x: 2.5, y: height * 0.24)
        }
        .shadow(color: .black.opacity(0.16), radius: 22, y: 12)
        .accessibilityLabel("a preview of jeni: your daily plan, the food camera, and steps")
        .task {
            guard lockedScene == nil, !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_600_000_000)
                guard !Task.isCancelled else { break }
                withAnimation(Motion.crossFade) { page = (page + 1) % 3 }
            }
        }
    }

    // MARK: plan

    private var planScene: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("day 1")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14))
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.white, in: Capsule())
                    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                Spacer()
                Image("onb-profile-latte")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 26, height: 26)
                    .background(Palette.accentSubtle)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
            }
            .padding(.top, 16)

            HStack(spacing: 5) {
                ForEach(0..<14, id: \.self) { i in
                    Capsule()
                        .fill(i == 0 ? Palette.bgInverse : Palette.accentSubtle)
                        .frame(width: 3, height: i == 0 ? 14 : 10)
                }
                Spacer()
            }

            Spacer(minLength: 0)

            planRow(thumb: "onb-itgirl-firstweek", title: "move", sub: "10 min", done: true)
            planRow(thumb: "onb-itgirl-preeat", title: "add a meal", sub: "before you eat", done: false)
            stepsRow
            planRow(thumb: "onb-itgirl-journal", title: "the method", sub: "2-min read", done: false)

            Spacer(minLength: 0)
        }
    }

    private func planRow(thumb: String, title: String, sub: String, done: Bool) -> some View {
        HStack(spacing: 9) {
            Image(thumb)
                .resizable()
                .scaledToFill()
                .frame(width: 38, height: 38)
                .background(Palette.accentSubtle)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.custom("DMSans-SemiBold", size: 12))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(sub)
                    .font(.custom("DMSans-Regular", size: 9.5))
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            ZStack {
                Circle()
                    .strokeBorder(
                        done ? Palette.cocoaPrimary : Palette.cocoaPrimary.opacity(0.25),
                        lineWidth: 1.5
                    )
                    .frame(width: 19, height: 19)
                if done {
                    Circle().fill(Palette.cocoaPrimary).frame(width: 19, height: 19)
                    Image(systemName: "checkmark")
                        .font(.custom("DMSans-SemiBold", size: 9))
                        .foregroundStyle(Palette.textInverse)
                }
            }
        }
        .padding(8)
        .background(Color.white, in: RoundedRectangle(cornerRadius: Radius.chip))
        .shadow(color: .black.opacity(0.04), radius: 5, y: 2)
    }

    private var stepsRow: some View {
        HStack(spacing: 9) {
            ZStack {
                Circle().stroke(Palette.accentSubtle, lineWidth: 3.5)
                Circle()
                    .trim(from: 0, to: 0.62)
                    .stroke(Palette.accent, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text("7,500 steps")
                    .font(.custom("DMSans-SemiBold", size: 12))
                    .foregroundStyle(Palette.textPrimary)
                Text("counted for you")
                    .font(.custom("DMSans-Regular", size: 9.5))
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(Color.white, in: RoundedRectangle(cornerRadius: Radius.chip))
        .shadow(color: .black.opacity(0.04), radius: 5, y: 2)
    }

    // MARK: camera

    private var cameraScene: some View {
        VStack(spacing: 10) {
            Spacer().frame(height: 20)
            ZStack {
                RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Palette.cocoaPrimary.opacity(0.88),
                                     Palette.cocoaPrimary.opacity(0.60)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                // The founder's real plate — the same bowl the mid-flow
                // demo reads, so screen one and the demo agree.
                Image("onb-v5-demo-poke")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 108, height: 108)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.65), lineWidth: 1.5))
                ScanBracketsShape()
                    .stroke(Color.white.opacity(0.9), lineWidth: 2.5)
                    .padding(13)

                VStack {
                    Spacer()
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.custom("DMSans-Regular", size: 10))
                            .foregroundStyle(Palette.stateGood)
                        Text("fits today")
                            .font(.custom("DMSans-SemiBold", size: 10.5))
                            .foregroundStyle(Palette.textPrimary)
                        Text("· 500 cal")
                            .font(.custom("DMSans-Regular", size: 10))
                            .foregroundStyle(Palette.textSecondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white, in: Capsule())
                    .padding(.bottom, 10)
                }
            }
            .frame(maxHeight: .infinity)

            Text("add it before you eat")
                .font(.custom("DMSans-SemiBold", size: 11))
                .foregroundStyle(Palette.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.white, in: Capsule())

            HStack(spacing: 22) {
                Image(systemName: "photo.on.rectangle")
                    .font(.custom("DMSans-Regular", size: 13))
                    .foregroundStyle(Palette.textSecondary)
                Circle()
                    .stroke(Palette.bgInverse, lineWidth: 3)
                    .frame(width: 36, height: 36)
                    .overlay(Circle().fill(Palette.bgInverse).frame(width: 26, height: 26))
                Image(systemName: "bolt.slash")
                    .font(.custom("DMSans-Regular", size: 13))
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.bottom, 2)
        }
    }

    // MARK: steps

    private var stepsScene: some View {
        VStack(spacing: 14) {
            Spacer()
            ZStack {
                Circle().stroke(Palette.accentSubtle, lineWidth: 9)
                Circle()
                    .trim(from: 0, to: 0.62)
                    .stroke(Palette.accent, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("4,680")
                        .font(.custom("Fraunces72pt-SemiBold", size: 26))
                        .foregroundStyle(Palette.textPrimary)
                    Text("of 7,500 steps")
                        .font(.custom("DMSans-Regular", size: 10))
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            .frame(width: 118, height: 118)

            VStack(spacing: 6) {
                HStack(alignment: .bottom, spacing: 7) {
                    ForEach(Array([0.55, 0.8, 0.45, 0.95, 0.7, 0.3, 0.62].enumerated()), id: \.offset) { i, h in
                        Capsule()
                            .fill(i == 6 ? Palette.accent : Palette.accentSubtle)
                            .frame(width: 9, height: 12 + 26 * h)
                    }
                }
                HStack(spacing: 7) {
                    ForEach(["m", "t", "w", "t", "f", "s", "s"].indices, id: \.self) { i in
                        Text(["m", "t", "w", "t", "f", "s", "s"][i])
                            .font(.custom("DMSans-Medium", size: 7.5))
                            .foregroundStyle(i == 6 ? Palette.textPrimary : Palette.textSecondary)
                            .frame(width: 9)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white, in: RoundedRectangle(cornerRadius: Radius.chip))
            .shadow(color: .black.opacity(0.04), radius: 5, y: 2)

            Text("the everyday anchor")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 12))
                .foregroundStyle(Palette.textSecondary)
            Spacer()
        }
    }
}

/// Viewfinder corner brackets.
struct ScanBracketsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let len: CGFloat = min(rect.width, rect.height) * 0.14
        let r: CGFloat = 7
        // top-left
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + len))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY),
                       control: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + len, y: rect.minY))
        // top-right
        p.move(to: CGPoint(x: rect.maxX - len, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r),
                       control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + len))
        // bottom-right
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - len))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY),
                       control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - len, y: rect.maxY))
        // bottom-left
        p.move(to: CGPoint(x: rect.minX + len, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r),
                       control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - len))
        return p
    }
}
