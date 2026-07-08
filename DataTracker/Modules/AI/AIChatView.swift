import SwiftUI

struct Toast: Equatable {
    var message: String
    var isPresented: Bool
}

struct ToastView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(Theme.bodyFont)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.7))
            .cornerRadius(20)
            .shadow(radius: 4)
    }
}

struct AIChatView: View {
    @Binding var isPresented: Bool
    @StateObject private var speechService = SpeechRecognitionService()
    @ObservedObject private var sessionManager = ChatSessionManager.shared
    @ObservedObject private var userManager = UserManager.shared
    @State private var inputText: String = ""
    @State private var aiStatus: AIStatus = .idle
    @FocusState private var isInputFocused: Bool
    
    // Action Sheet States
    @State private var showImagePicker = false
    @State private var showNoteAlert = false
    @State private var showingPaywall = false
    @State private var selectedImages: [UIImage] = []
    @State private var noteText: String = ""
    @State private var currentActionRecordId: UUID? = nil
    
    // Voice Input State
    @State private var isVoiceMode = true
    @State private var isRecording = false
    @State private var isCanceling = false
    @State private var dragOffset: CGFloat = 0
    @State private var currentAudioURL: URL?
    @State private var recordingStartTime: Date?
    @State private var processingTask: Task<Void, Never>?
    
