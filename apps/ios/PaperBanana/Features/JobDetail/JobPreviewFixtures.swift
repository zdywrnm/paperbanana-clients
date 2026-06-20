import Foundation

#if DEBUG
/// #Preview 共用的 mock Job 数据（永久资产）：覆盖进行中 / 成功 / 失败 / 排队四种核心状态。
/// 走真实 JSON 解码路径，保证 fixture 与后端契约同步演化。
enum JobPreviewFixtures {
  /// 内嵌小尺寸棋盘格 PNG，AsyncImage 可直接加载 data: URL，预览不依赖网络。
  static let sampleImageDataURL = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAGAAAABACAIAAABqVuVZAAAAhUlEQVR42u3asQkAIAwEwIzl4q5k7QCCmSGl8eDrh1z5JNYcpdyzS3m9PwABAgQIECBAgAABAgQIECBAgJoB/XZwtR8QIECAAAECBAgQIECAAAECBKgbkMHMoggIECBAgAABAgQIECBAgAAB8h9kMLMoAgIECBAgQIAAAQIECBAgQIDaAiWf4utJtaMt0AAAAABJRU5ErkJggg=="

  /// 进行中：3 个 stage，评审第 2 轮（流水线 active 在评审节点）。
  static let running = decode(
    """
    {
      "id": "job-preview-running",
      "status": "running",
      "provider": "bailian",
      "task_name": "diagram",
      "configuration_mode": "advanced",
      "method_content": "我们提出一种两阶段方法：先用对比学习预训练编码器，再用门控融合模块对多模态特征加权聚合，最后接轻量解码器输出结构化预测。",
      "caption": "两阶段多模态融合框架总览",
      "infographic_category": "方法框架图",
      "output_format": "png",
      "image_size": "2K",
      "main_model_name": "qwen3-max",
      "image_gen_model_name": "wan2.5-t2i-preview",
      "aspect_ratio": "16:9",
      "num_candidates": 2,
      "max_critic_rounds": 2,
      "critic_mode": "image",
      "created_at": "2026-06-11T09:30:00Z",
      "stages": [
        {"id": "s-planner", "candidate_id": 0, "type": "planner", "title": "规划", "round": 0, "text": "已把方法内容拆解为 4 个模块：编码器、门控融合、解码器与损失设计，并确定从左到右的主流程布局。"},
        {"id": "s-render", "candidate_id": 0, "type": "render", "title": "初次渲染", "round": 0, "text": "按规划生成第一版候选图。", "image": {"filename": "stage-render.png", "url": "\(sampleImageDataURL)", "mime_type": "image/png"}},
        {"id": "s-critic", "candidate_id": 0, "type": "critic", "title": "图像评审（第2轮）", "round": 2, "text": "模块连线方向不一致，门控融合的输入箭头缺失。", "suggestion": "统一连线方向为从左至右，补齐门控融合模块的两条输入箭头，并加大模块标题字号。"}
      ]
    }
    """
  )

  /// 精修放大中：后端从不发 `refine` 类型，精修放大阶段记录为 `type:'render'` +
  /// 标题「精修放大（…）」（laf-functions enhanceCandidateToResolution），流水线 active 在精修节点。
  static let refining = decode(
    """
    {
      "id": "job-preview-refining",
      "status": "running",
      "provider": "bailian",
      "task_name": "diagram",
      "configuration_mode": "advanced",
      "method_content": "我们提出一种两阶段方法：先用对比学习预训练编码器，再用门控融合模块对多模态特征加权聚合，最后接轻量解码器输出结构化预测。",
      "caption": "两阶段多模态融合框架总览",
      "infographic_category": "方法框架图",
      "output_format": "png",
      "image_size": "2K",
      "main_model_name": "qwen3-max",
      "image_gen_model_name": "wan2.5-t2i-preview",
      "aspect_ratio": "16:9",
      "num_candidates": 1,
      "max_critic_rounds": 1,
      "critic_mode": "image",
      "created_at": "2026-06-11T09:40:00Z",
      "stages": [
        {"id": "s-planner", "candidate_id": 0, "type": "planner", "title": "规划", "round": 0, "text": "拆解为 4 个模块并确定布局。"},
        {"id": "s-render", "candidate_id": 0, "type": "render", "title": "初次渲染", "round": 0, "image": {"filename": "stage-render.png", "url": "\(sampleImageDataURL)", "mime_type": "image/png"}},
        {"id": "s-critic", "candidate_id": 0, "type": "critic", "title": "图像评审（第1轮）", "round": 1, "text": "整体结构清晰。", "suggestion": ""},
        {"id": "s-enhance", "candidate_id": 0, "type": "render", "title": "精修放大（2K）", "round": 0, "text": "Auto-enhance pass to reach 2K resolution."}
      ]
    }
    """
  )

