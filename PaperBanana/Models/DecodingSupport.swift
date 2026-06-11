import Foundation

struct DynamicCodingKey: CodingKey {
  let stringValue: String
  let intValue: Int?

  init?(stringValue: String) {
    self.stringValue = stringValue
    intValue = nil
  }

  init?(intValue: Int) {
    stringValue = String(intValue)
    self.intValue = intValue
  }

  static func key(_ value: String) -> DynamicCodingKey {
    DynamicCodingKey(stringValue: value)!
  }
}

extension KeyedDecodingContainer where Key == DynamicCodingKey {
  func string(_ keys: String..., default defaultValue: String = "") -> String {
    for key in keys {
      if let value = try? decodeIfPresent(String.self, forKey: .key(key)) {
        return value
      }
      if let intValue = try? decodeIfPresent(Int.self, forKey: .key(key)) {
        return String(intValue)
      }
    }
    return defaultValue
  }

  func optionalString(_ keys: String...) -> String? {
    for key in keys {
      if let value = try? decodeIfPresent(String.self, forKey: .key(key)) {
        return value
      }
    }
    return nil
  }

  func int(_ keys: String..., default defaultValue: Int = 0) -> Int {
    for key in keys {
      if let value = try? decodeIfPresent(Int.self, forKey: .key(key)) {
        return value
      }
      if let value = try? decodeIfPresent(Double.self, forKey: .key(key)) {
        return Int(value)
      }
      if let value = try? decodeIfPresent(String.self, forKey: .key(key)), let parsed = Int(value) {
        return parsed
      }
    }
    return defaultValue
  }

  func stringArray(_ keys: String...) -> [String] {
    for key in keys {
      if let value = try? decodeIfPresent([String].self, forKey: .key(key)) {
        return value
      }
    }
    return []
  }

  func bool(_ keys: String..., default defaultValue: Bool = false) -> Bool {
    for key in keys {
      if let value = try? decodeIfPresent(Bool.self, forKey: .key(key)) {
        return value
      }
      if let value = try? decodeIfPresent(String.self, forKey: .key(key)) {
        let normalized = value.lowercased()
        if ["true", "1", "yes"].contains(normalized) { return true }
        if ["false", "0", "no"].contains(normalized) { return false }
      }
    }
    return defaultValue
  }

  func decodeArray<T: Decodable>(_ keys: String...) -> [T] {
    for key in keys {
      if let value = try? decodeIfPresent([T].self, forKey: .key(key)) {
        return value
      }
    }
    return []
  }

  func logsString(_ key: String) -> String {
    guard let logs = try? decodeIfPresent([String].self, forKey: .key(key)), !logs.isEmpty else {
      return ""
    }
    let suffix = logs.suffix(10).joined(separator: "\n")
    return suffix.isEmpty ? "" : "\n\(suffix)"
  }
}
