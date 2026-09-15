import Intents
import UIKit
import UserNotifications

final class NotificationService: UNNotificationServiceExtension {
  private let lock = NSLock()
  private var contentHandler: ((UNNotificationContent) -> Void)?
  private var original: UNNotificationContent?
  private var avatarTask: URLSessionDataTask?

  private static let session: URLSession = {
    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = 8
    config.timeoutIntervalForResource = 12
    return URLSession(configuration: config)
  }()

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    lock.lock()
    self.contentHandler = contentHandler
    original = request.content
    lock.unlock()

    let content = request.content
    let info = content.userInfo
    guard value(info, "type") == "message", let senderId = value(info, "sender_id") else {
      deliver(content)
      return
    }

    loadAvatar(value(info, "sender_avatar")) { [weak self] avatar in
      self?.present(content, senderId: senderId, avatar: avatar)
    }
  }

  override func serviceExtensionTimeWillExpire() {
    lock.lock()
    let task = avatarTask
    let fallback = original
    lock.unlock()
    task?.cancel()
    if let fallback = fallback { deliver(fallback) }
  }

  private func present(_ content: UNNotificationContent, senderId: String, avatar: Data?) {
    let info = content.userInfo
    let senderName = value(info, "sender_name") ?? content.title
    let isGroup = value(info, "room_type") == "group"

    let sender = INPerson(
      personHandle: INPersonHandle(value: senderId, type: .unknown),
      nameComponents: nil,
      displayName: senderName,
      image: avatar.map { INImage(imageData: $0) },
      contactIdentifier: nil,
      customIdentifier: senderId
    )

    var recipients: [INPerson]?
    var groupName: INSpeakableString?
    if isGroup {
      let me = INPerson(
        personHandle: INPersonHandle(value: "me", type: .unknown),
        nameComponents: nil,
        displayName: nil,
        image: nil,
        contactIdentifier: nil,
        customIdentifier: nil,
        isMe: true
      )
      recipients = [me, sender]
      groupName = INSpeakableString(spokenPhrase: value(info, "room_title") ?? content.title)
    }

    let intent = INSendMessageIntent(
      recipients: recipients,
      outgoingMessageType: .outgoingMessageText,
      content: content.body,
      speakableGroupName: groupName,
      conversationIdentifier: value(info, "thread_id") ?? content.threadIdentifier,
      serviceName: nil,
      sender: sender,
      attachments: nil
    )

    let interaction = INInteraction(intent: intent, response: nil)
    interaction.direction = .incoming
    interaction.donate { [weak self] _ in
      guard let self = self else { return }
      do {
        let updated = try self.stripSenderPrefix(content, senderName: senderName, isGroup: isGroup)
          .updating(from: intent)
        self.deliver(updated)
      } catch {
        self.deliver(content)
      }
    }
  }

  // 群組通知的 body 由伺服器組成「發送者：預覽」，系統改以溝通通知呈現時會另外顯示發送者名稱，不去掉會重複。
  private func stripSenderPrefix(_ content: UNNotificationContent, senderName: String, isGroup: Bool) -> UNNotificationContent {
    let prefix = senderName + "："
    guard isGroup, content.body.hasPrefix(prefix),
          let copy = content.mutableCopy() as? UNMutableNotificationContent else { return content }
    copy.body = String(content.body.dropFirst(prefix.count))
    return copy
  }

  private func loadAvatar(_ urlString: String?, completion: @escaping (Data?) -> Void) {
    guard let urlString = urlString, let url = URL(string: urlString),
          url.scheme == "https" || url.scheme == "http" else {
      completion(nil)
      return
    }
    let task = NotificationService.session.dataTask(with: url) { data, response, _ in
      let status = (response as? HTTPURLResponse)?.statusCode ?? 0
      guard (200..<300).contains(status), let data = data, data.count < 5_000_000,
            UIImage(data: data) != nil else {
        completion(nil)
        return
      }
      completion(data)
    }
    lock.lock()
    avatarTask = task
    lock.unlock()
    task.resume()
  }

  private func deliver(_ content: UNNotificationContent) {
    lock.lock()
    let handler = contentHandler
    contentHandler = nil
    lock.unlock()
    handler?(content)
  }

  private func value(_ info: [AnyHashable: Any], _ key: String) -> String? {
    guard let raw = info[key] as? String else { return nil }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
