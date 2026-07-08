import SwiftUI
import UniformTypeIdentifiers

struct DashboardView: View {
    @ObservedObject var categoryManager = CategoryManager.shared
    @StateObject private var userManager = UserManager.shared
    @State private var selectedCategory = "我的"
    @State private var pinned: Set<String> = DashboardView.loadPinned()
    @State private var showEntrySheet = false
    @State private var showTrendSheet = false
    @State private var showHistorySheet = false
    @State private var searchText: String = ""
    @State private var recentRecords: [TrackerRecord] = []
    @State private var modelMap: [UUID: TrackerItem] = [:]
    @State private var categoryItems: [TrackerItem] = []
    @State private var selectedItemId: UUID? = nil
    @State private var previewData: ImagePreviewData? = nil
    @State private var showNewModelSheet = false
    
    // Avatar
    @AppStorage("userAvatarPath") private var userAvatarPath: String = ""
    @State private var avatarImage: Image?
    
    // Deletion states
    @State private var itemToDelete: TrackerItem?
    @State private var templateToDelete: TemplateItem?
    @State private var showDeleteAlert = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Fixed Top Section
                    VStack(spacing: Theme.spacing * 1.5) {
                        // 1. Header Section (Avatar + Search)
                        headerSection
                        
                        // 2. Time Range Selector (Categories)
                        timeRangeSelector
                        
                        // 3. Quick Actions (Grid)
                        quickActionsSection
                        
                        // 4. Recent Activity Header (Fixed)
                        recentActivityHeader
                    }
                    .padding(.bottom, Theme.spacing)
                    .background(Theme.background) // Ensure opaque background
                    
