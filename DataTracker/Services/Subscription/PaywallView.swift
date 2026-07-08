import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var isRestoring = false
    @State private var showRedeemSheet = false
    @State private var inviteCode = ""
    @State private var redeemMessage = ""
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header Image
                    Image(systemName: "crown.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Theme.accent)
                        .padding(.top, 40)
                        .padding(.bottom, 10)
                    
                    Text("解锁 Pro 专业版")
                        .font(Theme.titleFont)
                        .foregroundColor(Theme.textPrimary)
                    
                    Text("无限制记录，智能分析，掌控生活")
                        .font(Theme.bodyFont)
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Feature List
                    VStack(alignment: .leading, spacing: 16) {
                        FeatureRow(icon: "person.2.fill", title: "无限用户", subtitle: "为家人、宠物创建独立档案")
                        FeatureRow(icon: "chart.xyaxis.line", title: "无限追踪项", subtitle: "记录生活中的每一个细节")
                        FeatureRow(icon: "brain.head.profile", title: "AI 深度分析", subtitle: "无限制智能对话与周报总结")
                        FeatureRow(icon: "lock.fill", title: "隐私安全锁", subtitle: "FaceID / 密码保护数据安全")
                        FeatureRow(icon: "icloud.and.arrow.down.fill", title: "高级导出", subtitle: "完整数据备份与迁移")
                    }
                    .padding(24)
                    .background(Theme.surfaceElevated)
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // Products
                    if subscriptionManager.isLoading {
                        ProgressView()
                            .padding()
                    } else {
                        VStack(spacing: 12) {
                            ForEach(subscriptionManager.products) { product in
                                Button {
                                    Task {
                                        await subscriptionManager.purchase(product)
                                    }
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(product.displayName)
                                                .font(.headline)
                                            Text(product.description)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Text(product.displayPrice)
                                            .font(.headline)
                                            .foregroundColor(Theme.primary)
                                    }
                                    .padding()
                                    .background(Theme.surface)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Theme.primary.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Restore
                    Button {
                        Task {
                            isRestoring = true
                            await subscriptionManager.restorePurchases()
                            isRestoring = false
                        }
                    } label: {
                        Text("恢复购买")
                            .font(Theme.captionFont)
                            .foregroundColor(Theme.textSecondary)
                            .underline()
                    }
                    .padding(.top, 8)
                    
                    Spacer(minLength: 40)
                    
                    // Footer
                    Text("确认购买后将从您的 Apple ID 账户扣款。订阅将自动续期，除非在当前周期结束前至少 24 小时取消。")
                        .font(.caption2)
                        .foregroundColor(Theme.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 20)
                }
            }
            
            // Close Button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(Theme.textSecondary)
                            .padding()
                    }
                }
                Spacer()
            }
        }
        .onChange(of: subscriptionManager.isPro) { _, isPro in
            if isPro {
                dismiss()
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(Theme.primary)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.bodyFont)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }
}
