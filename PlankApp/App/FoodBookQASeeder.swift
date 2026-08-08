#if DEBUG
import UIKit
import PlankFood

// MARK: - FoodBookQASeeder (v23 THE STILL LIFE — THE LOOP's food)
//
// Seeds a photogenic week for filming THE BOOK: four recent days
// with rendered plate photographs (hero + grid + typographic rows
// all exercised), plus one plate a month back so the month seam
// draws. Deterministic ids — re-runs are no-ops (debugSeed guards).
// The renders are obviously synthetic still lifes (a plate on a
// tinted ground), never fake food photography presented as real.

enum FoodBookQASeeder {

    static func seedWeek(userId: String) {
        let cal = Calendar.current
        func at(dayOffset: Int, hour: Int, minute: Int = 0) -> Date {
            let day = cal.date(byAdding: .day, value: -dayOffset, to: cal.startOfDay(for: .now))!
            return cal.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
        }

        struct Seed {
            let id: String
            let when: Date
            let title: String
            let kcal: Double
            let protein: Double
            let carbs: Double
            let fat: Double
            let fiber: Double
            let sugar: Double
            let sodium: Double
            let source: String
            let hue: CGFloat?   // nil = no photograph (typographic row)
        }

        let seeds: [Seed] = [
            .init(id: "qa-book-01", when: at(dayOffset: 0, hour: 8, minute: 40),
                  title: "greek yogurt + berries", kcal: 260, protein: 19,
                  carbs: 28, fat: 7, fiber: 4, sugar: 14, sodium: 90,
                  source: "photo", hue: 0.86),
            .init(id: "qa-book-02", when: at(dayOffset: 0, hour: 12, minute: 25),
                  title: "chicken salad bowl", kcal: 540, protein: 42,
                  carbs: 31, fat: 26, fiber: 7, sugar: 6, sodium: 620,
                  source: "photo", hue: 0.28),
            .init(id: "qa-book-03", when: at(dayOffset: 1, hour: 9, minute: 5),
                  title: "avocado toast + eggs", kcal: 445, protein: 19,
                  carbs: 34, fat: 26, fiber: 8, sugar: 4, sodium: 480,
                  source: "photo", hue: 0.21),
            .init(id: "qa-book-04", when: at(dayOffset: 1, hour: 13, minute: 10),
                  title: "bibimbap", kcal: 690, protein: 31,
                  carbs: 82, fat: 24, fiber: 6, sugar: 9, sodium: 940,
                  source: "photo", hue: 0.07),
            .init(id: "qa-book-05", when: at(dayOffset: 1, hour: 19, minute: 40),
                  title: "matcha latte with oat milk", kcal: 140, protein: 4,
                  carbs: 18, fat: 6, fiber: 1, sugar: 12, sodium: 105,
                  source: "text", hue: nil),
            .init(id: "qa-book-06", when: at(dayOffset: 2, hour: 12, minute: 0),
                  title: "ahi poke bowl", kcal: 520, protein: 38,
                  carbs: 56, fat: 15, fiber: 5, sugar: 8, sodium: 850,
                  source: "photo", hue: 0.55),
            .init(id: "qa-book-07", when: at(dayOffset: 2, hour: 19, minute: 5),
                  title: "salmon + rice + greens", kcal: 640, protein: 41,
                  carbs: 58, fat: 24, fiber: 5, sugar: 3, sodium: 510,
                  source: "photo", hue: 0.98),
            .init(id: "qa-book-08", when: at(dayOffset: 3, hour: 8, minute: 30),
                  title: "oatmeal with banana", kcal: 320, protein: 9,
                  carbs: 62, fat: 6, fiber: 7, sugar: 18, sodium: 60,
                  source: "photo", hue: 0.12),
            .init(id: "qa-book-09", when: at(dayOffset: 3, hour: 19, minute: 30),
                  title: "pasta with tomatoes", kcal: 580, protein: 18,
                  carbs: 92, fat: 15, fiber: 6, sugar: 11, sodium: 640,
                  source: "text", hue: nil),
            .init(id: "qa-book-10", when: at(dayOffset: 36, hour: 12, minute: 15),
                  title: "the first plate", kcal: 480, protein: 28,
                  carbs: 44, fat: 20, fiber: 5, sugar: 7, sodium: 430,
                  source: "photo", hue: 0.62),
        ]

        for seed in seeds {
            FoodLogPersister.debugSeed(
                id: seed.id, userId: userId, loggedAt: seed.when,
                kcal: seed.kcal, protein: seed.protein, carbs: seed.carbs,
                fat: seed.fat, fiber: seed.fiber, sugar: seed.sugar,
                sodiumMg: seed.sodium, title: seed.title, source: seed.source
            )
            if let hue = seed.hue, FoodPhotoStore.photo(entryId: seed.id) == nil,
               let jpeg = stillLife(hue: hue).jpegData(compressionQuality: 0.85) {
                FoodPhotoStore.store(jpeg, entryId: seed.id)
            }
        }
    }

    /// A synthetic still life: warm tinted ground, a ceramic plate,
    /// a few food-toned forms. Obviously staged; photogenic enough
    /// to judge the book's layout on film.
    private static func stillLife(hue: CGFloat) -> UIImage {
        let size = CGSize(width: 900, height: 675)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            let top = UIColor(hue: hue, saturation: 0.32, brightness: 0.82, alpha: 1)
            let bottom = UIColor(hue: fmod(hue + 0.04, 1), saturation: 0.42, brightness: 0.58, alpha: 1)
            let bg = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [top.cgColor, bottom.cgColor] as CFArray,
                locations: [0, 1]
            )!
            c.drawLinearGradient(bg, start: .zero,
                                 end: CGPoint(x: 0, y: size.height), options: [])

            // The plate.
            let plateRect = CGRect(x: 170, y: 120, width: 560, height: 430)
            c.setShadow(offset: CGSize(width: 0, height: 14), blur: 36,
                        color: UIColor.black.withAlphaComponent(0.30).cgColor)
            c.setFillColor(UIColor(white: 0.97, alpha: 1).cgColor)
            c.fillEllipse(in: plateRect)
            c.setShadow(offset: .zero, blur: 0, color: nil)
            c.setFillColor(UIColor(white: 0.92, alpha: 1).cgColor)
            c.fillEllipse(in: plateRect.insetBy(dx: 46, dy: 36))

            // The food — three toned forms.
            let f1 = UIColor(hue: fmod(hue + 0.92, 1), saturation: 0.55, brightness: 0.72, alpha: 1)
            let f2 = UIColor(hue: fmod(hue + 0.10, 1), saturation: 0.48, brightness: 0.66, alpha: 1)
            let f3 = UIColor(hue: fmod(hue + 0.24, 1), saturation: 0.38, brightness: 0.80, alpha: 1)
            c.setFillColor(f1.cgColor)
            c.fillEllipse(in: CGRect(x: 280, y: 220, width: 220, height: 160))
            c.setFillColor(f2.cgColor)
            c.fillEllipse(in: CGRect(x: 430, y: 280, width: 180, height: 140))
            c.setFillColor(f3.cgColor)
            c.fillEllipse(in: CGRect(x: 350, y: 330, width: 150, height: 110))
        }
    }
}
#endif