    // Toast State
    @State private var toast: Toast = Toast(message: "", isPresented: false)
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Chat Area
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 16) {
                                ForEach(sessionManager.messages) { message in
                                    VStack(alignment: .leading, spacing: 8) {
                                        ChatBubble(
                                            message: message.text,
                                            isUser: message.isUser,
                                            audioURL: message.audioURL,
                                            duration: message.duration,
                                            userAvatarPath: message.userAvatarPath,
                                            userName: message.userName ?? (message.isUser ? "用户" : "MoMo")
                                        )
                                        
                                        // Action Buttons for AI messages that created a record
                                        if !message.isUser && message.showActions, let recordId = message.relatedRecordId {
                                            HStack(spacing: 12) {
                                                Button {
                                                    currentActionRecordId = recordId
                                                    showImagePicker = true
                                                } label: {
                                                    Label("增加图片", systemImage: "photo")
                                                        .font(Theme.captionFont)
                                                        .foregroundColor(message.hasImage ? .white : Theme.textPrimary)
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 8)
                                                        .background(message.hasImage ? Theme.primary : Theme.surfaceElevated)
                                                        .cornerRadius(12)
                                                }
                                                .disabled(message.hasImage) // Optional: disable if already added
                                                
                                                Button {
                                                    currentActionRecordId = recordId
                                                    noteText = ""
                                                    showNoteAlert = true
                                                } label: {
                                                    Label("增加备注", systemImage: "note.text")
                                                        .font(Theme.captionFont)
                                                        .foregroundColor(message.hasNote ? .white : Theme.textPrimary)
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 8)
                                                        .background(message.hasNote ? Theme.primary : Theme.surfaceElevated)
                                                        .cornerRadius(12)
                                                }
                                                .disabled(message.hasNote) // Optional: disable if already added
                                            }
                                            .padding(.leading, 48) // Align with bubble content (36 avatar + 12 spacing)
                                        }
                                        
                                        // Upgrade Button
                                        if message.showUpgradeButton {
                                            Button {
                                                showingPaywall = true
                                            } label: {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "crown.fill")
                                                        .font(.system(size: 11))
                                                    Text("开通Pro会员，新用户首月仅5元")
                                                        .font(.system(size: 11, weight: .bold))
                                                }
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(
                                                    LinearGradient(colors: [Color(red: 1.0, green: 0.8, blue: 0.0), Color(red: 1.0, green: 0.5, blue: 0.0)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                                )
                                                .cornerRadius(14)
                                                .shadow(color: Color.orange.opacity(0.3), radius: 4, x: 0, y: 2)
                                            }
                                            .padding(.leading, 48)
                                            .padding(.top, 4)
                                        }
                                    }
                                    .id(message.id)
                                }
                            }
                            .padding()
                            .padding(.bottom, 60) // Space for floating status
                        }
                        .onChange(of: sessionManager.messages) { _, _ in
                            if let last = sessionManager.messages.last {
                                withAnimation {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                    
                    // Input Area
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            // Mode Switch Button
                            Button {
                                withAnimation {
                                    isVoiceMode.toggle()
                                    isInputFocused = !isVoiceMode
                                    if !isVoiceMode {
                                        inputText = ""
                                    }
                                }
                            } label: {
                                Image(systemName: isVoiceMode ? "keyboard" : "waveform")
                                    .font(.system(size: 20))
                                    .foregroundColor(Theme.textSecondary)
                                    .frame(width: 36, height: 36)
                                    .background(Theme.surfaceElevated)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            
                            if isVoiceMode {
                                // Voice Input Button
                                ZStack {
                                    // Background
                                    Capsule()
                                        .fill(isRecording ? (isCanceling ? Theme.error : Theme.accent) : Theme.surface)
                                        .frame(height: 48)
                                    
                                    Text(isRecording ? (isCanceling ? "松手取消" : "松手发送") : "按住说话")
                                        .font(Theme.bodyFont)
                                        .foregroundColor(isRecording ? .white : Theme.textSecondary)
                                }
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            if !isRecording {
                                                startRecording()
                                            }
                                            
                                            // Check drag distance for cancellation (slide up)
                                            dragOffset = value.translation.height
                                            withAnimation {
                                                isCanceling = dragOffset < -50
                                            }
                                        }
                                        .onEnded { value in
                                            stopRecording()
                                            dragOffset = 0
                                            isCanceling = false
                                        }
                                )
                            } else {
                                // Text Input
                                TextField("写点什么...", text: $inputText)
                                    .font(Theme.bodyFont)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Theme.surface.opacity(0.8))
                                    .cornerRadius(24)
                                    .focused($isInputFocused)
                                    .submitLabel(.send)
                                    .onSubmit {
                                        sendMessage()
                                    }
                                
                                // Send Button
                                Button(action: sendMessage) {
                                    Circle()
                                        .fill(inputText.isEmpty ? Theme.surfaceElevated : Theme.primary)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Image(systemName: "arrow.up")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundColor(inputText.isEmpty ? Theme.textTertiary : .white)
                                        )
                                }
                                .disabled(inputText.isEmpty)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 32)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .cornerRadius(32)
                        .shadow(color: Theme.shadowColor, radius: 10, x: 0, y: 4)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }
                }
                
                // Voice Overlay
                if isRecording {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .transition(.opacity)
                    
                    VStack(spacing: 24) {
                        Spacer()
                        
                        // Live Transcript
                        Text(speechService.transcript.isEmpty ? "正在听..." : speechService.transcript)
                            .font(Theme.headlineFont)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        
                        // Waveform Animation (Simulated)
                        HStack(spacing: 4) {
                            ForEach(0..<5) { _ in
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 8, height: 8)
                                    .opacity(isCanceling ? 0.5 : 1)
                            }
                        }
                        
                        // Cancel Instruction
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 24))
                            Text("上滑取消")
                                .font(Theme.captionFont)
                        }
                        .foregroundColor(isCanceling ? Theme.error : .white.opacity(0.8))
                        .padding(.bottom, 150)
                    }
                }
                
                // Floating Status Indicator
                
                // Floating Status Indicator
                if aiStatus != .idle {
                    VStack {
                        Spacer()
                        AIStatusIndicator(status: aiStatus)
                            .padding(.bottom, 100) // Above input area
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1) // Ensure it's above other content
                }
                
                // Toast
                if toast.isPresented {
                    VStack {
                        Spacer()
                        ToastView(message: toast.message)
                            .padding(.bottom, 120)
                    }
                    .transition(.opacity)
                    .zIndex(2)
                }
            }
            .navigationTitle("Memo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(Theme.textPrimary)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        sessionManager.clearMessages()
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 20))
                            .foregroundColor(Theme.textPrimary)
                    }
                }
            }
            .onChange(of: speechService.transcript) { _, newText in
                if speechService.isRecording {
                    inputText = newText
                    aiStatus = .listening
                }
            }
            .onChange(of: speechService.isRecording) { _, isRecording in
                if !isRecording && aiStatus == .listening {
                    aiStatus = .idle
                }
            }
            // Image Picker Sheet
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(images: $selectedImages, maxCount: 1)
            }
            .onChange(of: selectedImages) { _, newImages in
                if let image = newImages.first, let recordId = currentActionRecordId {
                    saveImageToRecord(recordId, image: image)
                }
            }
            // Note Alert
            .alert("添加备注", isPresented: $showNoteAlert) {
                TextField("请输入备注", text: $noteText)
                Button("确定") {
                    if let recordId = currentActionRecordId {
                        saveNoteToRecord(recordId, note: noteText)
                    }
                }
                Button("取消", role: .cancel) {}
            }
            .sheet(isPresented: $showingPaywall) {
                SubscriptionView()
            }
            .environment(\.openURL, OpenURLAction { url in
                if url.absoluteString == "app://subscription" {
                    showingPaywall = true
                    return .handled
                }
                return .systemAction
            })
        }
    }
    
    private func saveImageToRecord(_ id: UUID, image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        Task {
            do {
                try await CoreDataManager.shared.updateRecord(id: id, images: [imageData])
                await MainActor.run {
                    // Update message state
                    sessionManager.markImageAdded(for: id)
                    
                    // Show Toast
                    showToast(message: "图片已添加")
                    selectedImages = []
                }
            } catch {
                print("Failed to save image: \(error)")
            }
        }
    }
    
    private func saveNoteToRecord(_ id: UUID, note: String) {
        guard !note.isEmpty else { return }
        Task {
            do {
                try await CoreDataManager.shared.updateRecord(id: id, note: note)
                await MainActor.run {
                    // Update message state
                    sessionManager.markNoteAdded(for: id)
                    
                    // Show Toast
                    showToast(message: "备注已添加")
                    noteText = ""
                }
            } catch {
                print("Failed to save note: \(error)")
            }
        }
    }
    
    private func showToast(message: String) {
        withAnimation {
            toast = Toast(message: message, isPresented: true)
        }
        
        // Hide after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                toast.isPresented = false
            }
        }
    }
    
    // MARK: - Voice Recording Logic
    
    private func startRecording() {
        let docPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = docPath.appendingPathComponent("\(UUID().uuidString).m4a")
        currentAudioURL = audioFilename
        recordingStartTime = Date()
        
        isRecording = true
        speechService.startRecording(to: audioFilename)
    }
    
    private func stopRecording() {
        speechService.stopRecording()
        isRecording = false
        
        if isCanceling {
            // Delete file if canceling
            if let url = currentAudioURL {
                try? FileManager.default.removeItem(at: url)
            }
            currentAudioURL = nil
        } else {
            // Send Voice Message
            sendVoiceMessage()
        }
    }
    
    private func sendVoiceMessage() {
        guard let url = currentAudioURL else { return }
        
        // Use transcript if available, otherwise fallback
        let transcript = speechService.transcript
        let duration = Date().timeIntervalSince(recordingStartTime ?? Date())
        
        // 1. Add User Voice Message
        let userMsg = ChatMessage(
            text: transcript.isEmpty ? "语音消息" : transcript, // Fallback text for bubble accessibility/search? Actually UI uses audioURL to decide
            isUser: true,
            date: Date(),
            audioURL: url,
            duration: duration,
            userName: userManager.currentUser?.name,
            userAvatarPath: userManager.currentUser?.avatarPath
        )
        
        withAnimation {
            sessionManager.addMessage(userMsg)
        }
        
        // 2. Send Text to AI
        // If transcript is empty, maybe we should transcribe the file? 
        // For now, rely on live transcript.
        if !transcript.isEmpty {
            sendTextToAI(transcript)
        } else {
            // Edge case: No transcript captured. 
            // Could insert a "Processing audio..." state or just ignore.
            // Let's assume transcript works or user spoke nothing.
            if duration > 1.0 {
                 // Maybe speech recognizer failed but audio exists?
                 // For now, just send a placeholder or error
                 sessionManager.addMessage(ChatMessage(text: "未能识别语音内容", isUser: false, date: Date()))
            }
        }
        
        // Clear input text after sending voice message
        inputText = ""
    }
    
    private func startProcessingAnimation() {
        processingTask?.cancel()
        processingTask = Task { @MainActor in
            let states = ["语义理解中...", "AI分析中...", "数据记录中..."]
            var index = 0
            
            // Set initial state
            if case .processing = aiStatus {
                // Already processing, don't reset text immediately or do?
                // Let's just update
            } else {
                 withAnimation {
                    aiStatus = .processing(states[0])
                }
            }
            
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                if Task.isCancelled { break }
                
                index = (index + 1) % states.count
                
                // Only update if we are still processing to avoid overwriting other states
                if case .processing = aiStatus {
                    withAnimation {
                        aiStatus = .processing(states[index])
                    }
                } else {
                    break
                }
            }
        }
    }
    
    private func stopProcessingAnimation() {
        processingTask?.cancel()
        processingTask = nil
    }

    private func sendTextToAI(_ text: String) {
        // 1. Check AI Quota (Synchronous UI Check)
        let isPro = SubscriptionManager.shared.isPro
        let currentUsage = AIService.shared.getCurrentDailyUsage()
        
        if !isPro && currentUsage >= SubscriptionManager.Limits.maxFreeAIDaily {
            // Block sending
            withAnimation {
                var msg = ChatMessage(text: "今日免费 AI 对话额度已用完（\(SubscriptionManager.Limits.maxFreeAIDaily)次）。", isUser: false, date: Date())
                msg.showUpgradeButton = true
                sessionManager.addMessage(msg)
                aiStatus = .idle
            }
            return
        }
        
        // Update status to processing and start animation
        withAnimation {
            aiStatus = .processing("AI 思考中...")
        }
        startProcessingAnimation()
        
        Task {
            // Perform AI processing
            let response = await AIService.shared.processUserMessage(text)
            
            // Stop animation
            await MainActor.run {
                stopProcessingAnimation()
                withAnimation {
                    aiStatus = .speaking
                }
            }
            
            // Short delay to allow transition visibility if needed, or remove completely as requested.
            // User asked to "not force wait 5 seconds".
            // I'll remove the artificial delay completely.
            
            await MainActor.run {
                withAnimation {
                    var msg = ChatMessage(text: response.text, isUser: false, date: Date(), relatedRecordId: response.recordId, showActions: response.recordId != nil)
                    msg.showUpgradeButton = response.showUpgradeButton
                    sessionManager.addMessage(msg)
                    aiStatus = .idle
                }
            }
        }
    }

    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMsg = ChatMessage(
            text: inputText,
            isUser: true,
            date: Date(),
            userName: userManager.currentUser?.name,
            userAvatarPath: userManager.currentUser?.avatarPath
        )
        withAnimation {
            sessionManager.addMessage(userMsg)
        }
        
        let textToSend = inputText
        inputText = ""
        isInputFocused = false
        
        sendTextToAI(textToSend)
    }
}

#Preview {
    AIChatView(isPresented: .constant(true))
        .environmentObject(AppThemeManager.shared)
}
