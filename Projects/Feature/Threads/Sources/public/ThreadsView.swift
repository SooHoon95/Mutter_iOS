import SwiftUI

import Domain
import UIComponent

/// 스레드 탭 — 주고받은 상대 목록. 선택하면 시트로 편지 흐름을 보고 답장한다.
public struct ThreadsView: View {
  @State private var model: ThreadsModelData
  /// 답장(상대 preselect → Compose). recipientId 전달.
  private let onReply: (String) -> Void
  /// 받은 편지 열기(token).
  private let onOpen: (String) -> Void

  public init(
    threadUsecase: ThreadUsecasable,
    onReply: @escaping (String) -> Void,
    onOpen: @escaping (String) -> Void
  ) {
    _model = State(initialValue: ThreadsModelData(threadUsecase: threadUsecase))
    self.onReply = onReply
    self.onOpen = onOpen
  }

  public var body: some View {
    ZStack {
      MutterColor.ivory.ignoresSafeArea()
      if model.counterparts.isEmpty && !model.isLoading {
        emptyState
      } else {
        ScrollView {
          LazyVStack(spacing: 10) {
            ForEach(model.counterparts) { counterpart in
              Button { Task { await model.openThread(counterpart) } } label: { row(counterpart) }
                .buttonStyle(PressableButtonStyle())
            }
          }
          .padding(20)
          .frame(maxWidth: 600)
        }
      }
    }
    .task { await model.load() }
    .sheet(item: Binding(get: { model.selectedCounterpart }, set: { if $0 == nil { model.closeThread() } })) { counterpart in
      threadSheet(counterpart)
    }
  }

  private func row(_ counterpart: Counterpart) -> some View {
    HStack(spacing: 12) {
      Image(systemName: "person.crop.circle.fill").foregroundStyle(MutterColor.gold)
      Text(counterpart.nickname ?? "이름 없음")
        .fonts(.bodyMediumBold).foregroundStyle(MutterColor.ink)
      Spacer()
      Text("\(counterpart.exchangeCount)통")
        .fonts(.caption).foregroundStyle(MutterColor.inkSoft)
      Image(systemName: "chevron.right").foregroundStyle(MutterColor.inkFaint)
    }
    .padding(16)
    .background(MutterColor.surface, in: RoundedRectangle(cornerRadius: MutterRadius.lg))
    .shadows(.soft)
  }

  private func threadSheet(_ counterpart: Counterpart) -> some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 10) {
          ForEach(model.thread) { letter in
            threadRow(letter)
          }
        }
        .padding(20)
      }
      .background(MutterColor.ivory.ignoresSafeArea())
      .navigationTitle(counterpart.nickname ?? "편지")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("답장") {
            model.closeThread()
            onReply(counterpart.userId)
          }
        }
      }
    }
  }

  private func threadRow(_ letter: ThreadLetter) -> some View {
    let isSent = letter.direction == .sent
    return HStack {
      if isSent { Spacer(minLength: 40) }
      VStack(alignment: isSent ? .trailing : .leading, spacing: 4) {
        Text(letter.title.isEmpty ? "편지" : letter.title)
          .fonts(.bodyMediumBold).foregroundStyle(MutterColor.ink)
        Text(isSent ? "보냄" : "받음")
          .fonts(.caption).foregroundStyle(MutterColor.inkSoft)
      }
      .padding(14)
      .background(isSent ? MutterColor.goldSoft : MutterColor.surface, in: RoundedRectangle(cornerRadius: MutterRadius.lg))
      .onTapGesture {
        if !isSent, let token = letter.token {
          model.closeThread()
          onOpen(token)
        }
      }
      if !isSent { Spacer(minLength: 40) }
    }
  }

  private var emptyState: some View {
    VStack(spacing: 8) {
      Image(systemName: "bubble.left.and.bubble.right").font(.system(size: 32)).foregroundStyle(MutterColor.inkFaint)
      Text("주고받은 편지가 없어요").fonts(.bodyLarge).foregroundStyle(MutterColor.inkSoft)
    }
  }
}
