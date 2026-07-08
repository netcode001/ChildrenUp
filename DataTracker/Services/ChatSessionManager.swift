import SwiftUI
import Combine

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let date: Date
    // New properties for record interaction
    var relatedRecordId: UUID? = nil
    var showActions: Bool = false
    var hasImage: Bool = false
    var hasNote: Bool = false
    // Audio properties
    var audioURL: URL? = nil
    var duration: TimeInterval? = nil
    // Upgrade prompt
    var showUpgradeButton: Bool = false
    
    // User info snapshot
    var userName: String? = nil
    var userAvatarPath: String? = nil
}

class ChatSessionManager: ObservableObject {
    static let shared = ChatSessionManager()
    
    @Published var messages: [ChatMessage] = [
        ChatMessage(text: "你好！想记录什么？或者问我“本周运动了多久？”", isUser: false, date: Date(), userName: "MoMo")
    ]
    
    private init() {}
    
    func addMessage(_ message: ChatMessage) {
        messages.append(message)
    }
    
    func clearMessages() {
        messages = [
            ChatMessage(text: "你好！想记录什么？或者问我“本周运动了多久？”", isUser: false, date: Date(), userName: "MoMo")
        ]
    }
    
    func updateMessage(_ message: ChatMessage) {
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index] = message
        }
    }
    
    // Helper to update specific fields for record actions
    func markImageAdded(for recordId: UUID) {
        if let index = messages.firstIndex(where: { $0.relatedRecordId == recordId }) {
            var msg = messages[index]
            msg.hasImage = true
            messages[index] = msg
        }
    }
    
    func markNoteAdded(for recordId: UUID) {
        if let index = messages.firstIndex(where: { $0.relatedRecordId == recordId }) {
            var msg = messages[index]
            msg.hasNote = true
            messages[index] = msg
        }
    }
}
