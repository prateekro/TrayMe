//
//  BiometricAuth.swift
//  TrayMe
//
//  Touch ID / Face ID integration using LocalAuthentication

import Foundation
import LocalAuthentication

/// Biometric authentication handler
class BiometricAuth: ObservableObject {
    /// Available biometric type
    enum BiometricType {
        case none
        case touchID
        case faceID
    }
    
    /// Current biometric type available on device
    @Published private(set) var biometricType: BiometricType = .none
    
    /// Whether biometric authentication is available
    @Published private(set) var isAvailable: Bool = false
    
    /// Last error message if any
    @Published var lastError: String?
    
    init() {
        checkAvailability()
    }
    
    /// Check biometric availability
    func checkAvailability() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            isAvailable = true
            
            switch context.biometryType {
            case .touchID:
                biometricType = .touchID
            case .faceID:
                biometricType = .faceID
            case .opticID:
                biometricType = .faceID // Treat as Face ID equivalent
            @unknown default:
                biometricType = .none
            }
        } else {
            isAvailable = false
            biometricType = .none
            
            if let error = error {
                lastError = mapError(error)
            }
        }
    }
    
    /// Authenticate with biometrics
    /// - Parameter reason: Reason shown to user for authentication
    /// - Returns: Whether authentication succeeded
    func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Use Password"
        
        // Allow fallback to device passcode
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            lastError = mapError(error)
            return false
        }
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            
            if success {
                lastError = nil
            }
            
            return success
        } catch let error as NSError {
            lastError = mapError(error)
            return false
        }
    }
    
    /// Authenticate with biometrics only (no password fallback)
    func authenticateBiometricsOnly(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "" // Hide fallback option
        
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            lastError = mapError(error)
            return false
        }
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            
            if success {
                lastError = nil
            }
            
            return success
        } catch let error as NSError {
            lastError = mapError(error)
            return false
        }
    }
    
    /// Get display name for current biometric type
    var biometricName: String {
        switch biometricType {
        case .none:
            return "Biometrics"
        case .touchID:
            return "Touch ID"
        case .faceID:
            return "Face ID"
        }
    }
    
    /// Get SF Symbol for current biometric type
    var biometricIcon: String {
        switch biometricType {
        case .none:
            return "lock.fill"
        case .touchID:
            return "touchid"
        case .faceID:
            return "faceid"
        }
    }
    
    // MARK: - Private Methods
    
    private func mapError(_ error: NSError?) -> String {
        guard let error = error else {
            return "Unknown error"
        }
        
        switch error.code {
        case LAError.authenticationFailed.rawValue:
            return "Authentication failed"
        case LAError.userCancel.rawValue:
            return "Authentication was cancelled"
        case LAError.userFallback.rawValue:
            return "Password was selected"
        case LAError.biometryNotAvailable.rawValue:
            return "Biometric authentication is not available"
        case LAError.biometryNotEnrolled.rawValue:
            return "Biometric authentication is not set up"
        case LAError.biometryLockout.rawValue:
            return "Biometric authentication is locked out"
        case LAError.notInteractive.rawValue:
            return "Not interactive"
        default:
            return error.localizedDescription
        }
    }
}
