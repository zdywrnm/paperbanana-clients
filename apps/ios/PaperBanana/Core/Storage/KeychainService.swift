import Foundation
import Security

enum KeychainError: LocalizedError {
  case readFailed(OSStatus)
  case saveFailed(OSStatus)
  case deleteFailed(OSStatus)

  var errorDescription: String? {
    switch self {
    case .readFailed(let status): "Keychain 读取失败：\(status)"
    case .saveFailed(let status): "Keychain 保存失败：\(status)"
    case .deleteFailed(let status): "Keychain 删除失败：\(status)"
    }
  }
}

final class KeychainService {
  private let service = "asia.paperbanana.ios"

  func string(for account: String) throws -> String? {
    var query = baseQuery(account: account)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess else { throw KeychainError.readFailed(status) }
    guard let data = result as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }

  func set(_ value: String, for account: String) throws {
    try delete(account: account)
    var query = baseQuery(account: account)
    query[kSecValueData as String] = Data(value.utf8)
    query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else { throw KeychainError.saveFailed(status) }
  }

  func delete(account: String) throws {
    let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw KeychainError.deleteFailed(status)
    }
  }

  private func baseQuery(account: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account
    ]
  }
}
