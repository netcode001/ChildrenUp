import SwiftUI

struct VoiceInputButton: View {
    @StateObject private var speechService = SpeechRecognitionService()
    @State private var isPressed = false
    @State private var isCanceling = false
    @State private var dragOffset: CGSize = .zero
    
    var onSpeechCaptured: (String) -> Void
    
    var body: some View {
        Button(action: {
            // Action for tap (optional, maybe toggle?)
        }) {
            ZStack {
                Circle()
                    .fill(isPressed ? (isCanceling ? Color.gray : Color.red) : Color.blue)
                    .frame(width: 60, height: 60)
                    .shadow(radius: 4)
                    .scaleEffect(isPressed ? 1.1 : 1.0)
                
                Image(systemName: "mic.fill")
                    .foregroundColor(.white)
                    .font(.title2)
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isPressed {
                        isPressed = true
                        isCanceling = false
                        speechService.startRecording()
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    }
                    
                    // Track drag to check for cancel
                    dragOffset = value.translation
                    // If dragged up significantly (e.g., -80 points), treat as cancel intent
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isCanceling = value.translation.height < -80
                    }
                }
                .onEnded { _ in
                    let wasCanceling = isCanceling
                    
                    isPressed = false
                    isCanceling = false
                    dragOffset = .zero
                    
                    speechService.stopRecording()
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    
                    if !wasCanceling && !speechService.transcript.isEmpty {
                        onSpeechCaptured(speechService.transcript)
                    }
                }
        )
        .overlay(
            Group {
                if isPressed {
                    ZStack {
                        // Cancel Area Indicator (appears above)
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(isCanceling ? Color.red : Color.black.opacity(0.5))
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: "xmark")
                                    .font(.title)
                                    .foregroundColor(.white)
                            }
                            .scaleEffect(isCanceling ? 1.2 : 1.0)
                            
                            Text(isCanceling ? "松开取消" : "上滑取消")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(8)
                        }
                        .offset(y: -160) // Positioned well above the button
                        .transition(.opacity)
                        
                        // Live Transcript Bubble
                        VStack {
                            Text(speechService.transcript.isEmpty ? "请说话..." : speechService.transcript)
                                .font(.body)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .padding()
                                .background(Material.thickMaterial)
                                .cornerRadius(12)
                                .shadow(radius: 5)
                                .frame(maxWidth: 250)
                                .opacity(isCanceling ? 0.3 : 1.0) // Dim text when canceling
                        }
                        .offset(y: -80) // Positioned just above the button
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            , alignment: .bottom // Align overlay to bottom so offsets are relative to button
        )
    }
}
