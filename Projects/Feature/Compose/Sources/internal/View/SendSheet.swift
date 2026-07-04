import SwiftUI

import Domain
import UIComponent

/// 저장 직후 뜨는 "보내기" 시트 — 두 방식: 전달 링크 발급 / 연결된 사람 직접 발송.
/// (Feature→Feature 의존 금지라 DeliveryView를 끌어오지 않고 Domain usecase를 직접 쓴다.)
struct SendSheet: View {
  @Bindable var model: ComposeModelData

  enum Method: String, CaseIterable, Identifiable {
    case link = "전달 링크"
    case connection = "연결된 사람"
    var id: String { rawValue }
  }
  @State private var method: Method = .link
  /// 링크 복사 완료 표시(잠시 체크 아이콘으로 전환). 시트는 닫지 않는다 — 닫기는 "완료"가 담당.
  @State private var linkCopied = false

  var body: some View {
    ZStack(alignment: .bottom) {
      // 딤 배경
      Asset.Colors.ink.color.opacity(0.4)
        .ignoresSafeArea()
        .onTapGesture { model.showSendSheet = false }

      // 시트 본체
      VStack(spacing: 0) {
        // 그립 캡슐
        Capsule()
          .fill(Asset.Colors.hairline.color)
          .frame(width: 40, height: 4)
          .padding(.top, 12)
          .padding(.bottom, 20)

        // 커스텀 세그먼트 컨트롤
        segmentedControl
          .padding(.horizontal, 20)
          .padding(.bottom, 20)

        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            switch method {
            case .link: linkSection
            case .connection: connectionSection
            }

            if let message = model.errorMessage {
              Text(message)
                .fonts(.caption)
                .foregroundStyle(Asset.Colors.goldDeep.color)
                .padding(.horizontal, 4)
            }
          }
          .padding(.horizontal, 20)
          .padding(.bottom, 36)
        }
      }
      .frame(maxWidth: .infinity)
      .background(Asset.Colors.surface.color)
      .clipShape(
        UnevenRoundedRectangle(
          topLeadingRadius: MutterRadius.xl,
          bottomLeadingRadius: 0,
          bottomTrailingRadius: 0,
          topTrailingRadius: MutterRadius.xl
        )
      )
    }
    .ignoresSafeArea()
    // 닫힐 때 에러 메시지 정리
    .onDisappear { model.errorMessage = nil }
  }

  // MARK: - 세그먼트 컨트롤

  private var segmentedControl: some View {
    HStack(spacing: 4) {
      ForEach(Method.allCases) { tab in
        Button {
          withAnimation(.easeInOut(duration: 0.18)) { method = tab }
        } label: {
          Text(tab.rawValue)
            .fonts(.bodyMediumBold)
            .foregroundStyle(
              method == tab
                ? Asset.Colors.ink.color
                : Asset.Colors.inkSoft.color
            )
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(
              method == tab
                ? AnyView(
                    RoundedRectangle(cornerRadius: MutterRadius.lg)
                      .fill(Asset.Colors.surface.color)
                      .shadows(.shadowLow)
                  )
                : AnyView(Color.clear)
            )
        }
        .buttonStyle(.plain)
      }
    }
    .padding(4)
    .background(Asset.Colors.warm100.color, in: Capsule())
  }

  // MARK: - 전달 링크

  private var linkSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      // 암호 보호 카드
      HStack(spacing: 12) {
        MutterIcon(Asset.Images.lock, size: 20)
          .foregroundStyle(Asset.Colors.gold.color)
        VStack(alignment: .leading, spacing: 2) {
          Text("암호 보호")
            .fonts(.bodyMediumBold)
            .foregroundStyle(Asset.Colors.ink.color)
          Text("기본값이 프라이버시예요")
            .fonts(.caption)
            .foregroundStyle(Asset.Colors.inkSoft.color)
        }
        Spacer()
        Toggle(isOn: $model.usePassword) {}
          .labelsHidden()
          .tint(Asset.Colors.gold.color)
      }
      .padding(14)
      .background(Asset.Colors.warm50.color)
      .clipShape(RoundedRectangle(cornerRadius: MutterRadius.lg))
      .overlay(
        RoundedRectangle(cornerRadius: MutterRadius.lg)
          .strokeBorder(Asset.Colors.hairline.color, lineWidth: 1)
      )

      // 암호 입력 필드 (암호 보호 ON 시)
      if model.usePassword {
        SecureField("암호", text: $model.password)
          .textFieldStyle(.plain)
          .fonts(.bodyMedium)
          .padding(12)
          .background(Asset.Colors.surface.color, in: RoundedRectangle(cornerRadius: MutterRadius.md))
          .overlay(
            RoundedRectangle(cornerRadius: MutterRadius.md)
              .strokeBorder(Asset.Colors.hairline.color, lineWidth: 1)
          )
      }

      // 발급된 링크 미리보기 (링크가 있을 때)
      if let link = model.issuedLink {
        HStack(spacing: 10) {
          Text(link)
            .fonts(.caption)
            .foregroundStyle(Asset.Colors.inkMid.color)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
          Button {
            copyLink(link)
          } label: {
            MutterIcon(linkCopied ? Asset.Images.check : Asset.Images.copy, size: 20)
              .foregroundStyle(Asset.Colors.gold.color)
          }
        }
        .padding(14)
        .background(Asset.Colors.surface.color)
        .clipShape(RoundedRectangle(cornerRadius: MutterRadius.lg))
        .overlay(
          RoundedRectangle(cornerRadius: MutterRadius.lg)
            .strokeBorder(
              style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
            )
            .foregroundStyle(Asset.Colors.hairlineStrong.color)
        )
      }

      // CTA 버튼 — 복사는 복사만(시트 유지 + 복사됨 피드백), 닫기는 "완료"로 분리.
      if let link = model.issuedLink {
        MutterButton(
          linkCopied ? "복사됐어요" : "링크 복사하기",
          icon: linkCopied ? Asset.Images.check : Asset.Images.copy,
          isLoading: false
        ) {
          copyLink(link)
        }
        MutterButton("완료", style: .ghost) {
          model.finishSend()
        }
      } else {
        MutterButton(
          "링크 발급",
          icon: Asset.Images.link,
          isLoading: model.isIssuing,
          isEnabled: model.canIssueLink
        ) {
          Task { await model.issueLink() }
        }
      }
    }
  }

  // MARK: - 연결된 사람

  private var connectionSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      if model.connections.isEmpty {
        sectionLabel("아직 연결된 사람이 없어요")
        Text("'전달 링크'로 보내거나, 사람들 탭에서 연결을 맺어보세요.")
          .fonts(.caption)
          .foregroundStyle(Asset.Colors.inkSoft.color)
      } else {
        sectionLabel("연결된 사람에게 바로 보내기")
        ForEach(model.connections) { connection in
          connectionRow(connection)
        }
      }
    }
  }

  private func connectionRow(_ connection: Connection) -> some View {
    HStack(spacing: 12) {
      // 아바타: 이름 첫 글자 원형
      ZStack {
        Circle()
          .fill(Asset.Colors.goldSoft.color)
          .frame(width: 40, height: 40)
        Text(String((connection.nickname ?? "?").prefix(1)))
          .fonts(.bodyLargeBold)
          .foregroundStyle(Asset.Colors.goldDeep.color)
      }

      // 이름 + 시간
      VStack(alignment: .leading, spacing: 2) {
        Text(connection.nickname ?? "이름 없는 친구")
          .fonts(.bodyLargeBold)
          .foregroundStyle(Asset.Colors.ink.color)
        Text(connection.connectedAt, style: .relative)
          .fonts(.caption)
          .foregroundStyle(Asset.Colors.inkSoft.color)
      }

      Spacer()

      // 보내기 아이콘
      Button {
        Task { await model.sendToConnection(connection.userId) }
      } label: {
        MutterIcon(Asset.Images.send, size: 22)
          .foregroundStyle(Asset.Colors.gold.color)
      }
      .disabled(model.isSending)
    }
    .padding(12)
    .background(Asset.Colors.surface.color)
    .clipShape(RoundedRectangle(cornerRadius: MutterRadius.lg))
    .overlay(
      RoundedRectangle(cornerRadius: MutterRadius.lg)
        .strokeBorder(Asset.Colors.hairline.color, lineWidth: 1)
    )
    .shadows(.shadowLow)
  }

  // MARK: - 공통 헬퍼

  /// 링크 복사 + "복사됐어요" 피드백(2초 후 원복). 시트는 닫지 않는다.
  private func copyLink(_ link: String) {
    UIPasteboard.general.string = link
    withAnimation(.easeInOut(duration: 0.15)) { linkCopied = true }
    Task { @MainActor in
      try? await Task.sleep(for: .seconds(2))
      withAnimation(.easeInOut(duration: 0.15)) { linkCopied = false }
    }
  }

  private func sectionLabel(_ text: String) -> some View {
    Text(text)
      .fonts(.captionBold)
      .foregroundStyle(Asset.Colors.inkFaint.color)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}
