//
//  SecurityManager.swift
//  TrayMe
//
//  Main security manager with biometric authentication and auto-lock

import Foundation
import LocalAuthentication
import AppKit
import Combine

/// Security manager for authentication and sensitive data protection
@MainActor
class SecurityManager: ObservableObject {
    /// Shared instance
    static let shared = SecurityManager()
    
    /// Whether the app is currently unlocked
    @Published var isUnlocked: Bool = true
    
    /// Whether sensitive items are locked
    @Published var sensitiveItemsLocked: Bool = true
    
    /// Last activity time for auto-lock
    @Published var lastActivityTime: Date = Date()
    
    /// Authentication service
    let biometricAuth = BiometricAuth()
    
    /// Encryption service
    let encryptionService = EncryptionService()
    
    /// Sensitive data detector
    let sensitiveDataDetector = SensitiveDataDetector()
    
    /// Auto-lock timer
    private var autoLockTimer: Timer?
    
    /// Auto-lock interval in minutes (0 = disabled)
    @Published var autoLockMinutes: Int = 5 {
        didSet {
            UserDefaults.standard.set(autoLockMinutes, forKey: "SecurityManager.autoLockMinutes")
            setupAutoLockTimer()
        }
    }
    
    /// Require authentication for sensitive clips
    @Published var requireAuthForSensitive: Bool = true {
        didSet {
            UserDefaults.standard.set(requireAuthForSensitive, forKey: "SecurityManager.requireAuthForSensitive")
        }
    }
    
    /// Workspace notification observer
    private var sleepObserver: Any?
    private var screenLockObserver: Any?
    
    private init() {
        loadSettings()
        setupNotifications()
        setupAutoLockTimer()
    }
    
    // MARK: - Authentication
    
    /// Authenticate user with biometrics or password
    /// - Parameter reason: Reason shown to user
    /// - Returns: Whether authentication succeeded
    func authenticate(reason: String = "Unlock TrayMe") async -> Bool {
        let success = await biometricAuth.authenticate(reason: reason)
        
        if success {
            isUnlocked = true
            sensitiveItemsLocked = false
            updateLastActivity()
        }
        
        // Log authentication attempt
        await logAccessAttempt(success: success)
        
        return success
    }
    
    /// Authenticate specifically for sensitive content
    func authenticateForSensitiveContent() async -> Bool {
        guard requireAuthForSensitive && sensitiveItemsLocked else {
            return true
        }
        
        return await authenticate(reason: "View sensitive content")
    }
    
    /// Lock the app
    func lock() {
        isUnlocked = false
        sensitiveItemsLocked = true
    }
    
    /// Lock only sensitive items
    func lockSensitiveItems() {
        sensitiveItemsLocked = true
    }
    
    /// Update last activity time
    func updateLastActivity() {
        lastActivityTime = Date()
    }
    
    // MARK: - Sensitive Data Detection
    
    /// Detect if content contains sensitive data
    func detectSensitiveContent(_ text: String) -> SensitiveDataType? {
        sensitiveDataDetector.detect(text)
    }
    
    /// Check if content should be blurred
    func shouldBlurContent(_ text: String) -> Bool {
        guard requireAuthForSensitive else { return false }
        return sensitiveItemsLocked && detectSensitiveContent(text) != nil
    }
    
    // MARK: - Encryption
    
    /// Encrypt data for secure storage
    func encryptData(_ data: Data) throws -> Data {
        try encryptionService.encrypt(data)
    }
    
    /// Decrypt data from secure storage
    func decryptData(_ data: Data) throws -> Data {
        try encryptionService.decrypt(data)
    }
    
    /// Encrypt string for secure storage
    func encryptString(_ string: String) throws -> Data {
        guard let data = string.data(using: .utf8) else {
            throw EncryptionError.invalidInput
        }
        return try encryptData(data)
    }
    
    /// Decrypt string from secure storage
    func decryptString(_ data: Data) throws -> String {
        let decrypted = try decryptData(data)
        guard let string = String(data: decrypted, encoding: .utf8) else {
            throw EncryptionError.invalidInput
        }
        return string
    }
    
