import Foundation
import AuthenticationServices
import Combine

class SupabaseAuthManager: ObservableObject {
    static let shared = SupabaseAuthManager()
    
    private let supabaseURL = URL(string: "https://aomabgwmlgxwptlpmkwf.supabase.co")!
    private let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFvbWFiZ3dtbGd4d3B0bHBta3dmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQ0NzAzNDUsImV4cCI6MjA3MDA0NjM0NX0.RNjLAi-ge6G73SrsCdrYPAb3y6klYJ0X71fDJ0bpNuc"
    
    @Published var isAuthenticated = false
    @Published var currentUserEmail: String?
    
    private let sessionKey = "supabase_session"
    
    struct AuthSession: Codable {
        let accessToken: String
        let refreshToken: String
        let user: User
        
        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case user
        }
    }
    
    struct User: Codable {
        let id: String
        let email: String?
    }
    
    private init() {
        loadSession()
    }
    
    private func loadSession() {
        if let data = UserDefaults.standard.data(forKey: sessionKey),
           let session = try? JSONDecoder().decode(AuthSession.self, from: data) {
            self.isAuthenticated = true
            self.currentUserEmail = session.user.email
            // Optionally: Validate token or refresh it
        }
    }
    
    private func saveSession(_ session: AuthSession) {
        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: sessionKey)
            self.isAuthenticated = true
            self.currentUserEmail = session.user.email
        }
    }
    
    func signOut() {
        UserDefaults.standard.removeObject(forKey: sessionKey)
        self.isAuthenticated = false
        self.currentUserEmail = nil
    }
    
    // MARK: - Email OTP
    
    func signInWithEmailOTP(email: String) async throws {
        let url = supabaseURL.appendingPathComponent("/auth/v1/otp")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.addValue(anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "email": email,
            "create_user": true
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            throw URLError(.badServerResponse) // Should parse error message
        }
    }
    
    func verifyEmailOTP(email: String, token: String) async throws {
        let url = supabaseURL.appendingPathComponent("/auth/v1/verify")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.addValue(anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "type": "email",
            "email": email,
            "token": token
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let session = try JSONDecoder().decode(AuthSession.self, from: data)
        saveSession(session)
    }
    
    // MARK: - Apple Sign In
    
    func signInWithApple(idToken: String, nonce: String) async throws {
        let url = supabaseURL.appendingPathComponent("/auth/v1/token")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "grant_type", value: "id_token")]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.addValue(anonKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "provider": "apple",
            "id_token": idToken,
            "nonce": nonce
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            if let errorStr = String(data: data, encoding: .utf8) {
                print("Apple Sign In Error: \(errorStr)")
            }
            throw URLError(.badServerResponse)
        }
        
        let session = try JSONDecoder().decode(AuthSession.self, from: data)
        saveSession(session)
    }
}
