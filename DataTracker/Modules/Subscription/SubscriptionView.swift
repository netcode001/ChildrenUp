import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showCustomRedemptionAlert = false
    @State private var redemptionCodeInput = ""
    @State private var selectedProduct: Product?
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 24) {
                        // 1. Header Area
                        headerSection
                        
                        // 2. Feature Comparison
                        comparisonSection
                        
                        // 3. Plans Selection
                        planSelectionSection
                        
                        // 4. Footer Links (Restore & Redeem)
                        footerLinksSection
                        
                        // Spacer for bottom button
                        Color.clear.frame(height: 80)
                    }
                    .padding(.vertical)
                }
                .background(Theme.background)
                
                // 5. Sticky Bottom Button
                purchaseButtonSection
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(Theme.textPrimary)
                }
            }
        }
        .onChange(of: subscriptionManager.products) { _, newProducts in
            if selectedProduct == nil {
                // Default to Yearly (Best Value) or the second item
                selectedProduct = newProducts.first { $0.id.contains("yearly") } ?? newProducts.first
            }
        }
        .onAppear {
            if selectedProduct == nil {
                selectedProduct = subscriptionManager.products.first { $0.id.contains("yearly") } ?? subscriptionManager.products.first
            }
        }
        .alert("提示", isPresented: Binding<Bool>(
            get: { subscriptionManager.errorMessage != nil },
            set: { if !$0 { subscriptionManager.errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) { }
        } message: {
            if let errorMessage = subscriptionManager.errorMessage {
                Text(errorMessage)
            }
        }
        .alert("兑换优惠码", isPresented: $showCustomRedemptionAlert) {
            TextField("请输入兑换码", text: $redemptionCodeInput)
            Button("取消", role: .cancel) {
                redemptionCodeInput = ""
            }
            Button("兑换") {
                print("DEBUG: User entered code: \(redemptionCodeInput)") // Debug log
                if subscriptionManager.redeemCode(redemptionCodeInput) {
                    subscriptionManager.errorMessage = "兑换成功！"
                    showCustomRedemptionAlert = false // Close alert on success
                } else {
                    // If internal redemption fails, ask if they want to try App Store
                    // For now, just show error
                    print("DEBUG: Redemption failed for code: \(redemptionCodeInput)") // Debug log
                    subscriptionManager.errorMessage = "无效的兑换码"
                }
                redemptionCodeInput = ""
            }
        } message: {
            Text("请输入活动兑换码解锁 Pro 权益")
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.bottom, 8)
            
            if subscriptionManager.isPro {
                Text("尊贵的 Pro 用户")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                
                if let expiryDate = subscriptionManager.expirationDate {
                    Text("有效期至：\(expiryDate.formatted(date: .long, time: .omitted))")
                        .font(Theme.bodyFont)
                        .foregroundColor(Theme.textSecondary)
                } else {
                    Text("永久会员")
                        .font(Theme.bodyFont)
                        .foregroundColor(Theme.textSecondary)
                }
            } else {
                Text("解锁 FlashMo Pro")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                
                Text("释放全部潜能，掌握每一份数据")
                    .font(Theme.bodyFont)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }
    
    private var comparisonSection: some View {
        VStack(spacing: 20) {
            // Table Header
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    Text("权益对比")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textPrimary)
                        .frame(width: geometry.size.width * 0.36, alignment: .leading) // 36% width
                    
                    Text("免费用户")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textSecondary)
                        .frame(width: geometry.size.width * 0.32) // 32% width, centered
                    
                    Text("Pro 用户")
                        .font(.headline)
                        .fontWeight(.black) // Extra bold for Pro
                        .foregroundColor(Theme.primary)
                        .frame(width: geometry.size.width * 0.32) // 32% width, centered
                }
            }
            .frame(height: 30) // Fixed height for header row
            .padding(.horizontal)
            
            VStack(spacing: 24) {
                // 1. 快速输入
                comparisonCategory(title: "快速输入", icon: "bolt.fill", color: .blue, rows: [
                    ("追踪项目数量", " 5 个", "无限数量"),
                    ("多用户管理", " 1 个", "无限数量"),
                    ("记录图片附件", " 1 张", "无限数量"),
                    ("语音输入", "标配 ", "标配")
                ])
                
                // 2. AI 智能
                comparisonCategory(title: "AI 智能", icon: "brain.head.profile", color: .purple, rows: [
                    ("AI对话", "20次/日", "无限次数"),
                    ("智能周期总结", "不支持", "多周期回顾"),
                    ("复杂意图识别", "单意图", "多意图查询"),
                    ("AI情感陪伴", "基础回复", "鼓励建议")
                ])
                
                // 3. 分析洞察
                comparisonCategory(title: "分析洞察", icon: "chart.xyaxis.line", color: .orange, rows: [
                    ("历史数据范围", "7天数据", "全部数据"),
                    ("高级图表分析", "基础图表", "多指标分析"),
                    ("AI趋势预测", "不支持", "智能预测趋势")
                ])
                
                // 4. 安全工具
                comparisonCategory(title: "安全工具", icon: "lock.shield.fill", color: .green, rows: [
                    ("iCloud 同步", "标配", "标配"),
                    ("安全锁 (FaceID)", "不支持", "支持"),
                    ("高级数据导出", "基础CSV", "多种格式"),
                    ("个性化图标", "默认图标", "限定图标")
                ])
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.surface)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
            )
        }
        .padding(.horizontal)
    }
    
    private func comparisonCategory(title: String, icon: String, color: Color, rows: [(String, String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(color)
                    .clipShape(Circle())
                    
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)
            }
            .padding(.bottom, 6)
            
            ForEach(rows.indices, id: \.self) { index in
                let row = rows[index]
                GeometryReader { geometry in
                    HStack(alignment: .center, spacing: 0) { // Center vertical alignment
                        Text(row.0)
                            .font(.system(size: 14))
                            .foregroundColor(Theme.textSecondary)
                            .frame(width: geometry.size.width * 0.36, alignment: .leading) // Match header 36%
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Text(row.1)
                            .font(.system(size: 13, weight: .bold)) // Bolder and larger
                            .foregroundColor(Theme.textSecondary.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .frame(width: geometry.size.width * 0.32) // Match header 32%
                        
                        Text(row.2)
                            .font(.system(size: 13, weight: .heavy)) // Even bolder
                            .foregroundColor(color) // Use category color for Pro features
                            .multilineTextAlignment(.center)
                            .frame(width: geometry.size.width * 0.32) // Match header 32%
                    }
                }
                .frame(minHeight: 32) // Minimum height for row to accommodate content
                
                if index < rows.count - 1 {
                    Divider()
                        .opacity(0.5)
                }
            }
        }
    }
    
    private var planSelectionSection: some View {
        VStack(spacing: 12) {
            if subscriptionManager.isLoading {
                ProgressView()
                    .padding()
            } else if subscriptionManager.products.isEmpty {
                // Error State
                VStack(spacing: 8) {
                    Text("无法加载商品")
                        .font(Theme.captionFont)
                    Button("重试") {
                        Task { await subscriptionManager.loadProducts() }
                    }
                }
            } else {
                ForEach(subscriptionManager.products) { product in
                    PlanCard(
                        product: product,
                        isSelected: selectedProduct?.id == product.id,
                        action: { selectedProduct = product }
                    )
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var footerLinksSection: some View {
        VStack(spacing: 16) {
            // Redemption Code
            Button {
                showCustomRedemptionAlert = true
            } label: {
                HStack(spacing: 12) {
                    // Gift Icon Circle
                    Circle()
                        .fill(Theme.primary.opacity(0.1))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "gift.fill")
                                .foregroundColor(Theme.primary)
                                .font(.system(size: 20))
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("兑换优惠码")
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                        Text("已有兑换码？点击此处输入")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Text("去兑换")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.primary.opacity(0.1))
                        .cornerRadius(16)
                }
                .padding(16)
                .background(Theme.surface)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Theme.primary.opacity(0.1), lineWidth: 1)
                )
            }
            .padding(.horizontal)
            
            // Restore Purchase
            Button("恢复购买") {
                Task { await subscriptionManager.restorePurchases() }
            }
            .font(Theme.captionFont)
            .foregroundColor(Theme.textSecondary)
        }
    }
    
    private var purchaseButtonSection: some View {
        VStack(spacing: 8) {
            Button {
                if let product = selectedProduct {
                    Task {
                        await subscriptionManager.purchase(product)
                    }
                }
            } label: {
                HStack {
                    if subscriptionManager.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text(buttonTitle)
                            .fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedProduct == nil ? Color.gray : Color.green)
                .foregroundColor(.white)
                .cornerRadius(Theme.cornerRadius)
            }
            .disabled(selectedProduct == nil || subscriptionManager.isLoading)
            
            HStack(spacing: 4) {
                Text("确认购买即表示您同意")
                    .foregroundColor(Theme.textSecondary)
                
                NavigationLink(destination: UserAgreementView()) {
                    Text("《用户协议》")
                        .foregroundColor(Theme.primary)
                }
                
                Text("和")
                    .foregroundColor(Theme.textSecondary)
                
                NavigationLink(destination: PrivacyPolicyView()) {
                    Text("《隐私政策》")
                        .foregroundColor(Theme.primary)
                }
            }
            .font(.system(size: 10))
        }
        .padding()
        .background(Theme.surfaceElevated.ignoresSafeArea())
        .shadow(color: Color.black.opacity(0.1), radius: 10, y: -5)
    }
    
    private var buttonTitle: String {
        guard let product = selectedProduct else { return "选择方案" }
        
        // Check for intro offer
        if let subscription = product.subscription,
           let offer = subscription.introductoryOffer,
           offer.paymentMode == .payAsYouGo || offer.paymentMode == .payUpFront || offer.paymentMode == .freeTrial {
            return "开始体验" // Simplified, can be more specific
        }
        
        return "立即订阅"
    }
}

