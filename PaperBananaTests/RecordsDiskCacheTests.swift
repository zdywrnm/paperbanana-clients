import XCTest
@testable import PaperBanana

final class RecordsDiskCacheTests: XCTestCase {
  func testJobCacheEncodingRoundTripsThroughExistingDecoder() throws {
    let job = try JSONDecoder().decode(Job.self, from: Data("""
    {
      "id": "job-cache",
      "status": "succeeded",
      "provider": "bailian",
      "job_type": "generate",
      "configuration_mode": "advanced",
      "method_content": "method",
      "caption": "caption",
      "infographic_category": "方法框架图",
      "output_format": "svg",
      "image_size": "2K",
      "main_model_name": "qwen3.7-max",
      "image_gen_model_name": "wan2.7-image-pro",
      "reference_vision_model_name": "qwen3.7-plus",
      "reference_image_mode": "vision_model",
      "pipeline_mode": "planner_critic",
      "task_name": "plot",
      "retrieval_setting": "manual",
      "retrieved_reference_ids": ["ref-1"],
      "aspect_ratio": "16:9",
      "num_candidates": 2,
      "max_critic_rounds": 1,
      "result_image_count": 1,
      "result_images": [
        {"filename": "out.png", "url": "/signed/out.png", "storage": "bucket", "mime_type": "image/png", "candidate_id": 0, "object_key": "jobs/out.png"}
      ],
      "reference_images": [
        {"filename": "style.png", "mimeType": "image/png", "size": 16, "objectKey": "refs/style.png", "url": "/signed/style.png", "storage": "bucket"}
      ],
      "stages": [
        {"id": "stage-1", "candidate_id": 0, "type": "critic", "title": "评审", "round": 1, "text": "建议", "image": {"filename": "stage.webp", "url": "/signed/stage.webp", "storage": "bucket", "mime_type": "image/webp"}}
      ],
      "logs_tail": "done",
      "error": "",
      "created_at": "2026-06-10T08:00:00Z"
    }
    """.utf8))

    let encoded = try JSONEncoder().encode([job])
    let decoded = try JSONDecoder().decode([Job].self, from: encoded)

    XCTAssertEqual(decoded, [job])
  }

  func testDiskCacheSaveLoadClearCycle() throws {
    let cache = RecordsDiskCache(filename: "user-jobs-test-\(UUID().uuidString).json")
    defer { cache.clear() }

    XCTAssertNil(cache.load())

    let job = try JSONDecoder().decode(Job.self, from: Data(#"{"id": "job-1", "status": "succeeded", "caption": "cached"}"#.utf8))
    cache.save([job])

    let loaded = try XCTUnwrap(cache.load())
    XCTAssertEqual(loaded, [job])

    cache.clear()
    XCTAssertNil(cache.load())
  }
}