  /// 已完成：带 2 张结果图。
  static let succeeded = decode(
    """
    {
      "id": "job-preview-succeeded",
      "status": "succeeded",
      "provider": "bailian",
      "task_name": "diagram",
      "configuration_mode": "advanced",
      "method_content": "我们提出一种两阶段方法：先用对比学习预训练编码器，再用门控融合模块对多模态特征加权聚合，最后接轻量解码器输出结构化预测。",
      "caption": "两阶段多模态融合框架总览",
      "infographic_category": "方法框架图",
      "output_format": "png",
      "image_size": "2K",
      "main_model_name": "qwen3-max",
      "image_gen_model_name": "wan2.5-t2i-preview",
      "aspect_ratio": "16:9",
      "num_candidates": 2,
      "max_critic_rounds": 1,
      "critic_mode": "image",
      "created_at": "2026-06-11T08:12:00Z",
      "completed_at": "2026-06-11T08:19:42Z",
      "stages": [
        {"id": "s-planner", "candidate_id": 0, "type": "planner", "title": "规划", "round": 0, "text": "拆解为 4 个模块并确定布局。"},
        {"id": "s-stylist", "candidate_id": 0, "type": "stylist", "title": "风格", "round": 0, "text": "统一为期刊蓝灰配色，模块圆角矩形。"},
        {"id": "s-render", "candidate_id": 0, "type": "render", "title": "初次渲染", "round": 0, "image": {"filename": "stage-render.png", "url": "\(sampleImageDataURL)", "mime_type": "image/png"}},
        {"id": "s-critic", "candidate_id": 0, "type": "critic", "title": "图像评审（第1轮）", "round": 1, "text": "整体结构清晰，文字层级合理。", "suggestion": "无需进一步修改。"},
        {"id": "s-enhance", "candidate_id": 0, "type": "render", "title": "精修放大（2K）", "round": 0, "image": {"filename": "stage-refine.png", "url": "\(sampleImageDataURL)", "mime_type": "image/png"}}
      ],
      "result_images": [
        {"filename": "candidate-1.png", "url": "\(sampleImageDataURL)", "mime_type": "image/png", "candidate_id": 0},
        {"filename": "candidate-2.png", "url": "\(sampleImageDataURL)", "mime_type": "image/png", "candidate_id": 1}
      ]
    }
    """
  )

  /// 失败：渲染阶段失败，带错误与日志尾巴。
  static let failed = decode(
    """
    {
      "id": "job-preview-failed",
      "status": "failed",
      "provider": "openrouter",
      "task_name": "diagram",
      "configuration_mode": "simple",
      "method_content": "我们提出一种两阶段方法：先用对比学习预训练编码器，再用门控融合模块对多模态特征加权聚合。",
      "caption": "两阶段多模态融合框架总览",
      "output_format": "png",
      "image_size": "1K",
      "created_at": "2026-06-11T07:02:00Z",
      "error": "image model rejected the request: content filter triggered",
      "logs_tail": "[planner] plan ok, 4 modules\\n[renderer] submitting prompt to image model\\n[renderer] ERROR 422: content filter triggered\\n[worker] job marked failed",
      "stages": [
        {"id": "s-planner", "candidate_id": 0, "type": "planner", "title": "规划", "round": 0, "text": "拆解为 4 个模块并确定布局。"},
        {"id": "s-render", "candidate_id": 0, "type": "render", "title": "初次渲染", "round": 0, "error": "渲染失败"}
      ]
    }
    """
  )

  /// 刚排队：无 stages。
  static let queued = decode(
    """
    {
      "id": "job-preview-queued",
      "status": "queued",
      "task_name": "diagram",
      "caption": "两阶段多模态融合框架总览",
      "created_at": "2026-06-11T09:55:00Z"
    }
    """
  )

  private static func decode(_ json: String) -> Job {
    guard
      let data = json.data(using: .utf8),
      let job = try? JSONDecoder().decode(Job.self, from: data)
    else {
      // fixture JSON 写错时立刻在预览/调试期暴露，而不是静默给空数据。
      preconditionFailure("JobPreviewFixtures JSON 无法解码")
    }
    return job
  }
}
#endif
