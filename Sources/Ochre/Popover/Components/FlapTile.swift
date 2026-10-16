import MetricsCore
import SwiftUI

/// Цвета табло — те же, что на сайте. Табло всегда графитовое, в любой теме.
enum BoardPalette {
    static let board = Color(.sRGB, red: 42 / 255, green: 43 / 255, blue: 46 / 255)
    static let flap = Color(.sRGB, red: 54 / 255, green: 55 / 255, blue: 59 / 255)
    static let ink = Color(.sRGB, red: 236 / 255, green: 231 / 255, blue: 218 / 255)
    static let inkDim = Color(.sRGB, red: 182 / 255, green: 176 / 255, blue: 163 / 255)
    static let inkOnWarm = Color(.sRGB, red: 26 / 255, green: 27 / 255, blue: 29 / 255)

    /// Узкий системный шрифт с табличными цифрами — буквы табло.
    static func font(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold).width(.condensed).monospacedDigit()
    }
}

/// Флажок табло: число на плитке цвета нагрева. При смене числа верхняя половинка со старым
/// значением падает вниз, а нижняя с новым дописывается — как на вокзальном табло.
struct FlapTile: View {
    let value: String
    let load: Double
    let fontSize: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Face
    @State private var previous: Face
    @State private var flips = 0

    init(value: String, load: Double, fontSize: CGFloat) {
        self.value = value
        self.load = load
        self.fontSize = fontSize
        let face = Face(text: value, load: load)
        _shown = State(initialValue: face)
        _previous = State(initialValue: face)
    }

    var body: some View {
        let old = previous, new = shown, size = fontSize
        return Color.clear
            .keyframeAnimator(initialValue: 1.0, trigger: flips) { _, progress in
                FlapLeaves(old: old, new: new, progress: progress, fontSize: size)
            } keyframes: { _ in
                MoveKeyframe(0.0)
                CubicKeyframe(1.0, duration: 0.26)
            }
            .onChange(of: Face(text: value, load: load)) { _, next in
                guard next.text != shown.text else { shown = next; previous = next; return }
                previous = shown
                shown = next
                if !reduceMotion { flips += 1 }
            }
    }
}

struct Face: Equatable {
    let text: String
    let load: Double

    var fill: Color {
        switch HeatScale.color(forLoad: load) {
        case .cold: BoardPalette.flap
        case let color: color.swiftUIColor
        }
    }

    var ink: Color { HeatScale.tileInk(forLoad: load) == .light ? BoardPalette.ink : BoardPalette.inkOnWarm }
}

/// Отрисовка одного кадра перещёлкивания: progress 0 → 1.
private struct FlapLeaves: View {
    let old: Face
    let new: Face
    let progress: Double
    let fontSize: CGFloat

    var body: some View {
        // В покое — одно лицо и шов: полный набор половинок с масками нужен только на время поворота.
        if progress >= 1 {
            ZStack {
                face(new)
                Rectangle().fill(.black.opacity(0.32)).frame(height: 1)
            }
        } else {
            leaves
        }
    }

    private var leaves: some View {
        ZStack {
            face(new).mask(TopHalf())
            face(progress < 1 ? old : new).mask(BottomHalf())
            if progress < 0.5 {
                // Верхняя половинка со старым числом падает к шву.
                face(old).mask(TopHalf())
                    .rotation3DEffect(.degrees(-180 * progress), axis: (x: 1, y: 0, z: 0), perspective: 0.45)
            } else if progress < 1 {
                // Нижняя половинка с новым числом опускается от шва на место.
                face(new).mask(BottomHalf())
                    .rotation3DEffect(.degrees(180 * (1 - progress)), axis: (x: 1, y: 0, z: 0), perspective: 0.45)
            }
            Rectangle().fill(.black.opacity(0.32)).frame(height: 1)
        }
    }

    private func face(_ face: Face) -> some View {
        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
        return ZStack {
            shape.fill(face.fill)
            BottomHalf().fill(.black.opacity(0.08)).clipShape(shape)
            Text(face.text)
                .font(BoardPalette.font(fontSize))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundStyle(face.ink)
                .padding(.horizontal, 1)
        }
    }
}

private struct TopHalf: Shape {
    func path(in rect: CGRect) -> Path { Path(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height / 2)) }
}

private struct BottomHalf: Shape {
    func path(in rect: CGRect) -> Path { Path(CGRect(x: rect.minX, y: rect.midY, width: rect.width, height: rect.height / 2)) }
}
