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
      Asset.Colors.ivory.color.ignoresSafeArea()

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
          .padding(.horizontal, 20)
          .padding(.vertical, 16)
          .frame(maxWidth: 600)
        }
      }
    }
    .task { await model.load() }
    .sheet(item: Binding(get: { model.selectedCounterpart }, set: { if $0 == nil { model.closeThread() } })) { counterpart in
      threadSheet(counterpart)
    }
  }

  // MARK: - 상대 목록 카드 행

  private func row(_ counterpart: Counterpart) -> some View {
    HStack(spacing: 14) {
      // 아바타 원 — 상대 이름 이니셜
      ZStack {
        Circle()
          .fill(Asset.Colors.goldSoft.color)
          .frame(width: 44, height: 44)
        Text(String((counterpart.nickname ?? "?").prefix(1)))
          .fonts(.bodyLargeBold)
          .foregroundStyle(Asset.Colors.goldDeep.color)
      }

      VStack(alignment: .leading, spacing: 3) {
        Text(counterpart.nickname ?? L10n.threadsUnnamed)
          .fonts(.bodyLargeBold)
          .foregroundStyle(Asset.Colors.ink.color)
          .lineLimit(1)
        Text(L10n.threadsExchangeCount(counterpart.exchangeCount))
          .fonts(.caption)
          .foregroundStyle(Asset.Colors.inkFaint.color)
      }

      Spacer()

      MutterIcon(Asset.Images.chevronRight, size: 16)
        .foregroundStyle(Asset.Colors.inkFaint.color)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.lg))
    .overlay(
      RoundedRectangle(cornerRadius: MutterRadius.lg)
        .strokeBorder(Asset.Colors.hairline.color, lineWidth: 0.5)
    )
    .shadows(.shadowLow)
  }

  // MARK: - 대화 시트 (단일 상대와의 편지 흐름)

  private func threadSheet(_ counterpart: Counterpart) -> some View {
    NavigationStack {
      ZStack {
        Asset.Colors.ivory.color.ignoresSafeArea()

        VStack(spacing: 0) {
          // 편지 버블 목록
          ScrollView {
            LazyVStack(spacing: 12) {
              ForEach(model.thread) { letter in
                threadRow(letter)
              }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
          }

          // 하단 편지 쓰기 바
          bottomBar(counterpart)
        }
      }
      .navigationTitle(counterpart.nickname ?? L10n.threadsLetterFallback)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button {
            model.closeThread()
          } label: {
            MutterIcon(Asset.Images.chevronRight, size: 20)
              .rotationEffect(.degrees(180))
              .foregroundStyle(Asset.Colors.ink.color)
          }
        }
        ToolbarItem(placement: .topBarTrailing) {
          // 상대 이니셜 아바타
          ZStack {
            Circle()
              .fill(Asset.Colors.goldSoft.color)
              .frame(width: 32, height: 32)
            Text(String((counterpart.nickname ?? "?").prefix(1)))
              .fonts(.captionBold)
              .foregroundStyle(Asset.Colors.goldDeep.color)
          }
        }
      }
    }
  }

  // MARK: - 편지 말풍선 행

  private func threadRow(_ letter: ThreadLetter) -> some View {
    let isSent = letter.direction == .sent
    let cornerRadii = RectangleCornerRadii(
      topLeading: MutterRadius.lg,
      bottomLeading: isSent ? MutterRadius.lg : MutterRadius.sm,
      bottomTrailing: isSent ? MutterRadius.sm : MutterRadius.lg,
      topTrailing: MutterRadius.lg
    )
    return HStack(alignment: .bottom, spacing: 0) {
      if isSent { Spacer(minLength: 60) }

      VStack(alignment: isSent ? .trailing : .leading, spacing: 0) {
        // 말풍선 본체
        HStack(spacing: 10) {
          MutterIcon(
            isSent ? Asset.Images.envelopeOpen : Asset.Images.envelope,
            size: 18
          )
          .foregroundStyle(isSent ? Asset.Colors.goldDeep.color : Asset.Colors.gold.color)

          VStack(alignment: .leading, spacing: 3) {
            Text(letter.title.isEmpty ? L10n.threadsLetterFallback : letter.title)
              .fonts(.bodyMediumBold)
              .foregroundStyle(Asset.Colors.ink.color)
              .lineLimit(2)

            Text(letter.sentAt, style: .relative)
              .fonts(.caption)
              .foregroundStyle(Asset.Colors.inkFaint.color)
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
          isSent ? Asset.Colors.goldSoft.color : Asset.Colors.surface.color,
          in: UnevenRoundedRectangle(cornerRadii: cornerRadii)
        )
        .overlay(
          Group {
            if !isSent {
              UnevenRoundedRectangle(cornerRadii: cornerRadii)
                .strokeBorder(Asset.Colors.hairline.color, lineWidth: 0.5)
            }
          }
        )
        .shadows(.shadowLow)
      }
      .contentShape(Rectangle())
      .onTapGesture {
        if !isSent, let token = letter.token {
          model.closeThread()
          onOpen(token)
        }
      }

      if !isSent { Spacer(minLength: 60) }
    }
  }

  // MARK: - 하단 편지 쓰기 바

  private func bottomBar(_ counterpart: Counterpart) -> some View {
    VStack(spacing: 0) {
      Divider()
        .background(Asset.Colors.hairline.color)

      let buttonTitle = counterpart.nickname.map { L10n.threadsWriteTo($0) } ?? L10n.threadsWrite
      MutterButton(buttonTitle, icon: Asset.Images.compose) {
        model.closeThread()
        onReply(counterpart.userId)
      }
      .padding(.horizontal, 20)
      .padding(.top, 16)
      .padding(.bottom, 24)
    }
    .background(Asset.Colors.surface.color)
  }

  // MARK: - 빈 상태

  private var emptyState: some View {
    VStack(spacing: 16) {
      MutterIcon(Asset.Images.emptyConnections, size: 120)
        .foregroundStyle(Asset.Colors.inkFaint.color)
      Text(L10n.threadsEmptyTitle)
        .fonts(.bodyLarge)
        .foregroundStyle(Asset.Colors.inkSoft.color)
      Text(L10n.threadsEmptyDetail)
        .fonts(.caption)
        .foregroundStyle(Asset.Colors.inkFaint.color)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(.bottom, 60)
  }
}
