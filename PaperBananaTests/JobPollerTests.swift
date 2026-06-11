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
    poller.sleep = { sleeps.append($0) }

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

  // MARK: - Helpers

  private static func job(status: String, stageCount: Int = 0) throws -> Job {
    let stages = (0..<stageCount)
      .map { #"{"id": "stage-\#($0)", "type": "renderer"}"# }
      .joined(separator: ",")
    let json = #"{"id": "job-1", "status": "\#(status)", "stages": [\#(stages)]}"#
    return try JSONDecoder().decode(Job.self, from: Data(json.utf8))
  }
}
