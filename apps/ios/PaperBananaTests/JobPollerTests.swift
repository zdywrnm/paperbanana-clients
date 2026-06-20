import XCTest
@testable import PaperBanana

@MainActor
final class JobPollerTests: XCTestCase {
  func testBackoffGrowsByHalfAndCapsAtFifteenSeconds() async throws {
    let poller = JobPoller()
    var sleeps: [Duration] = []
    poller.sleep = { sleeps.append($0) }

    var fetchCount = 0
    var termination: JobPoller.Termination?
    let finished = expectation(description: "poller finished")
    poller.start(
      fetch: {
        fetchCount += 1
        return try Self.job(status: fetchCount >= 9 ? "succeeded" : "running")
      },
      onUpdate: { _ in },
      onFinish: { result in
        termination = result
        finished.fulfill()
      }
    )

    await fulfillment(of: [finished], timeout: 5)

    XCTAssertEqual(termination, .reachedTerminalStatus)
    XCTAssertEqual(fetchCount, 9)
    XCTAssertEqual(
      sleeps,
      [.seconds(2), .seconds(3), .seconds(4.5), .seconds(6.75), .seconds(10.125), .seconds(15), .seconds(15), .seconds(15)]
    )
  }

  func testStatusChangeResetsBackoffInterval() async throws {
    let poller = JobPoller()
    var sleeps: [Duration] = []
    poller.sleep = { sleeps.append($0) }

    let statuses = ["queued", "queued", "running", "running", "succeeded"]
    var fetchCount = 0
    var observedStatuses: [String] = []
    let finished = expectation(description: "poller finished")
    poller.start(
      fetch: {
        defer { fetchCount += 1 }
        return try Self.job(status: statuses[fetchCount])
      },
      onUpdate: { observedStatuses.append($0.status) },
      onFinish: { _ in finished.fulfill() }
    )

    await fulfillment(of: [finished], timeout: 5)

    XCTAssertEqual(observedStatuses, statuses)
    XCTAssertEqual(sleeps, [.seconds(2), .seconds(3), .seconds(2), .seconds(3)])
  }

  func testStageCountChangeResetsBackoffInterval() async throws {
    let poller = JobPoller()
    var sleeps: [Duration] = []
    poller.sleep = { sleeps.append($0) }

    let polls: [(status: String, stageCount: Int)] = [
      ("running", 0), ("running", 1), ("running", 1), ("succeeded", 1)
    ]
    var fetchCount = 0
    let finished = expectation(description: "poller finished")
    poller.start(
      fetch: {
        defer { fetchCount += 1 }
        let poll = polls[fetchCount]
        return try Self.job(status: poll.status, stageCount: poll.stageCount)
      },
      onUpdate: { _ in },
      onFinish: { _ in finished.fulfill() }
    )

    await fulfillment(of: [finished], timeout: 5)

    XCTAssertEqual(sleeps, [.seconds(2), .seconds(2), .seconds(3)])
  }

  func testSingleFailureDoesNotStopPolling() async throws {
    let poller = JobPoller()
    var sleeps: [Duration] = []
    poller.sleep = { sleeps.append($0) }

    var fetchCount = 0
    var termination: JobPoller.Termination?
    let finished = expectation(description: "poller finished")
    poller.start(
      fetch: {
        fetchCount += 1
        if fetchCount == 2 { throw URLError(.networkConnectionLost) }
        return try Self.job(status: fetchCount >= 4 ? "succeeded" : "running")
      },
      onUpdate: { _ in },
      onFinish: { result in
        termination = result
        finished.fulfill()
      }
    )

    await fulfillment(of: [finished], timeout: 5)

    XCTAssertEqual(termination, .reachedTerminalStatus)
    XCTAssertEqual(fetchCount, 4)
    XCTAssertEqual(sleeps, [.seconds(2), .seconds(3), .seconds(4.5)])
  }

