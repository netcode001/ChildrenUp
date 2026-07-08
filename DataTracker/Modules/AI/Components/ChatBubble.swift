import SwiftUI
import AVFoundation
import Combine

struct ChatBubble: View {
    let message: String
    let isUser: Bool
    let audioURL: URL?
    let duration: TimeInterval?
    let userAvatarPath: String?
    let userName: String?
    
    @State private var userAvatar: Image?
    
    init(message: String, isUser: Bool, audioURL: URL? = nil, duration: TimeInterval? = nil, userAvatarPath: String? = nil, userName: String? = nil) {
        self.message = message
        self.isUser = isUser
        self.audioURL = audioURL
        self.duration = duration
        self.userAvatarPath = userAvatarPath
        self.userName = userName
    }
    
    @StateObject private var audioPlayer = AudioPlayer()
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if isUser {
                Spacer()
            } else {
                // AI Avatar Column
                VStack(spacing: 4) {
                    Circle()
                        .fill(Theme.accentGradient)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "sparkles")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        )
                    
                    if let userName = userName {
                        Text(userName)
                            .font(Theme.smallFont)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
            
            if let audioURL = audioURL {
                // Audio Bubble
                Button {
                    audioPlayer.play(url: audioURL)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: audioPlayer.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                            .font(.system(size: 24))
                        
                        // Waveform (Simulated)
                        HStack(spacing: 2) {
                            ForEach(0..<10) { i in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(isUser ? Theme.textPrimary.opacity(0.6) : Theme.textPrimary)
                                    .frame(width: 2, height: .random(in: 10...20))
                            }
                        }
                        
                        Text(formatDuration(duration ?? 0))
                            .font(Theme.captionFont)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(isUser ? Theme.surfaceElevated : Color.clear)
                    )
                    .foregroundColor(Theme.textPrimary)
                }
            } else {
                // Text Bubble
                Text(message)
                    .font(Theme.bodyFont)
                    .foregroundColor(Theme.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Theme.surfaceElevated)
                    )
                    .shadow(color: Theme.shadowColor.opacity(0.1), radius: 2, x: 0, y: 1)
            }
            
            if isUser {
                // User Avatar Column
                VStack(spacing: 4) {
                    if let userAvatar = userAvatar {
                        userAvatar
                            .resizable()
                            .scaledToFill()
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Theme.surfaceElevated)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(Theme.primary)
                            )
                    }
                    
                    if let userName = userName {
                        Text(userName)
                            .font(Theme.smallFont)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            } else {
                Spacer()
            }
        }
        .onAppear {
            loadAvatar()
        }
    }
    
    private func loadAvatar() {
        guard let path = userAvatarPath, !path.isEmpty else { return }
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = dir.appendingPathComponent(path)
            if let data = try? Data(contentsOf: fileURL), let uiImage = UIImage(data: data) {
                userAvatar = Image(uiImage: uiImage)
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        return String(format: "%d\"", seconds)
    }
}

class AudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    private var player: AVAudioPlayer?
    
    func play(url: URL) {
        if isPlaying {
            player?.stop()
            isPlaying = false
            return
        }
        
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.play()
            isPlaying = true
        } catch {
            print("Audio play error: \(error)")
        }
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
    }
}

#Preview {
    VStack {
        ChatBubble(message: "今天喝了多少水？", isUser: true)
        ChatBubble(message: "今天你记录了 500ml 的水。", isUser: false)
    }
    .padding()
    .background(Theme.background)
}
