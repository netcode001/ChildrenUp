import SwiftUI

struct InsightView: View {
    @State private var selectedTab: Int = 0
    
    @State private var showingPaywall = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("视图", selection: $selectedTab) {
                    Text("趋势").tag(0)
                    Text("关联").tag(1)
                    Text("热力").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()
                .background(Theme.surface)
                
                TabView(selection: $selectedTab) {
                    TrendDetailView(isEmbedded: true)
                        .tag(0)
                    
                    if SubscriptionManager.shared.isPro {
                        CorrelationView()
                            .tag(1)
                        
                        HeatmapView()
                            .tag(2)
                    } else {
                        ProFeaturePlaceholder(title: "关联分析", icon: "arrow.triangle.merge", description: "解锁 Pro 会员，分析多项数据间的相关性，发现隐藏规律。")
                            .tag(1)
                        
                        ProFeaturePlaceholder(title: "热力图", icon: "square.grid.3x3.fill", description: "解锁 Pro 会员，查看年度数据分布，直观了解记录习惯。")
                            .tag(2)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("成长洞察")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ProFeaturePlaceholder: View {
    let title: String
    let icon: String
    let description: String
    @State private var showPaywall = false
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(Theme.secondary)
                .padding()
                .background(
                    Circle()
                        .fill(Theme.surfaceElevated)
                        .frame(width: 120, height: 120)
                )
            
            Text(title)
                .font(Theme.titleFont)
                .foregroundColor(Theme.textPrimary)
            
            Text(description)
                .font(Theme.bodyFont)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                showPaywall = true
            } label: {
                HStack {
                    Text("升级到 Pro")
                    Image(systemName: "crown.fill")
                }
                .font(Theme.headlineFont)
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(Theme.accent)
                .cornerRadius(25)
            }
            .padding(.top, 16)
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showPaywall) {
            SubscriptionView()
        }
    }
}

#Preview {
    InsightView()
}