  func testFiveConsecutiveFailuresStopPollingWithStructuredError() async throws {
    let poller = JobPoller()
    var sleeps: [Duration] = []
    poller.sleep = { sleeps.append($0) }

    var fetchCount = 0
    var termination: JobPoller.Termination?
    let finished = expectation(description: "poller finished")
    poller.start(
      fetch: {
        fetchCount += 1
        throw PaperBananaAPIError.server("Backend is unavailable")
      },
      onUpdate: { _ in },
      onFinish: { result in
        termination = result
        finished.fulfill()
      }
    )

    await fulfillment(of: [finished], timeout: 5)

    XCTAssertEqual(termination, .repeatedFailures(message: "Backend is unavailable"))
    XCTAssertEqual(fetchCount, 5)
    XCTAssertEqual(sleeps.count, 4)
  }

  func testFailureCounterResetsAfterSuccessfulPoll() async throws {
    let poller = JobPoller()
    poller.sleep = { _ in }

    var fetchCount = 0
    var termination: JobPoller.Termination?
    let finished = expectation(description: "poller finished")
    poller.start(
      fetch: {
        fetchCount += 1
        switch fetchCount {
        case 1...4, 6...9: throw URLError(.timedOut)
        case 5: return try Self.job(status: "running")
        default: return try Self.job(status: "succeeded")
        }
      },
      onUpdate: { _ in },
      onFinish: { result in
        termination = result
        finished.fulfill()
      }
    )

    await fulfillment(of: [finished], timeout: 5)

    XCTAssertEqual(termination, .reachedTerminalStatus)
    XCTAssertEqual(fetchCount, 10)
  }

  func testTerminalStatusStopsImmediately() async throws {
    let poller = JobPoller()
    var sleeps: [Duration] = []
    poller.sleep = { sleeps.append($0) }

    var fetchCount = 0
    var termination: JobPoller.Termination?
    let finished = expectation(description: "poller finished")
    poller.start(
      fetch: {
        fetchCount += 1
        return try Self.job(status: "failed")
      },
      onUpdate: { _ in },
      onFinish: { result in
        termination = result
        finished.fulfill()
      }
    )

    await fulfillment(of: [finished], timeout: 5)

    XCTAssertEqual(termination, .reachedTerminalStatus)
    XCTAssertEqual(fetchCount, 1)
    XCTAssertEqual(sleeps, [])
  }

  func testPollingTimesOutAfterOverallBudget() async throws {
    let poller = JobPoller()
    var sleeps: [Duration] = []
    // 预算按 now() 墙钟流逝判断；fake sleep 不真等待，所以注入手动推进的时钟，
    // 在 fake sleep 里把 sleep 时长同步推进到 now() 上。
    let base = ContinuousClock.now
    var simulatedElapsed = Duration.zero
    poller.now = { base + simulatedElapsed }
    poller.sleep = {
      sleeps.append($0)
      simulatedElapsed += $0
    }

    var termination: JobPoller.Termination?
    let finished = expectation(description: "poller finished")
    poller.start(
      fetch: { try Self.job(status: "running") },
      onUpdate: { _ in },
      onFinish: { result in
        termination = result
        finished.fulfill()
      }
    )

    await fulfillment(of: [finished], timeout: 5)

    XCTAssertEqual(termination, .timedOut)
    let totalSlept = sleeps.reduce(Duration.zero, +)
    XCTAssertLessThanOrEqual(totalSlept, .seconds(600))
    XCTAssertGreaterThan(totalSlept, .seconds(580))
    XCTAssertEqual(sleeps.max(), .seconds(15))
  }

