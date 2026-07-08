import SwiftUI

enum AIStatus: Equatable {
    case idle
    case listening
    case processing(String) // e.g., "分析语义中...", "查询数据中..."
    case speaking
    case error(String)
}

struct AIStatusIndicator: View {
    let status: AIStatus
    
    var body: some View {
        HStack(spacing: 8) {
            switch status {
            case .idle:
                EmptyView()
            case .listening:
                if #available(iOS 17.0, *) {
                    Image(systemName: "mic.fill")
                        .foregroundColor(Theme.primary)
                        .symbolEffect(.pulse, isActive: true)
                } else {
                    Image(systemName: "mic.fill")
                        .foregroundColor(Theme.primary)
                }
                Text("正在听...")
                    .font(Theme.captionFont)
                    .foregroundColor(Theme.textSecondary)
            case .processing(let text):
                ProgressView()
                    .scaleEffect(0.8)
                Text(text)
                    .font(Theme.captionFont)
                    .foregroundColor(Theme.textSecondary)
            case .speaking:
                if #available(iOS 17.0, *) {
                    Image(systemName: "waveform")
                        .foregroundColor(Theme.primary)
                        .symbolEffect(.variableColor.iterative, isActive: true)
                } else {
                    Image(systemName: "waveform")
                        .foregroundColor(Theme.primary)
                }
                Text("AI 正在回复...")
                    .font(Theme.captionFont)
                    .foregroundColor(Theme.textSecondary)
            case .error(let msg):
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(Theme.warning)
                Text(msg)
                    .font(Theme.captionFont)
                    .foregroundColor(Theme.warning)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.surfaceElevated)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .animation(.easeInOut, value: status)
    }
}

#Preview {
    VStack {
        AIStatusIndicator(status: .listening)
        AIStatusIndicator(status: .processing("分析语义中..."))
        AIStatusIndicator(status: .processing("查询本地数据..."))
        AIStatusIndicator(status: .error("网络连接断开"))
    }
    .padding()
    .background(Theme.background)
}
