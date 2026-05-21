import Foundation
import Security

enum KeychainError: LocalizedError {
  case unhandled(OSStatus)

  var errorDescription: String? {
    switch self {
    case .unhandled(let status): "Keychain 操作失败：\(status)"
    }
  }
}

final class KeychainService {
  private let service = "asia.paperbanana.mac.api-key"

  func string(for account: String) throws -> String {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne
    ]

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecItemNotFound { return "" }
    guard status == errSecSuccess else { throw KeychainError.unhandled(status) }
    guard let data = item as? Data else { return "" }
    return String(data: data, encoding: .utf8) ?? ""
  }

  func set(_ value: String, for account: String) throws {
    if value.isEmpty {
      try remove(account: account)
      return
    }

    let data = Data(value.utf8)
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account
    ]
    let attributes: [String: Any] = [
      kSecValueData as String: data
    ]

    let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    if updateStatus == errSecSuccess { return }
    if updateStatus != errSecItemNotFound { throw KeychainError.unhandled(updateStatus) }

    var addQuery = query
    addQuery[kSecValueData as String] = data
    addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
    let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
    guard addStatus == errSecSuccess else { throw KeychainError.unhandled(addStatus) }
  }

  func remove(account: String) throws {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account
    ]
    let status = SecItemDelete(query as CFDictionary)
    if status == errSecSuccess || status == errSecItemNotFound { return }
    throw KeychainError.unhandled(status)
  }
}
