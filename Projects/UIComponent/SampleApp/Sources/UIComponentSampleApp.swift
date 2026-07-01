import SwiftUI

import UIComponent

@main
struct UIComponentSampleApp: App {
  var body: some Scene { WindowGroup { IconGalleryView() } }
}

/// 디자인 시스템 커스텀 아이콘/일러스트/시맨틱색이 실제로 렌더되는지 확인하는 갤러리(인증 불필요).
struct IconGalleryView: View {
  private let icons: [(String, ImageAsset)] = [
    ("envelope", Asset.Images.envelope), ("envelopeOpen", Asset.Images.envelopeOpen),
    ("compose", Asset.Images.compose), ("send", Asset.Images.send),
    ("play", Asset.Images.play), ("pause", Asset.Images.pause),
    ("note", Asset.Images.note), ("musicLink", Asset.Images.musicLink),
    ("moodCalm", Asset.Images.moodCalm), ("moodWarm", Asset.Images.moodWarm),
    ("moodLonging", Asset.Images.moodLonging), ("moodTag", Asset.Images.moodTag),
    ("lock", Asset.Images.lock), ("clock", Asset.Images.clock),
    ("calendar", Asset.Images.calendar), ("copy", Asset.Images.copy),
    ("link", Asset.Images.link), ("linkBroken", Asset.Images.linkBroken),
    ("reply", Asset.Images.reply), ("connect", Asset.Images.connect),
    ("person", Asset.Images.person), ("thread", Asset.Images.thread),
    ("trash", Asset.Images.trash), ("checkCircle", Asset.Images.checkCircle),
    ("chevronRight", Asset.Images.chevronRight), ("settings", Asset.Images.settings),
    ("tabHome", Asset.Images.tabHome), ("tabHomeFill", Asset.Images.tabHomeFill),
    ("tabInbox", Asset.Images.tabInbox), ("tabPeople", Asset.Images.tabPeople),
    ("preview", Asset.Images.preview), ("read", Asset.Images.read),
  ]

  var body: some View {
    ZStack {
      Asset.Colors.ivory.color.ignoresSafeArea()
      ScrollView {
        VStack(spacing: 22) {
          Text("Mutter 디자인 시스템 · 아이콘")
            .font(.title3.bold()).foregroundStyle(Asset.Colors.ink.color)
            .padding(.top, 12)

          LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 18) {
            ForEach(icons, id: \.0) { name, asset in
              VStack(spacing: 6) {
                MutterIcon(asset, size: 28).foregroundStyle(Asset.Colors.gold.color)
                Text(name).font(.system(size: 8)).foregroundStyle(Asset.Colors.inkSoft.color)
                  .lineLimit(1).minimumScaleFactor(0.7)
              }
            }
          }

          // 잉크색(기본 틴트) + 시맨틱색 틴트 확인
          HStack(spacing: 18) {
            MutterIcon(Asset.Images.envelope, size: 28).foregroundStyle(Asset.Colors.ink.color)
            MutterIcon(Asset.Images.lock, size: 28).foregroundStyle(Asset.Colors.inkSoft.color)
            MutterIcon(Asset.Images.trash, size: 28).foregroundStyle(Asset.Colors.danger.color)
            MutterIcon(Asset.Images.checkCircle, size: 28).foregroundStyle(Asset.Colors.success.color)
          }

          // 빈상태 일러스트(2색 고정)
          Text("일러스트").font(.caption.bold()).foregroundStyle(Asset.Colors.inkSoft.color)
          HStack(spacing: 12) {
            Asset.Images.emptyReceived.image.resizable().scaledToFit().frame(height: 64)
            Asset.Images.emptySent.image.resizable().scaledToFit().frame(height: 64)
            Asset.Images.emptyConnections.image.resizable().scaledToFit().frame(height: 64)
          }

          // 시맨틱색 스와치
          Text("시맨틱 색").font(.caption.bold()).foregroundStyle(Asset.Colors.inkSoft.color)
          HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8).fill(Asset.Colors.success.color).frame(width: 44, height: 28)
            RoundedRectangle(cornerRadius: 8).fill(Asset.Colors.danger.color).frame(width: 44, height: 28)
            RoundedRectangle(cornerRadius: 8).fill(Asset.Colors.warning.color).frame(width: 44, height: 28)
            RoundedRectangle(cornerRadius: 8).fill(Asset.Colors.info.color).frame(width: 44, height: 28)
          }
        }
        .padding(20)
      }
    }
  }
}
