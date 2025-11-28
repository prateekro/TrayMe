//
//  EncryptionService.swift
//  TrayMe
//
//  AES-256-GCM encryption with Keychain storage

import Foundation
import CryptoKit
import Security

/// Encryption errors
enum EncryptionError: Error, LocalizedError {
    case keyGenerationFailed
    case keychainError(OSStatus)
    case encryptionFailed
    case decryptionFailed
    case invalidInput
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed:
            return "Failed to generate encryption key"
        case .keychainError(let status):
            return "Keychain error: \(status)"
        case .encryptionFailed:
            return "Encryption failed"
        case .decryptionFailed:
            return "Decryption failed"
        case .invalidInput:
            return "Invalid input"
        case .invalidData:
            return "Invalid encrypted data"
        }
    }
}

/// AES-256-GCM encryption service with Keychain key storage
class EncryptionService: ObservableObject {
    /// Keychain service identifier
    private let keychainService = "com.trayme.encryption"
    
    /// Keychain account for the encryption key
    private let keychainAccount = "master-key"
    
    /// Cached symmetric key
    private var cachedKey: SymmetricKey?
    
    init() {}
    
    // MARK: - Public API
    
    /// Encrypt data using AES-256-GCM
    /// - Parameter data: Data to encrypt
    /// - Returns: Encrypted data (nonce + ciphertext + tag)
    func encrypt(_ data: Data) throws -> Data {
        let key = try getOrCreateKey()
        
        do {
            let sealed = try AES.GCM.seal(data, using: key)
            
            guard let combined = sealed.combined else {
                throw EncryptionError.encryptionFailed
            }
            
            return combined
        } catch {
            throw EncryptionError.encryptionFailed
        }
    }
    
    /// Decrypt data using AES-256-GCM
    /// - Parameter data: Encrypted data to decrypt
    /// - Returns: Decrypted data
    func decrypt(_ data: Data) throws -> Data {
        let key = try getOrCreateKey()
        
        do {
            let box = try AES.GCM.SealedBox(combined: data)
            let decrypted = try AES.GCM.open(box, using: key)
            return decrypted
        } catch {
            throw EncryptionError.decryptionFailed
        }
    }
    
    /// Encrypt string
    func encryptString(_ string: String) throws -> Data {
        guard let data = string.data(using: .utf8) else {
            throw EncryptionError.invalidInput
        }
        return try encrypt(data)
    }
    
    /// Decrypt to string
    func decryptString(_ data: Data) throws -> String {
        let decrypted = try decrypt(data)
        guard let string = String(data: decrypted, encoding: .utf8) else {
            throw EncryptionError.invalidData
        }
        return string
    }
    
    /// Generate a new encryption key (rotates existing key)
    func rotateKey() throws {
        // Delete existing key
        try deleteKeyFromKeychain()
        cachedKey = nil
        
        // Generate and store new key
        _ = try getOrCreateKey()
    }
    
    /// Check if encryption key exists
    var hasKey: Bool {
        do {
            _ = try loadKeyFromKeychain()
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Key Management
    
    /// Get existing key or create new one
    private func getOrCreateKey() throws -> SymmetricKey {
        // Return cached key if available
        if let cached = cachedKey {
            return cached
        }
        
        // Try to load from Keychain
        do {
            let key = try loadKeyFromKeychain()
            cachedKey = key
            return key
        } catch {
            // Key doesn't exist, create new one
            let key = SymmetricKey(size: .bits256)
            try saveKeyToKeychain(key)
            cachedKey = key
            return key
        }
    }
    
    /// Save key to Keychain
    private func saveKeyToKeychain(_ key: SymmetricKey) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete any existing key first
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            throw EncryptionError.keychainError(status)
        }
    }
    
    /// Load key from Keychain
    private func loadKeyFromKeychain() throws -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecItemNotFound {
            throw EncryptionError.keyGenerationFailed
        }
        
        if status != errSecSuccess {
            throw EncryptionError.keychainError(status)
        }
        
        guard let keyData = result as? Data else {
            throw EncryptionError.keyGenerationFailed
        }
        
        return SymmetricKey(data: keyData)
    }
    
    /// Delete key from Keychain
    private func deleteKeyFromKeychain() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess && status != errSecItemNotFound {
            throw EncryptionError.keychainError(status)
        }
    }
}

// MARK: - Hashing Utilities

extension EncryptionService {
    /// Hash data using SHA-256
    static func sha256(_ data: Data) -> Data {
        let hash = SHA256.hash(data: data)
        return Data(hash)
    }
    
    /// Hash string using SHA-256
    static func sha256(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else {
            return ""
        }
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Generate secure random bytes
    static func randomBytes(count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes)
    }
}
