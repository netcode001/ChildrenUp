import SwiftUI
import LocalAuthentication

struct LockScreenView: View {
    @StateObject private var appLockManager = AppLockManager.shared
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Theme.primary)
                
                Text("应用已锁定")
                    .font(Theme.titleFont)
                    .foregroundColor(Theme.textPrimary)
                
                Button {
                    appLockManager.authenticate()
                } label: {
                    Text("点击解锁")
                        .font(Theme.headlineFont)
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 12)
                        .background(Theme.primary)
                        .cornerRadius(25)
                }
            }
        }
        .onAppear {
            appLockManager.authenticate()
        }
    }
}
