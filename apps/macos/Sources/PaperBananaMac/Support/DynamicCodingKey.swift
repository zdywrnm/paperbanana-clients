import Foundation

struct DynamicCodingKey: CodingKey {
  let stringValue: String
  let intValue: Int?

  init?(stringValue: String) {
    self.stringValue = stringValue
    intValue = nil
  }

  init?(intValue: Int) {
    self.stringValue = "\(intValue)"
    self.intValue = intValue
  }
}

extension KeyedDecodingContainer where Key == DynamicCodingKey {
  func string(_ keys: String...) -> String {
    for key in keys {
      guard let codingKey = DynamicCodingKey(stringValue: key) else { continue }
      if let value = try? decodeIfPresent(String.self, forKey: codingKey) {
        return value
      }
      if let value = try? decodeIfPresent(Int.self, forKey: codingKey) {
        return String(value)
      }
      if let value = try? decodeIfPresent(Double.self, forKey: codingKey) {
        return String(value)
      }
    }
    return ""
  }

  func int(_ keys: String...) -> Int {
    for key in keys {
      guard let codingKey = DynamicCodingKey(stringValue: key) else { continue }
      if let value = try? decodeIfPresent(Int.self, forKey: codingKey) {
        return value
      }
      if let value = try? decodeIfPresent(String.self, forKey: codingKey), let parsed = Int(value) {
        return parsed
      }
    }
    return 0
  }

  func bool(_ keys: String...) -> Bool {
    for key in keys {
      guard let codingKey = DynamicCodingKey(stringValue: key) else { continue }
      if let value = try? decodeIfPresent(Bool.self, forKey: codingKey) {
        return value
      }
    }
    return false
  }

  func decodeArray<T: Decodable>(_ keys: String...) -> [T] {
    for key in keys {
      guard let codingKey = DynamicCodingKey(stringValue: key) else { continue }
      if let value = try? decodeIfPresent([T].self, forKey: codingKey) {
        return value
      }
    }
    return []
  }

  func logsString(_ key: String) -> String {
    guard let codingKey = DynamicCodingKey(stringValue: key) else { return "" }
    if let value = try? decodeIfPresent([String].self, forKey: codingKey) {
      return value.suffix(10).joined(separator: "\n")
    }
    return ""
  }
}
