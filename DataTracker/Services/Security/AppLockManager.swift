import Foundation
import LocalAuthentication
import SwiftUI
import Combine

@MainActor
class AppLockManager: ObservableObject {
    static let shared = AppLockManager()
    
    @Published var isLocked: Bool = false
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "isAppLockEnabled")
        }
    }
    
    private var isAuthenticating = false
    
    private init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: "isAppLockEnabled")
        self.isLocked = self.isEnabled
    }
    
    func authenticate() {
        guard isEnabled else {
            isLocked = false
            return
        }
        
        // Prevent repeated calls if already unlocked or authenticating
        guard isLocked && !isAuthenticating else { return }
        
        isAuthenticating = true
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "请验证以解锁应用"
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    self.isAuthenticating = false
                    if success {
                        self.isLocked = false
                    } else {
                        // Keep locked if failed or cancelled
                        self.isLocked = true
                    }
                }
            }
        } else {
            // Fallback to passcode if biometrics unavailable
            if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
                context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "输入密码解锁") { success, _ in
                    DispatchQueue.main.async {
                        self.isAuthenticating = false
                        self.isLocked = !success
                    }
                }
            } else {
                // No auth available, unlock? Or stay locked?
                // Safety first: stay locked if enabled but broken, or auto-unlock if feature unsupported?
                // Let's assume if enabled but unavailable, we unlock to avoid bricking
                DispatchQueue.main.async {
                    self.isAuthenticating = false
                    self.isLocked = false
                }
            }
        }
    }
    
    func lockApp() {
        if isEnabled {
            isLocked = true
        }
    }
}