// MARK: - Subviews

struct PlanCard: View {
    let product: Product
    let isSelected: Bool
    let action: () -> Void
    
    var isYearly: Bool { product.id.contains("yearly") }
    var isLifetime: Bool { product.id.contains("lifetime") }
    
    var introOfferDescription: String? {
        if let subscription = product.subscription,
           let offer = subscription.introductoryOffer {
            if offer.paymentMode == .payAsYouGo || offer.paymentMode == .payUpFront {
                 // Format: "首月 ¥1.00"
                return "\(offer.period.value)\(unitName(offer.period.unit))特惠 \(product.displayPrice)"
            } else if offer.paymentMode == .freeTrial {
                return "免费试用 \(offer.period.value) \(unitName(offer.period.unit))"
            }
        }
        return nil
    }
    
    func unitName(_ unit: Product.SubscriptionPeriod.Unit) -> String {
        switch unit {
        case .day: return "天"
        case .week: return "周"
        case .month: return "个月"
        case .year: return "年"
        @unknown default: return ""
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                // Radio Circle
                Image(systemName: isSelected ? "circle.inset.filled" : "circle")
                    .foregroundColor(isSelected ? Theme.primary : Theme.textSecondary)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(product.displayName)
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                        
                        if isYearly {
                            Text("推荐")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.yellow)
                                .foregroundColor(.black)
                                .clipShape(Capsule())
                        }
                    }
                    
                    if let intro = introOfferDescription {
                        Text(intro)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(Theme.primary)
                    } else if isYearly {
                         // Calculate monthly equivalent roughly if needed, or just description
                        Text(product.description)
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    } else {
                        Text(product.description)
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(product.displayPrice)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(isSelected ? Theme.primary : Theme.textPrimary)
                    
                    if isYearly {
                        Text("平均 ¥7.3/月") // Hardcoded calculation for visual, dynamic is complex
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Theme.primary.opacity(0.05) : Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Theme.primary : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Extensions

extension View {
    @ViewBuilder
    func safeOfferCodeRedemption(isPresented: Binding<Bool>, onCompletion: @escaping (Result<Void, Error>) -> Void) -> some View {
        if #available(iOS 16.0, *) {
            self.offerCodeRedemption(isPresented: isPresented, onCompletion: onCompletion)
        } else {
            self
        }
    }
}
