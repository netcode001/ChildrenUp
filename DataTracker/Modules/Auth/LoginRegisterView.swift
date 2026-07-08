import SwiftUI
import Combine
import AuthenticationServices
import CryptoKit

struct LoginRegisterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var authManager = SupabaseAuthManager.shared
    
    @State private var email: String = ""
    @State private var otpCode: String = ""
    @State private var isOtpSent: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?
    @State private var currentNonce: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.spacing * 1.5) {
                // Header
                VStack(spacing: 12) {
                    Text("数据记录")
                        .font(Theme.titleFont)
                        .foregroundColor(Theme.textPrimary)
                    Text("登录或注册以同步数据")
                        .font(Theme.bodyFont)
                        .foregroundColor(Theme.textSecondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                        .fill(Theme.surfaceElevated)
                )
                
                // Error Banner
                if let error = errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(Theme.warning)
                        Text(error)
                            .font(Theme.captionFont)
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                        Button("关闭") {
                            errorMessage = nil
                        }
                        .font(Theme.captionFont)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.cornerRadius)
                            .fill(Theme.surfaceElevated)
                    )
                }
                
                // Form
                VStack(spacing: Theme.spacing) {
                    if !isOtpSent {
                        // Email Input
                        TextField("请输入邮箱", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .padding()
                            .background(Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                    .stroke(Theme.border, lineWidth: 1)
                            )
                        
                        Button(action: sendOtp) {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("发送验证码")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                .fill(email.isEmpty ? AnyShapeStyle(Theme.textSecondary.opacity(0.3)) : AnyShapeStyle(Theme.primaryGradient))
                        )
                        .foregroundColor(.white)
                        .disabled(email.isEmpty || isSubmitting)
                        
                    } else {
                        // OTP Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("验证码已发送至 \(email)")
                                .font(Theme.captionFont)
                                .foregroundColor(Theme.textSecondary)
                            
                            TextField("请输入6位验证码", text: $otpCode)
                                .keyboardType(.numberPad)
                                .textContentType(.oneTimeCode)
                                .padding()
                                .background(Theme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                        .stroke(Theme.border, lineWidth: 1)
                                )
                        }
                        
                        Button(action: verifyOtp) {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("验证登录")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                .fill(otpCode.count != 6 ? AnyShapeStyle(Theme.textSecondary.opacity(0.3)) : AnyShapeStyle(Theme.primaryGradient))
                        )
                        .foregroundColor(.white)
                        .disabled(otpCode.count != 6 || isSubmitting)
                        
                        Button("重新发送") {
                            isOtpSent = false
                            otpCode = ""
                            errorMessage = nil
                        }
                        .font(Theme.captionFont)
                        .foregroundColor(Theme.primary)
                        .padding(.top, 4)
                    }
                }
                .padding()
                
                // Divider
                HStack {
                    Rectangle().fill(Theme.border).frame(height: 1)
                    Text("或者")
                        .font(Theme.captionFont)
                        .foregroundColor(Theme.textSecondary)
                    Rectangle().fill(Theme.border).frame(height: 1)
                }
                .padding(.horizontal)
                
                // Apple Sign In
                SignInWithAppleButton(
                    onRequest: { request in
                        let nonce = randomNonceString()
                        currentNonce = nonce
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = sha256(nonce)
                    },
                    onCompletion: { result in
                        switch result {
                        case .success(let authResults):
                            switch authResults.credential {
                            case let appleIDCredential as ASAuthorizationAppleIDCredential:
                                guard let nonce = currentNonce else {
                                    fatalError("Invalid state: A login callback was received, but no login request was sent.")
                                }
                                guard let appleIDToken = appleIDCredential.identityToken else {
                                    print("Unable to fetch identity token")
                                    errorMessage = "无法获取 Apple ID Token"
                                    return
                                }
                                guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                                    print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
                                    errorMessage = "Token 格式错误"
                                    return
                                }
                                
                                loginWithApple(idToken: idTokenString, nonce: nonce)
                                
                            default:
                                break
                            }
                        case .failure(let error):
                            print("Authorization failed: \(error.localizedDescription)")
                            errorMessage = error.localizedDescription
                        }
                    }
                )
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 50)
                .cornerRadius(Theme.cornerRadius)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("登录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated {
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func sendOtp() {
        isSubmitting = true
        errorMessage = nil
        
        Task {
            do {
                try await authManager.signInWithEmailOTP(email: email)
                await MainActor.run {
                    isSubmitting = false
                    isOtpSent = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = "发送失败: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func verifyOtp() {
        isSubmitting = true
        errorMessage = nil
        
        Task {
            do {
                try await authManager.verifyEmailOTP(email: email, token: otpCode)
                await MainActor.run {
                    isSubmitting = false
                    // Dismiss is handled by onChange
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = "验证失败: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func loginWithApple(idToken: String, nonce: String) {
        isSubmitting = true
        errorMessage = nil
        
        Task {
            do {
                // Pass RAW nonce to Supabase (Supabase will hash it and compare with ID Token)
                try await authManager.signInWithApple(idToken: idToken, nonce: nonce)
                await MainActor.run {
                    isSubmitting = false
                    // Dismiss is handled by onChange
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = "Apple登录失败: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Crypto Helpers
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        
        return String(nonce)
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
    }
}

#Preview {
    LoginRegisterView()
}
