import Foundation
import CloudKit
import Combine

class CloudSyncManager: ObservableObject {
    static let shared = CloudSyncManager()
    
    @Published var iCloudAccountStatus: CKAccountStatus = .couldNotDetermine
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?
    
    private init() {
        checkAccountStatus()
        // Listen for iCloud account changes
        NotificationCenter.default.addObserver(self, selector: #selector(accountChanged), name: .CKAccountChanged, object: nil)
    }
    
    func checkAccountStatus() {
        CKContainer.default().accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                self?.iCloudAccountStatus = status
            }
        }
    }
    
    @objc private func accountChanged() {
        checkAccountStatus()
    }
    
    func triggerSync() async {
        await MainActor.run {
            self.isSyncing = true
        }
        
        // Simulating a sync trigger or waiting for Core Data to catch up
        // In reality, NSPersistentCloudKitContainer syncs automatically.
        // We can simulate a "check" by performing a small operation or just waiting.
        
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds delay to simulate check
        
        await MainActor.run {
            self.isSyncing = false
            self.lastSyncDate = Date()
        }
    }
}