  func testPauseStopsPollingAndResumeRefreshesImmediately() async throws {
    let poller = JobPoller()
    var sleeps: [Duration] = []
    poller.sleep = { sleeps.append($0) }

    var fetchCount = 0
    var termination: JobPoller.Termination?
    let finished = expectation(description: "poller finished")
    poller.start(
      fetch: {
        fetchCount += 1
        if fetchCount == 3 { poller.pause() }
        return try Self.job(status: fetchCount >= 5 ? "succeeded" : "running")
      },
      onUpdate: { _ in },
      onFinish: { result in
        termination = result
        finished.fulfill()
      }
    )

    var spins = 0
    while fetchCount < 3 && spins < 10_000 {
      await Task.yield()
      spins += 1
    }
    // 注意：固定次数 yield 自旋隐式依赖上面的 fake sleep「不挂起、立即返回」；
    // 若 fake 会真正挂起，这里需要换成事件驱动的等待（见下方取消语义测试的写法）。
    for _ in 0..<50 { await Task.yield() }

    XCTAssertEqual(fetchCount, 3, "暂停后不应再有请求")
    XCTAssertTrue(poller.isPaused)
    XCTAssertNil(termination)

    poller.resume()
    await fulfillment(of: [finished], timeout: 5)

    XCTAssertEqual(termination, .reachedTerminalStatus)
    XCTAssertEqual(fetchCount, 5)
    XCTAssertEqual(sleeps, [.seconds(2), .seconds(3), .seconds(4.5)])
  }

  // MARK: - 取消语义（生产路径：任务挂起在 Task.sleep 时被取消，抛 CancellationError 退出）

  func testPauseWhileSuspendedInSleepCancelsAndResumeRecovers() async throws {
    let poller = JobPoller()
    var sleepEntries = 0
    // 取消感知 fake sleep：挂起（自旋 yield）直到所在任务被取消，
    // 然后像真实 Task.sleep 一样抛出 CancellationError。
    poller.sleep = { _ in
      sleepEntries += 1
      while true {
        try Task.checkCancellation()
        await Task.yield()
      }
    }

    var fetchCount = 0
    var termination: JobPoller.Termination?
    let finished = expectation(description: "poller finished")
    poller.start(
      fetch: {
        fetchCount += 1
        return try Self.job(status: fetchCount >= 2 ? "succeeded" : "running")
      },
      onUpdate: { _ in },
      onFinish: { result in
        termination = result
        finished.fulfill()
      }
    )

    var spins = 0
    while sleepEntries < 1 && spins < 10_000 {
      await Task.yield()
      spins += 1
    }
    XCTAssertEqual(sleepEntries, 1, "轮询应已挂起在 sleep 中")

    poller.pause()
    // 给被取消的 sleep 留出抛 CancellationError 并退出循环的机会。
    for _ in 0..<50 { await Task.yield() }

    XCTAssertEqual(fetchCount, 1, "CancellationError 退出后不应有多余请求")
    XCTAssertTrue(poller.isPaused)
    XCTAssertTrue(poller.isActive)
    XCTAssertNil(termination)

    poller.resume()
    await fulfillment(of: [finished], timeout: 5)

    XCTAssertEqual(termination, .reachedTerminalStatus)
    XCTAssertEqual(fetchCount, 2, "resume 应立即刷新一次并到达 terminal")
  }

  func testRapidPauseResumePauseDoesNotStackPollingLoops() async throws {
    let poller = JobPoller()
    var sleepEntries = 0
    poller.sleep = { _ in
      sleepEntries += 1
      while true {
        try Task.checkCancellation()
        await Task.yield()
      }
    }

    var fetchCount = 0
    var terminations: [JobPoller.Termination] = []
    let finished = expectation(description: "poller finished")
    poller.start(
      fetch: {
        fetchCount += 1
        return try Self.job(status: fetchCount >= 2 ? "succeeded" : "running")
      },
      onUpdate: { _ in },
      onFinish: { result in
        terminations.append(result)
        finished.fulfill()
      }
    )

    var spins = 0
    while sleepEntries < 1 && spins < 10_000 {
      await Task.yield()
      spins += 1
    }

    // 同步连续 pause-resume-pause：第二个 pause 必须在 resume 起的新循环开跑前取消它。
    poller.pause()
    poller.resume()
    poller.pause()
    for _ in 0..<50 { await Task.yield() }

    XCTAssertEqual(fetchCount, 1, "pause-resume-pause 期间不应产生新请求")
    XCTAssertTrue(poller.isPaused)

    poller.resume()
    await fulfillment(of: [finished], timeout: 5)

    // 若产生了双循环，onFinish 会触发两次（expectation 过度 fulfill 失败）且请求数翻倍。
    XCTAssertEqual(terminations, [.reachedTerminalStatus])
    XCTAssertEqual(fetchCount, 2, "恢复后只应有单个轮询循环在请求")
  }