    // MARK: - Auto-Lock
    
    private func setupAutoLockTimer() {
        autoLockTimer?.invalidate()
        
        guard autoLockMinutes > 0 else { return }
        
        autoLockTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkAutoLock()
            }
        }
    }
    
    private func checkAutoLock() {
        guard autoLockMinutes > 0, isUnlocked else { return }
        
        let inactiveMinutes = Date().timeIntervalSince(lastActivityTime) / 60
        
        if inactiveMinutes >= Double(autoLockMinutes) {
            lock()
        }
    }
    
    // MARK: - Notifications
    
    private func setupNotifications() {
        let center = NSWorkspace.shared.notificationCenter
        
        // Lock on sleep
        sleepObserver = center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.lock()
        }
        
        // Lock on screen lock
        screenLockObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.lock()
        }
    }
    
    // MARK: - Logging
    
    private func logAccessAttempt(success: Bool) async {
        do {
            let db = DatabaseManager.shared
            try await db.open()
            try await db.execute(
                "INSERT INTO access_log (action, timestamp, success) VALUES (?, ?, ?)",
                parameters: ["authentication", Date(), success ? 1 : 0]
            )
        } catch {
            print("Failed to log access attempt: \(error)")
        }
    }
    
    // MARK: - Settings
    
    private func loadSettings() {
        autoLockMinutes = UserDefaults.standard.integer(forKey: "SecurityManager.autoLockMinutes")
        if autoLockMinutes == 0 {
            autoLockMinutes = 5 // Default
        }
        
        requireAuthForSensitive = UserDefaults.standard.bool(forKey: "SecurityManager.requireAuthForSensitive")
    }
    
    deinit {
        autoLockTimer?.invalidate()
        
        if let observer = sleepObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        
        if let observer = screenLockObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }
}

// MARK: - Self-Destructing Clips

extension SecurityManager {
    /// Store a clip that will auto-delete after specified time
    func storeSelfDestructingClip(content: String, deleteAfter: TimeInterval) async throws -> UUID {
        let id = UUID()
        let deleteAt = Date().addingTimeInterval(deleteAfter)
        
        // Encrypt content
        let encrypted = try encryptString(content)
        
        // Store in database
        let db = DatabaseManager.shared
        try await db.open()
        try await db.createSecurityTables()
        
        try await db.execute(
            "INSERT INTO sensitive_items (id, encrypted_data, type, created_at, auto_delete_at) VALUES (?, ?, ?, ?, ?)",
            parameters: [id.uuidString, encrypted, "self_destructing", Date(), deleteAt]
        )
        
        // Schedule deletion
        scheduleDeletion(id: id, at: deleteAt)
        
        return id
    }
    
    /// Retrieve a self-destructing clip
    func retrieveSelfDestructingClip(id: UUID) async throws -> String? {
        // Require authentication
        guard await authenticateForSensitiveContent() else {
            return nil
        }
        
        let db = DatabaseManager.shared
        try await db.open()
        
        let results = try await db.query(
            "SELECT encrypted_data FROM sensitive_items WHERE id = ?",
            parameters: [id.uuidString]
        )
        
        guard let row = results.first,
              let encrypted = row["encrypted_data"] as? Data else {
            return nil
        }
        
        return try decryptString(encrypted)
    }
    
    /// Schedule deletion of a sensitive item
    private func scheduleDeletion(id: UUID, at date: Date) {
        let timer = Timer(fire: date, interval: 0, repeats: false) { [weak self] _ in
            Task { [weak self] in
                await self?.deleteSensitiveItem(id: id)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }
    
    /// Delete a sensitive item
    func deleteSensitiveItem(id: UUID) async {
        do {
            let db = DatabaseManager.shared
            try await db.open()
            try await db.execute(
                "DELETE FROM sensitive_items WHERE id = ?",
                parameters: [id.uuidString]
            )
        } catch {
            print("Failed to delete sensitive item: \(error)")
        }
    }
}
