import SwiftUI

struct ModelsView: View {
    @State private var showNewModel = false
    @State private var showEditModel = false
    @State private var selectedItem: TrackerItem?
    @State private var items: [TrackerItem] = []
    @State private var isLoading = true
    
    @State private var showingPaywall = false
    
    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    ProgressView("加载中...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                } else if items.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "square.grid.3x3")
                        .font(.system(size: 48))
                        .foregroundColor(Theme.textSecondary)
                    
                        Text("暂无追踪项目")
                            .font(Theme.bodyFont)
                            .foregroundColor(Theme.textSecondary)
                    
                        Text("点击右上角新增按钮创建您的第一个追踪项目")
                            .font(Theme.captionFont)
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(items) { item in
                        HStack {
                            Image(systemName: item.icon ?? "doc.text.fill")
                                .foregroundColor(Color(hex: item.color ?? "#007AFF"))
                                .frame(width: 24, height: 24)
                            
                            VStack(alignment: .leading) {
                                Text(item.name)
                                    .font(Theme.bodyFont)
                                    .foregroundColor(Theme.textPrimary)
                                if let group = item.group {
                                    Text(group)
                                        .font(Theme.captionFont)
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }
                            
                            Spacer()
                            
                            if let unit = item.unit {
                                Text(unit)
                                    .font(Theme.captionFont)
                                    .foregroundColor(Theme.textSecondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Theme.surfaceElevated)
                                    .cornerRadius(4)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedItem = item
                            showEditModel = true
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
            }
            .navigationTitle("追踪项目")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("新增") {
                        if SubscriptionManager.shared.canCreateTracker(currentItemCount: items.count) {
                            showNewModel = true
                        } else {
                            showingPaywall = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showNewModel, onDismiss: { loadItems() }) {
                NewModelView()
            }
            .sheet(isPresented: $showEditModel, onDismiss: { loadItems() }) {
                if let item = selectedItem {
                    ModelEditView(existingItem: item)
                }
            }
            .sheet(isPresented: $showingPaywall) {
                SubscriptionView()
            }
            .onAppear {
                loadItems()
            }
        }
    }
    
    private func loadItems() {
        Task {
            do {
                let fetched = try await CoreDataManager.shared.fetchTrackerItems()
                await MainActor.run {
                    self.items = fetched
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    print("加载项目失败: \(error)")
                }
            }
        }
    }
    
    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let item = items[index]
            Task {
                try? await CoreDataManager.shared.deleteTrackerItem(item)
                await MainActor.run {
                    if let idx = items.firstIndex(of: item) {
                        items.remove(at: idx)
                    }
                }
            }
        }
    }
}

#Preview {
    ModelsView()
}
