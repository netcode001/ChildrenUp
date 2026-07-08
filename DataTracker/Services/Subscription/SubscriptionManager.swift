import Foundation
import StoreKit
import SwiftUI
import Combine

// MARK: - Subscription Configuration

enum SubscriptionTier: String, CaseIterable {
    case free
    case pro
    
    var localizedName: String {
        switch self {
        case .free: return "免费版"
        case .pro: return "Pro 专业版"
        }
    }
}

// MARK: - Product Identifiers

struct StoreIDs {
    static let proMonthly = "com.ailee.datatracker.pro.monthly"
    static let proYearly = "com.ailee.datatracker.pro.yearly"
    static let proLifetime = "com.ailee.datatracker.pro.lifetime"
    
    static let allIdentifiers: Set<String> = [proMonthly, proYearly, proLifetime]
}

// MARK: - Subscription Manager

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isPro: Bool = false
    @Published private(set) var expirationDate: Date? // Add expiration date
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Invite Code System
    @AppStorage("redeemedProExpiryDate") private var redeemedProExpiryDate: Double = 0
    @Published var redemptionMessage: String?
    
    private var updates: Task<Void, Never>? = nil
    
    private init() {
        // Start listening for transaction updates
        updates = newTransactionListenerTask()
        
        // Initial check
        Task {
            await updateSubscriptionStatus()
            await loadProducts()
        }
    }
    
    deinit {
        updates?.cancel()
    }
    
    // MARK: - Core Logic
    
    func loadProducts() async {
        isLoading = true
        print("StoreKit: Loading products for identifiers: \(StoreIDs.allIdentifiers)")
        do {
            let products = try await Product.products(for: StoreIDs.allIdentifiers)
            print("StoreKit: Successfully loaded \(products.count) products.")
            for product in products {
                print("StoreKit: Found product - \(product.id) \(product.displayName) \(product.price)")
            }
            self.products = products.sorted { $0.price < $1.price }
        } catch {
            print("StoreKit: Failed to load products: \(error)")
            errorMessage = "无法加载商品列表，请检查网络"
        }
        isLoading = false
    }
    
    func purchase(_ product: Product) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Add 30s timeout to prevent infinite loading
            let task = Task {
                return try await product.purchase()
            }
            
            let result = try await withThrowingTaskGroup(of: Product.PurchaseResult.self) { group in
                group.addTask {
                    return try await task.value
                }
                
                group.addTask {
                    try await Task.sleep(nanoseconds: 30 * 1_000_000_000)
                    throw CancellationError()
                }
                
                guard let success = try await group.next() else {
                    throw CancellationError()
                }
                group.cancelAll()
                return success
            }
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updateSubscriptionStatus()
                
            case .userCancelled:
                print("User cancelled purchase")
                
            case .pending:
                print("Purchase pending")
                
            @unknown default:
                break
            }
        } catch is CancellationError {
            print("Purchase timeout")
            errorMessage = "连接 App Store 超时，请稍后重试"
        } catch {
            print("Purchase failed: \(error)")
            errorMessage = "购买失败：\(error.localizedDescription)"
        }
    }
    
    func restorePurchases() async {
        isLoading = true
        try? await AppStore.sync()
        await updateSubscriptionStatus()
        isLoading = false
    }
    
    // MARK: - Internal Helpers
    
    private func newTransactionListenerTask() -> Task<Void, Never> {
        Task(priority: .background) {
            for await verification in Transaction.updates {
                do {
                    let transaction = try checkVerified(verification)
                    await transaction.finish()
                    await updateSubscriptionStatus()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    private func updateSubscriptionStatus() async {
        var purchasedIDs: Set<String> = []
        var maxExpiryDate: Date? = nil
        
        // Iterate through all current entitlements
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                // Check if not expired (though currentEntitlements usually returns valid ones)
                if let expiryDate = transaction.expirationDate {
                    if expiryDate < Date() {
                        continue
                    }
                    // Update max expiry from App Store
                    if maxExpiryDate == nil || expiryDate > maxExpiryDate! {
                        maxExpiryDate = expiryDate
                    }
                }
                
                if transaction.revocationDate == nil {
                    purchasedIDs.insert(transaction.productID)
                }
            } catch {
                print("Failed to verify entitlement")
            }
        }
        
        self.purchasedProductIDs = purchasedIDs
        
        // Check redeemed code expiry
        if isProViaCode {
            let codeExpiry = Date(timeIntervalSince1970: redeemedProExpiryDate)
            if maxExpiryDate == nil || codeExpiry > maxExpiryDate! {
                maxExpiryDate = codeExpiry
            }
        }
        
        self.expirationDate = maxExpiryDate
        
        // Determine Pro status
        // Add debug override for simulator testing if needed
        #if DEBUG
        // Uncomment to force Pro mode for testing UI
        // self.isPro = true
        // return
        #endif
        
        self.isPro = !purchasedIDs.isDisjoint(with: StoreIDs.allIdentifiers) || isProViaCode
    }
    
    private var isProViaCode: Bool {
        return Date().timeIntervalSince1970 < redeemedProExpiryDate
    }
    
    func redeemCode(_ code: String) -> Bool {
        // Simple static code validation (Mock)
        // In production, this would verify against a backend
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        print("DEBUG: Checking code: '\(normalizedCode)' (Original: '\(code)')") // Debug log

        var duration: TimeInterval = 0
        
        switch normalizedCode {
        case "TEST2025": // 7 Days
            duration = 7 * 24 * 3600
        case "VIP888": // 30 Days
            duration = 30 * 24 * 3600
        case "PROFOREVER": // 100 Years (Dev)
            duration = 100 * 365 * 24 * 3600
        default:
            print("DEBUG: Code '\(normalizedCode)' not found in switch case")
            return false
        }
        
        // Extend existing expiry if valid, or start from now
        let currentExpiry = max(Date().timeIntervalSince1970, redeemedProExpiryDate)
        redeemedProExpiryDate = currentExpiry + duration
        
        print("DEBUG: Code redeemed successfully. New expiry: \(Date(timeIntervalSince1970: redeemedProExpiryDate))")

        Task {
            await updateSubscriptionStatus()
        }
        return true
    }
    
    // MARK: - Feature Gates (Limits)
    
    struct Limits {
        static let maxFreeUsers = 1
        static let maxFreeTrackers = 10
        static let maxFreeAIDaily = 20
        static let maxFreeHistoryDays = 7
    }
    
    func canCreateUser(currentUserCount: Int) -> Bool {
        if isPro { return true }
        return currentUserCount < Limits.maxFreeUsers
    }
    
    func canCreateTracker(currentItemCount: Int) -> Bool {
        if isPro { return true }
        return currentItemCount < Limits.maxFreeTrackers
    }
    
    func canUseAI(dailyUsage: Int) -> Bool {
        if isPro { return true }
        return dailyUsage < Limits.maxFreeAIDaily
    }
    
    func canExport() -> Bool {
        // Simple gate: only Pro can export complex data (or maybe limit format)
        // For now, let's say Export is a Pro feature for multi-user, 
        // but basic single user export might be free?
        // User requested: "Export data page select users... then export"
        // Let's gate the MULTI-USER export.
        return true 
    }
    
    func canViewFullHistory() -> Bool {
        return isPro
    }
}

enum StoreError: Error {
    case failedVerification
}
