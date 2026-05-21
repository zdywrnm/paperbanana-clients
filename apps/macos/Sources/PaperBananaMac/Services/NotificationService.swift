import Foundation
import UserNotifications

final class NotificationService {
  func requestAuthorization() async {
    _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
  }

  func notifyJobFinished(job: Job) async {
    let content = UNMutableNotificationContent()
    content.title = "PaperBanana"
    content.body = job.statusKind == .succeeded ? "候选图已生成完成。" : "任务生成失败。"
    content.sound = .default
    let request = UNNotificationRequest(
      identifier: "paperbanana-job-\(job.id)",
      content: content,
      trigger: nil
    )
    try? await UNUserNotificationCenter.current().add(request)
  }
}
