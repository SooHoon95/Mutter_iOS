import SwiftUI

/// 음악 재생 시각화 — 골드 막대가 오르내리는 이퀄라이저.
/// 수신 뷰의 "재생 중" 인디케이터. `isPlaying`이 false면 막대가 가라앉는다.
public struct EqualizerView: View {
  private let barCount: Int
  private let color: Color
  private let isPlaying: Bool

  @State private var phase = false

  public init(barCount: Int = 4, color: Color = MutterColor.gold, isPlaying: Bool = true) {
    self.barCount = barCount
    self.color = color
    self.isPlaying = isPlaying
  }

  public var body: some View {
    HStack(alignment: .center, spacing: 3) {
      ForEach(0..<barCount, id: \.self) { index in
        Capsule()
          .fill(color)
          .frame(width: 3, height: height(for: index))
          .animation(
            isPlaying
              ? .easeInOut(duration: duration(for: index)).repeatForever(autoreverses: true)
              : .easeOut(duration: 0.2),
            value: phase
          )
      }
    }
    .frame(height: 18)
    .onAppear { phase = true }
  }

  /// 재생 중이면 막대마다 다른 높이로 진동, 정지면 최소 높이.
  private func height(for index: Int) -> CGFloat {
    guard isPlaying else { return 4 }
    let tall: CGFloat = phase ? 16 : 6
    // 인덱스마다 위상을 어긋나게 해 자연스러운 물결.
    return index % 2 == 0 ? tall : (22 - tall)
  }

  private func duration(for index: Int) -> Double {
    0.5 + Double(index % 3) * 0.18
  }
}

#Preview {
  HStack(spacing: 24) {
    EqualizerView(isPlaying: true)
    EqualizerView(isPlaying: false)
  }
  .padding()
}
