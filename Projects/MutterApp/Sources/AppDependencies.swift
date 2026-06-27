import Foundation

import Domain
import Infrastructure
import Networking

/// 합성 루트의 의존성 그래프 — SupabaseProvider → Repository → Usecase를 1회 구성한다.
/// (명시적 생성자 주입. Feature는 이 usecase들을 받아 동작한다.)
@MainActor
final class AppDependencies {
  /// 전달/연결 링크 베이스 URL(Universal Link 도메인).
  let linkBaseURL = "https://mutter.app"

  private let provider = SupabaseProvider.shared

  // MARK: - Repositories
  private lazy var authRepo = AuthRepository(provider: provider)
  private lazy var profileRepo = ProfileRepository(provider: provider)
  private lazy var letterRepo = LetterRepository(provider: provider)
  private lazy var catalogRepo = CatalogRepository()
  private lazy var deliveryRepo = DeliveryRepository(provider: provider)
  private lazy var receiptRepo = ReceiptRepository(provider: provider)
  private lazy var inboxRepo = InboxRepository(provider: provider)
  private lazy var connectionRepo = ConnectionRepository(provider: provider)
  private lazy var threadRepo = ThreadRepository(provider: provider)
  private lazy var takedownRepo = TakedownRepository(provider: provider)

  // MARK: - Usecases
  lazy var authUsecase: AuthUsecasable = AuthUsecase(repository: authRepo)
  lazy var profileUsecase: ProfileUsecasable = ProfileUsecase(repository: profileRepo)
  lazy var letterUsecase: LetterUsecasable = LetterUsecase(repository: letterRepo, catalog: catalogRepo)
  lazy var catalogUsecase: CatalogUsecasable = CatalogUsecase(repository: catalogRepo)
  lazy var deliveryUsecase: DeliveryUsecasable = DeliveryUsecase(repository: deliveryRepo)
  lazy var receiptUsecase: ReceiptUsecasable = ReceiptUsecase(repository: receiptRepo)
  lazy var inboxUsecase: InboxUsecasable = InboxUsecase(repository: inboxRepo)
  lazy var connectionUsecase: ConnectionUsecasable = ConnectionUsecase(repository: connectionRepo)
  lazy var threadUsecase: ThreadUsecasable = ThreadUsecase(repository: threadRepo)
  lazy var takedownUsecase: TakedownUsecasable = TakedownUsecase(repository: takedownRepo)
  lazy var audioUsecase: AudioUsecasable = AudioUsecase(catalog: catalogRepo)
}