  func testStopWhileFetchInFlightDiscardsStaleResult() async throws {
    let poller = JobPoller()
    poller.sleep = { _ in }

    var fetchStarted = false
    let releaseFetch = Gate()
    var updates: [Job] = []
    var termination: JobPoller.Termination?
    poller.start(
      fetch: {
        fetchStarted = true
        // 挂起直到测试放行；不感知取消，模拟「已在途的网络请求最终正常返回」。
        var waits = 0
        while !releaseFetch.isOpen && waits < 100_000 {
          await Task.yield()
          waits += 1
        }
        return try Self.job(status: "succeeded")
      },
      onUpdate: { updates.append($0) },
      onFinish: { termination = $0 }
    )

    var spins = 0
    while !fetchStarted && spins < 10_000 {
      await Task.yield()
      spins += 1
    }
    XCTAssertTrue(fetchStarted)

    poller.stop()
    releaseFetch.isOpen = true
    for _ in 0..<100 { await Task.yield() }

    XCTAssertTrue(updates.isEmpty, "stop() 后在途 fetch 的旧结果应被取消 guard 丢弃")
    XCTAssertNil(termination, "stop() 不应触发 onFinish")
    XCTAssertFalse(poller.isActive)
  }

  func testRestartWhileRunningReplacesLoopWithoutStacking() async throws {
    let poller = JobPoller()
    var sleepEntries = 0
    let releaseSleeps = Gate()
    // 取消感知 + 可放行：旧循环靠取消退出，新循环靠放行继续。
    poller.sleep = { _ in
      sleepEntries += 1
      while !releaseSleeps.isOpen {
        try Task.checkCancellation()
        await Task.yield()
      }
    }

    var fetchCount = 0
    var terminations: [JobPoller.Termination] = []
    let finished = expectation(description: "second poll loop finished")
    let fetch: JobPoller.Fetch = {
      fetchCount += 1
      return try Self.job(status: fetchCount >= 3 ? "succeeded" : "running")
    }
    let onFinish: JobPoller.FinishHandler = { result in
      terminations.append(result)
      finished.fulfill()
    }

    poller.start(fetch: fetch, onUpdate: { _ in }, onFinish: onFinish)

    var spins = 0
    while sleepEntries < 1 && spins < 10_000 {
      await Task.yield()
      spins += 1
    }
    XCTAssertEqual(fetchCount, 1)

    // 轮询运行中重复 start()：应先取消旧循环再起新循环，而不是叠加。
    poller.start(fetch: fetch, onUpdate: { _ in }, onFinish: onFinish)

    spins = 0
    while sleepEntries < 2 && spins < 10_000 {
      await Task.yield()
      spins += 1
    }
    XCTAssertEqual(fetchCount, 2, "重复 start 后只应有新循环的一次立即请求")

    releaseSleeps.isOpen = true
    await fulfillment(of: [finished], timeout: 5)

    // 若旧循环未被取消，放行 sleep 后它也会醒来请求，fetchCount 会超过 3
    // 且 onFinish 触发两次（expectation 过度 fulfill 失败）。
    XCTAssertEqual(terminations, [.reachedTerminalStatus])
    XCTAssertEqual(fetchCount, 3)
    for _ in 0..<100 { await Task.yield() }
    XCTAssertEqual(fetchCount, 3, "放行后不应再出现旧循环的请求")
  }

  // MARK: - Helpers

  /// MainActor 上的可变布尔盒子：测试放行闭包用，
  /// 避免「sendable 闭包捕获 var 后又在外部修改」的编译告警。
  @MainActor
  private final class Gate {
    var isOpen = false
  }

  private static func job(status: String, stageCount: Int = 0) throws -> Job {
    let stages = (0..<stageCount)
      .map { #"{"id": "stage-\#($0)", "type": "renderer"}"# }
      .joined(separator: ",")
    let json = #"{"id": "job-1", "status": "\#(status)", "stages": [\#(stages)]}"#
    return try JSONDecoder().decode(Job.self, from: Data(json.utf8))
  }
}
