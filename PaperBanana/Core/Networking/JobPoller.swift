import Foundation

/// 任务轮询器：指数退避 + 总时长上限 + 连续失败熔断。
///
/// - 初始间隔 2s，每次 ×1.5 退避，封顶 15s。
/// - 总时长超过 10 分钟停止并产出 `.timedOut`；预算按 `now()` 墙钟真实流逝判断
///   （包含 fetch 耗时与暂停期间），而非只累计 sleep 时长。
/// - 连续 5 次请求失败停止并产出 `.repeatedFailures`；单次失败不中断。
/// - 任务到达 terminal 状态（succeeded/failed）立即停止。
/// - 任务状态变化（status 或 stages 数量变化）会把退避间隔重置回初始值，
///   保证流水线动画及时跟进。
/// - `pause()`/`resume()` 供 scenePhase 接线；resume 会立即刷一次。
@MainActor
final class JobPoller {
  struct Configuration {
    var initialInterval: Duration = .seconds(2)
    var backoffMultiplier: Double = 1.5
    var maxInterval: Duration = .seconds(15)
    var overallBudget: Duration = .seconds(600)
    var maxConsecutiveFailures: Int = 5
  }

  enum Termination: Equatable {
    case reachedTerminalStatus
    case timedOut
    case repeatedFailures(message: String)
  }

  typealias Fetch = @MainActor () async throws -> Job
  typealias UpdateHandler = @MainActor (Job) -> Void
  typealias FinishHandler = @MainActor (Termination) -> Void

  /// 可注入的睡眠实现；测试里替换成只记录间隔的 fake，避免真实等待。
  var sleep: @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
  /// 可注入的当前时刻来源；测试里替换成手动推进的 fake，让预算判断可控。
  var now: @MainActor () -> ContinuousClock.Instant = { ContinuousClock.now }

  private(set) var isPaused = false
  private(set) var isActive = false

  private let configuration: Configuration
  /// 轮询循环任务。标记 nonisolated(unsafe) 仅为允许 deinit 兜底取消；
  /// 其余读写都发生在 MainActor 上。
  private nonisolated(unsafe) var task: Task<Void, Never>?
  private var fetch: Fetch?
  private var onUpdate: UpdateHandler?
  private var onFinish: FinishHandler?

  private var currentInterval: Duration
  /// 轮询起始时刻：预算按 `now() - startedAt` 的真实墙钟流逝判断。
  private var startedAt: ContinuousClock.Instant = ContinuousClock.now
  private var consecutiveFailures = 0
  private var lastStatus: String?
  private var lastStageCount: Int?
  private var lastFailureMessage = ""

  init(configuration: Configuration = Configuration()) {
    self.configuration = configuration
    currentInterval = configuration.initialInterval
  }

  deinit {
    // 兜底：持有方释放时取消遗留的轮询任务，避免孤儿循环继续请求。
    task?.cancel()
  }

  func start(fetch: @escaping Fetch, onUpdate: @escaping UpdateHandler, onFinish: @escaping FinishHandler) {
    stop()
    self.fetch = fetch
    self.onUpdate = onUpdate
    self.onFinish = onFinish
    currentInterval = configuration.initialInterval
    startedAt = now()
    consecutiveFailures = 0
    lastStatus = nil
    lastStageCount = nil
    lastFailureMessage = ""
    isPaused = false
    isActive = true
    launchLoop()
  }

  func stop() {
    task?.cancel()
    task = nil
    isActive = false
    isPaused = false
    fetch = nil
    onUpdate = nil
    onFinish = nil
  }

  func pause() {
    guard isActive, !isPaused else { return }
    isPaused = true
    task?.cancel()
    task = nil
  }

  func resume() {
    guard isActive, isPaused else { return }
    isPaused = false
    launchLoop()
  }

  private func launchLoop() {
    task = Task { [weak self] in
      await self?.run()
    }
  }

  private func run() async {
    while isActive, !Task.isCancelled {
      await pollOnce()
      guard isActive, !Task.isCancelled else { return }

      let interval = currentInterval
      if now() - startedAt + interval > configuration.overallBudget {
        finish(.timedOut)
        return
      }
      do {
        try await sleep(interval)
      } catch {
        return
      }
      guard isActive, !Task.isCancelled else { return }
    }
  }

  private func pollOnce() async {
    guard let fetch else { return }
    do {
      let job = try await fetch()
      guard isActive, !Task.isCancelled else { return }
      consecutiveFailures = 0
      let stateChanged = job.status != lastStatus || job.stages.count != lastStageCount
      lastStatus = job.status
      lastStageCount = job.stages.count
      onUpdate?(job)
      if job.statusKind.isTerminal {
        finish(.reachedTerminalStatus)
        return
      }
      currentInterval = stateChanged ? configuration.initialInterval : nextBackoffInterval()
    } catch {
      guard isActive, !Task.isCancelled else { return }
      consecutiveFailures += 1
      lastFailureMessage = formatUserFacingError(error)
      if consecutiveFailures >= configuration.maxConsecutiveFailures {
        finish(.repeatedFailures(message: lastFailureMessage))
        return
      }
      currentInterval = nextBackoffInterval()
    }
  }

  private func nextBackoffInterval() -> Duration {
    min(currentInterval * configuration.backoffMultiplier, configuration.maxInterval)
  }

  private func finish(_ termination: Termination) {
    guard isActive else { return }
    isActive = false
    isPaused = false
    let handler = onFinish
    fetch = nil
    onUpdate = nil
    onFinish = nil
    handler?(termination)
  }
}
