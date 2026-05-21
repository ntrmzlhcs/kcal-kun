import Foundation
import Security

/// Verwaltet den Google-Gemini-API-Key sicher im iOS Keychain.
/// BYOK-Modell: Jeder User legt seinen eigenen Key an — App-Anbieter sieht ihn nie.
enum APIKeyService {
    private static let service = "com.martin.kcal-kun.gemini"
    private static let account = "gemini-api-key"

    // MARK: - Status

    static var hasKey: Bool { getKey() != nil }

    // MARK: - Read

    static func getKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String:  kSecMatchLimitOne,
            kSecReturnData as String:  true
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else { return nil }
        return key
    }

    // MARK: - Write

    @discardableResult
    static func setKey(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return false }

        let baseQuery: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        // Existing entry entfernen — wir machen immer fresh insert
        SecItemDelete(baseQuery as CFDictionary)

        var newItem = baseQuery
        newItem[kSecValueData as String] = data
        // Verfügbar nach erstem Unlock (auch im Hintergrund) — sinnvoller Default
        newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        return SecItemAdd(newItem as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    static func clearKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Validation

    /// Validiert einen Key mit einem minimalen Gemini-API-Call (List-Models-Endpoint).
    /// Sendet KEINE User-Daten — nur einen leichten Status-Call.
    static func validate(_ key: String) async -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models?key=\(trimmed)"
        guard let url = URL(string: urlString) else { return false }
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    // MARK: - Display

    /// Maskiert einen Key für die UI-Anzeige: „AIza…xY9z"
    static func masked(_ key: String) -> String {
        guard key.count > 8 else { return "•••" }
        let prefix = key.prefix(4)
        let suffix = key.suffix(4)
        return "\(prefix)…\(suffix)"
    }
}