                    // Scrollable Content
                    ScrollView {
                        VStack(spacing: Theme.spacing * 1.5) {
                            // 5. Recent Activity List
                            recentActivityList
                        }
                        .padding(.bottom, 20)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ReloadDashboardData"))) { _ in
                loadData()
            }
            .onAppear { 
                loadData()
                loadAvatar()
            }
            .onChange(of: userAvatarPath) { _, _ in loadAvatar() }
            .onChange(of: selectedCategory) { _, _ in loadData() }
            .sheet(isPresented: $showEntrySheet, onDismiss: {
                loadData()
                selectedItemId = nil
            }) { EntryView(initialSelectedItemId: selectedItemId) }
            .sheet(isPresented: $showNewModelSheet, onDismiss: {
                loadData()
            }) {
                NewModelView(initialGroup: selectedCategory == "我的" ? nil : selectedCategory)
            }
            .sheet(isPresented: $showTrendSheet) { TrendDetailView() }
            .sheet(isPresented: $showHistorySheet) { HistoryView() }
            .sheet(item: $previewData) { data in
                ImagePreviewView(images: data.images)
            }
            .alert("确认删除", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) {
                    itemToDelete = nil
                    templateToDelete = nil
                }
                Button("删除", role: .destructive) {
                    if let item = itemToDelete {
                        Task {
                            try? await CoreDataManager.shared.deleteTrackerItem(item)
                            await MainActor.run {
                                loadData()
                            }
                        }
                    } else if let template = templateToDelete {
                        categoryManager.hideTemplate(template.name)
                    }
                    itemToDelete = nil
                    templateToDelete = nil
                }
            } message: {
                if let item = itemToDelete {
                    Text("确定要删除“\(item.name)”吗？此操作不可撤销。")
                } else if let template = templateToDelete {
                    Text("确定要移除“\(template.name)”吗？您以后可以在设置中恢复。")
                } else {
                    Text("确定要删除吗？")
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private func loadAvatar() {
        guard !userAvatarPath.isEmpty else {
            avatarImage = nil
            return
        }
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = dir.appendingPathComponent(userAvatarPath)
            if let data = try? Data(contentsOf: fileURL), let uiImage = UIImage(data: data) {
                avatarImage = Image(uiImage: uiImage)
            } else {
                avatarImage = nil
            }
        }
    }
    
    private var headerSection: some View {
        HStack(spacing: 12) {
            // Profile Button (Left)
            Menu {
                Text("切换用户")
                
                ForEach(userManager.allUsers) { user in
                    Button {
                        Task { await userManager.switchUser(to: user) }
                    } label: {
                        HStack {
                            Text(user.name)
                            if user.isCurrentUser {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                if let avatarImage {
                    avatarImage
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Theme.primary.opacity(0.3), lineWidth: 1))
                        .shadow(color: Theme.shadowColor, radius: 4, x: 0, y: 2)
                } else {
                    ZStack {
                        Circle()
                            .fill(Theme.surfaceElevated)
                            .frame(width: 44, height: 44)
                            .shadow(color: Theme.shadowColor, radius: 4, x: 0, y: 2)
                        
                        Image(systemName: "person.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Theme.primary)
                    }
                    .overlay(Circle().stroke(Theme.primary.opacity(0.3), lineWidth: 1))
                }
            }
            
            // Search Bar (Right)
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Theme.textSecondary)
                TextField("搜索...", text: $searchText)
                    .foregroundColor(Theme.textPrimary)
                    .submitLabel(.search)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
            .padding(10)
            .background(Theme.surfaceElevated)
            .cornerRadius(22)
            .shadow(color: Theme.shadowColor, radius: 2, x: 0, y: 1)
        }
        .padding(.horizontal, Theme.padding)
        .padding(.top, Theme.spacing)
    }
    
    private var timeRangeSelector: some View {
        CategoryTabBar(selectedCategory: $selectedCategory)
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacing) {
            Text("快速记录")
                .font(Theme.headlineFont)
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal, Theme.padding)
            
            let filteredCategoryItems = searchText.isEmpty ? categoryItems : categoryItems.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            let allItems = sortedItems(filteredCategoryItems)
            
            // Assuming getTemplates() returns [TemplateItem] and has a name property
            let allTemplates = getTemplates()
            let templates = searchText.isEmpty ? allTemplates : allTemplates.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: [GridItem(.fixed(80)), GridItem(.fixed(80))], spacing: 12) {
                    let displayItems: [DisplayItem] = allItems.map { .tracker($0) } + templates.map { .template($0) } + [.addModel]
                    let combinedItems = reorderForColumnMajor(displayItems)
                    
                    ForEach(combinedItems) { displayItem in
                        switch displayItem {
                        case .tracker(let item):
                            quickActionItem(item: item)
                        case .template(let template):
                            templateActionItem(template: template)
                        case .addModel:
                            addModelItem()
                        case .empty:
                            Color.clear.frame(width: 70, height: 80)
                        }
                    }
                }
                .padding(.horizontal, Theme.padding)
                .frame(height: 180)
            }
        }
    }
    
    // Enum to handle mixed types in the grid
    enum DisplayItem: Identifiable {
        case tracker(TrackerItem)
        case template(TemplateItem)
        case addModel
        case empty(UUID)
        
        var id: String {
            switch self {
            case .tracker(let item): return "tracker_\(item.id)"
            case .template(let template): return "template_\(template.id)"
            case .addModel: return "add_model"
            case .empty(let id): return "empty_\(id)"
            }
        }
    }

    private func reorderForColumnMajor(_ items: [DisplayItem]) -> [DisplayItem] {
        let allDisplayItems = items
        let count = allDisplayItems.count
        guard count > 0 else { return [] }
        
        // Fixed: Fill first row (5 items) then second row, in blocks of 10
        let itemsPerRow = 5
        let rows = 2
        let blockSize = itemsPerRow * rows
        
        // Calculate max grid index needed
        // For k items:
        // Last item index k-1
        // Block B = (k-1)/10
        // local i = (k-1)%10
        // Grid index = ...
        
        // We need to size the array to hold the last item at its correct position
        var maxGridIndex = 0
        
        for k in 0..<count {
            let B = k / blockSize
            let i = k % blockSize
            
            // Logic: fill row 0 (0..4), then row 1 (5..9)
            // r_local = i < 5 ? 0 : 1
            // c_local = i % 5
            
            // BUT LazyHGrid fills column-major:
            // (0,0), (1,0), (0,1), (1,1)...
            // grid_index = C * 2 + R
            
            let r_local = i < itemsPerRow ? 0 : 1
            let c_local = i % itemsPerRow
            
            let C = B * itemsPerRow + c_local
            let R = r_local
            
            let gridIndex = C * rows + R
            if gridIndex > maxGridIndex {
                maxGridIndex = gridIndex
            }
        }
        
        var reordered = [DisplayItem](repeating: .empty(UUID()), count: maxGridIndex + 1)
        
        for (k, item) in allDisplayItems.enumerated() {
            let B = k / blockSize
            let i = k % blockSize
            
            let r_local = i < itemsPerRow ? 0 : 1
            let c_local = i % itemsPerRow
            
            let C = B * itemsPerRow + c_local
            let R = r_local
            
            let gridIndex = C * rows + R
            if gridIndex < reordered.count {
                reordered[gridIndex] = item
            }
        }
        
        return reordered
    }
    
    private func getTemplates() -> [TemplateItem] {
        if selectedCategory != "我的" {
            let templates = categoryManager.getTemplates(for: selectedCategory)
            let existingNames = Set(categoryItems.map { $0.name })
            return templates.filter { !existingNames.contains($0.name) }
                .sorted { a, b in
                    let aPinned = pinned.contains(a.name)
                    let bPinned = pinned.contains(b.name)
                    return aPinned && !bPinned
                }
        }
        return []
    }
    
    private func sortedItems(_ items: [TrackerItem]) -> [TrackerItem] {
        return items.sorted { a, b in
            let aPinned = pinned.contains(a.name)
            let bPinned = pinned.contains(b.name)
            if aPinned && !bPinned { return true }
            if !aPinned && bPinned { return false }
            return a.name < b.name
        }
    }
    
    private func togglePin(_ item: TrackerItem) {
        togglePin(name: item.name)
    }
    
    private func togglePin(name: String) {
        if pinned.contains(name) {
            pinned.remove(name)
        } else {
            pinned.insert(name)
        }
        DashboardView.savePinned(pinned)
    }
    
    private func quickActionItem(item: TrackerItem) -> some View {
        Button {
            selectedItemId = item.id
            showEntrySheet = true
        } label: {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    let iconName = (item.icon?.isEmpty == false) ? item.icon! : "doc.text.fill"
                    Image(systemName: iconName)
                        .font(.system(size: 32)) // Larger icon
                        .foregroundColor(Theme.primary) // Brand color for active items
                        .frame(width: 56, height: 56)
                        
                    if pinned.contains(item.name) {
                        Circle()
                            .fill(Theme.secondary)
                            .frame(width: 8, height: 8)
                            .offset(x: -4, y: 4)
                    }
                }
                
                Text(item.name)
                    .font(Theme.captionFont) // Increased from smallFont
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                    .frame(width: 70)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(BounceButtonStyle())
        .contextMenu {
            Button {
                togglePin(item)
            } label: {
                Label(pinned.contains(item.name) ? "取消置顶" : "置顶", systemImage: "pin")
            }
            
            Menu {
                ForEach(categoryManager.categories, id: \.self) { category in
                    Button {
                        moveItem(item, to: category)
                    } label: {
                        HStack {
                            Text(category)
                            if item.group == category {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label("移动到...", systemImage: "folder")
            }
            
            Button(role: .destructive) {
                itemToDelete = item
                templateToDelete = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showDeleteAlert = true
                }
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
    
    private func templateActionItem(template: TemplateItem) -> some View {
        Button {
            createFromTemplate(template)
        } label: {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: template.icon)
                        .font(.system(size: 32))
                        .foregroundColor(Theme.textSecondary.opacity(0.5)) // Gray for templates
                        .frame(width: 56, height: 56)
                    
                    if pinned.contains(template.name) {
                        Circle()
                            .fill(Theme.secondary)
                            .frame(width: 8, height: 8)
                            .offset(x: -4, y: 4)
                    }
                }
                
                Text(template.name)
                    .font(Theme.smallFont)
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
                    .frame(width: 70)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(BounceButtonStyle())
        .contextMenu {
            Button {
                togglePin(name: template.name)
            } label: {
                Label(pinned.contains(template.name) ? "取消置顶" : "置顶", systemImage: "pin")
            }
            
            Button(role: .destructive) {
                templateToDelete = template
                itemToDelete = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showDeleteAlert = true
                }
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
    
    private func addModelItem() -> some View {
        Button {
            showNewModelSheet = true
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Theme.surface)
                        .frame(width: 56, height: 56)
                        .shadow(color: Theme.shadowColor, radius: 4, x: 0, y: 2)
                    Image(systemName: "plus")
                        .font(.system(size: 24))
                        .foregroundColor(Theme.accent)
                }
                Text("新增模型")
                    .font(Theme.smallFont)
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
                    .frame(width: 70)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func createFromTemplate(_ template: TemplateItem) {
        let item = TrackerItem(
            name: template.name,
            group: selectedCategory,
            unit: template.unit,
            icon: template.icon,
            color: "blue"
        )
        Task {
            do {
                try await CoreDataManager.shared.saveTrackerItem(item)
                await MainActor.run {
                    loadData()
                    showEntrySheet = true
                }
            } catch {
                print("Error creating item from template: \(error)")
            }
        }
    }
    
    private var recentActivityHeader: some View {
        HStack {
            Text("最近记录")
                .font(Theme.headlineFont)
                .foregroundColor(Theme.textPrimary)
            Spacer()
            Button("查看全部") { showHistorySheet = true }
                .font(Theme.captionFont)
                .foregroundColor(Theme.primary)
        }
        .padding(.horizontal, Theme.padding)
    }
    
    private var recentActivityList: some View {
        VStack(spacing: 8) { // Reduced spacing between items
            ForEach(Array(recentRecords.enumerated()), id: \.element.id) { index, r in
                let info = formatRow(record: r)
                
                Button {
                    if let images = r.images, !images.isEmpty {
                        previewData = ImagePreviewData(images: images)
                    }
                } label: {
                    HStack(spacing: 12) {
                        // Icon (Centered)
                        ZStack {
                            Circle()
                                .fill(Theme.primary.opacity(0.1))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: info.icon)
                                .font(.system(size: 20))
                                .foregroundColor(Theme.primary)
                        }
                        
                        // Content
                        VStack(alignment: .leading, spacing: 4) {
                            // First line: Name + Note
                            HStack(alignment: .center, spacing: 8) {
                                Text(info.title)
                                    .font(Theme.subheadlineFont)
                                    .foregroundColor(Theme.textPrimary)
                                    .layoutPriority(1)
                                
                                if let note = info.note, !note.isEmpty {
                                    Text(note)
                                        .font(Theme.subheadlineFont)
                                        .foregroundColor(Theme.textSecondary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                            }
                            
                            // Second line: Value
                            if !info.valueWithUnit.isEmpty {
                                Text(info.valueWithUnit)
                                    .font(Theme.subheadlineFont)
                                    .foregroundColor(Theme.textPrimary)
                            }
                        }
                        
                        Spacer()
                        
                        // Right Section: Image + Date
                        VStack(alignment: .trailing, spacing: 4) {
                            if let images = r.images, !images.isEmpty {
                                if let firstData = images.first, let uiImage = UIImage(data: firstData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 50, height: 50)
                                        .cornerRadius(8)
                                        .clipped()
                                } else {
                                    Image(systemName: "photo")
                                        .foregroundColor(Theme.textSecondary)
                                        .font(.system(size: 24))
                                        .frame(width: 50, height: 50)
                                }
                            }
                            
                            Text(info.timestamp)
                                .font(Theme.captionFont.monospacedDigit())
                                .foregroundColor(Theme.textTertiary)
                        }
                    }
                    .padding(.vertical, 12) // Reduced vertical padding (height -20% approx)
                    .padding(.horizontal, 16)
                    .background(Theme.surface)
                    .cornerRadius(Theme.cornerRadius)
                }
                .buttonStyle(BounceButtonStyle())
            }
        }
        .padding(.horizontal, 24) // Increased horizontal padding to reduce width
    }
    
    // MARK: - Data Loading
    
    private func loadData() {
        loadRecentRecords()
        loadCategoryItems()
    }
    
    private func loadCategoryItems() {
        Task {
            do {
                let items = try await CoreDataManager.shared.fetchTrackerItems(in: selectedCategory)
                await MainActor.run {
                    self.categoryItems = items
                }
            } catch {
                print("Error loading category items: \(error)")
            }
        }
    }

    static func loadPinned() -> Set<String> {
        let arr = UserDefaults.standard.array(forKey: "dashboard_pinned") as? [String] ?? []
        return Set(arr)
    }
    
    static func savePinned(_ set: Set<String>) {
        UserDefaults.standard.set(Array(set), forKey: "dashboard_pinned")
    }
    
    private func moveItem(_ item: TrackerItem, to category: String) {
        var newItem = item
        newItem.group = category
        Task {
            try? await CoreDataManager.shared.saveTrackerItem(newItem)
            await MainActor.run {
                loadData()
            }
        }
    }
    
    private func loadRecentRecords() {
        Task {
            do {
                let items = try await CoreDataManager.shared.fetchTrackerItems()
                var map: [UUID: TrackerItem] = [:]
                for m in items { map[m.id] = m }
                let recents = try await CoreDataManager.shared.fetchRecentRecords(limit: 10, category: nil)
                await MainActor.run {
                    self.modelMap = map
                    self.recentRecords = recents
                }
            } catch {
                await MainActor.run {
                    self.recentRecords = []
                }
            }
        }
    }
    
    private func formatRow(record: TrackerRecord) -> (icon: String, title: String, valueWithUnit: String, note: String?, timestamp: String, color: Color) {
        let item = modelMap[record.itemId]
        let modelName = item?.name ?? "记录"
        var icon: String = "doc.text.fill"
        var color: Color = Theme.primary
        
        // Simple mapping
        switch modelName {
        case "学习成绩": icon = "book.fill"; color = Theme.primary
        case "体重": icon = "scalemass.fill"; color = Theme.secondary
        case "习惯打卡": icon = "checkmark.circle.fill"; color = Theme.accent
        default: icon = "doc.text.fill"; color = Theme.primary
        }
        
        if let i = item?.icon, !i.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { 
            icon = i 
        }
        
        var valueWithUnit = ""
        let valStr = String(format: "%.1f", record.value)
        if let unit = item?.unit {
            valueWithUnit = "\(valStr) \(unit)"
        } else {
            valueWithUnit = valStr
        }
        
        let formatter = DateFormatter()
        var timestamp: String
        if Calendar.current.isDateInToday(record.date) {
            formatter.dateFormat = "HH:mm"
            let timeStr = formatter.string(from: record.date)
            timestamp = "今天 \(timeStr)"
        } else {
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            timestamp = formatter.string(from: record.date)
        }
        
        return (icon, modelName, valueWithUnit, record.note, timestamp, color)
    }
}

struct ImagePreviewData: Identifiable {
    let id = UUID()
    let images: [Data]
}

struct ImagePreviewView: View {
    let images: [Data]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            TabView {
                ForEach(images.indices, id: \.self) { index in
                    if let uiImage = UIImage(data: images[index]) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .tag(index)
                    }
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
            .background(Color.black)
            .navigationTitle("查看图片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct CategoryTabBar: View {
    @Binding var selectedCategory: String
    @ObservedObject var categoryManager = CategoryManager.shared
    @State private var showAddCategoryAlert = false
    @State private var newCategoryName = ""
    @State private var draggedItem: String?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // "My" Button
                categoryButton(title: "我的", isSelected: selectedCategory == "我的")
                
                // Dynamic Categories
                ForEach(categoryManager.categories, id: \.self) { category in
                    categoryButton(title: category, isSelected: selectedCategory == category)
                        .onDrag {
                            self.draggedItem = category
                            return NSItemProvider(object: category as NSString)
                        }
                        .onDrop(of: [.text], delegate: CategoryDropDelegate(item: category, items: $categoryManager.categories, draggedItem: $draggedItem, onMove: { from, to in
                            categoryManager.moveCategory(from: from, to: to)
                        }))
                }
                
                // Add Button
                Button {
                    newCategoryName = ""
                    showAddCategoryAlert = true
                } label: {
                    Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.primary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Theme.surface)
                            .shadow(color: Theme.shadowColor, radius: 2, x: 0, y: 1)
                    )
                }
            }
            .padding(.horizontal, Theme.padding)
            .padding(.vertical, 8)
        }
        .alert("新增分组", isPresented: $showAddCategoryAlert) {
            TextField("分组名称", text: $newCategoryName)
            Button("取消", role: .cancel) { }
            Button("添加") {
                if !newCategoryName.isEmpty {
                    categoryManager.addCategory(newCategoryName)
                    // Optionally select the new category
                    // selectedCategory = newCategoryName
                }
            }
        }
    }
    
    private func categoryButton(title: String, isSelected: Bool) -> some View {
        Button {
            withAnimation(Theme.springAnimation) {
                selectedCategory = title
            }
        } label: {
            Text(title)
                .font(Theme.captionFont)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Theme.primary : Theme.surface)
                )
                .foregroundColor(isSelected ? .white : Theme.textSecondary)
                .overlay(
                    Capsule()
                        .stroke(Theme.primary.opacity(0.3), lineWidth: isSelected ? 0 : 1)
                )
                .shadow(color: isSelected ? Theme.primary.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
        }
    }
}

struct CategoryDropDelegate: DropDelegate {
    let item: String
    @Binding var items: [String]
    @Binding var draggedItem: String?
    let onMove: (IndexSet, Int) -> Void
    
    // Feedback generator for haptic feedback
    private let feedback = UIImpactFeedbackGenerator(style: .medium)
    
    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem else { return }
        if draggedItem != item {
            guard let from = items.firstIndex(of: draggedItem),
                  let to = items.firstIndex(of: item) else { return }
            
            // Trigger haptic feedback when item moves
            feedback.impactOccurred()
            
            withAnimation {
                // Adjust index for move
                let toOffset = to > from ? to + 1 : to
                onMove(IndexSet(integer: from), toOffset)
            }
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}


#Preview {
    DashboardView()
}
