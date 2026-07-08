import SwiftUI

struct EntryView: View {
    @Environment(\.dismiss) private var dismiss
    var initialSelectedItemId: UUID?
    @State private var selectedItem: TrackerItem?
    @State private var value: String = ""
    @State private var note: String = ""
    @State private var date: Date = Date()
    @State private var selectedImages: [UIImage] = []
    @State private var showImagePicker = false
    @State private var showSubmitSuccess = false
    @State private var items: [TrackerItem] = []
    @State private var showModelsSheet = false
    @State private var showNewModelSheet = false
    @State private var showErrorBanner = false
    @State private var errorText: String = ""
    @State private var recentRecords: [TrackerRecord] = []
    @State private var lastRecord: TrackerRecord?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.spacing * 1.5) {
                    if showErrorBanner {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Theme.warning)
                            Text(errorText)
                                .font(Theme.captionFont)
                                .foregroundColor(Theme.textPrimary)
                            Spacer()
                            Button("重试") { loadItems() }
                                .font(Theme.captionFont)
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                                        .fill(Theme.primary)
                                )
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                .fill(Theme.surfaceElevated)
                        )
                    }
                    // 1. 项目选择卡片
                    itemSelectionCard
                    
                    // 2. 数据录入区域
                    inputArea
                    
                    // 3. 提交按钮
                    submitButton
                    recentBar
                }
                .padding(Theme.spacing * 1.5)
            }
            .navigationTitle("数据录入")
            .navigationBarTitleDisplayMode(.large)
            .alert("提交成功", isPresented: $showSubmitSuccess) {
                Button("关闭", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("数据已成功记录")
            }
            .onAppear {
                loadItems()
            }
            .sheet(isPresented: $showModelsSheet, onDismiss: { loadItems() }) {
                ModelsView()
            }
            .sheet(isPresented: $showNewModelSheet, onDismiss: { loadItems() }) {
                NewModelView()
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(images: $selectedImages, maxCount: 3)
            }
        }
    }
    
    // MARK: - 项目选择卡片
    private var itemSelectionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "square.grid.2x2")
                    .font(.title3)
                    .foregroundColor(Theme.primary)
                
                Text("选择项目")
                    .font(Theme.headlineFont)
                    .foregroundColor(Theme.textPrimary)
                
                Spacer()
                Button("管理") { showModelsSheet = true }
                    .font(Theme.captionFont)
                    .foregroundColor(Theme.primary)
                Button("新增") { showNewModelSheet = true }
                    .font(Theme.captionFont)
                    .foregroundColor(Theme.primary)
            }
            
            // 项目选择器
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items) { item in
                        ModelSelectionButton(
                            title: item.name,
                            icon: item.icon ?? "doc.text.fill",
                            isSelected: selectedItem?.id == item.id
                        ) {
                            selectedItem = item
                            loadRecent(for: item)
                        }
                    }
                }
                .padding(.vertical, 4) // Avoid border clipping
                .padding(.horizontal, 2)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .fill(Theme.surface)
                .shadow(color: Theme.shadowColor, radius: Theme.shadowRadius, x: Theme.shadowOffset.width, y: Theme.shadowOffset.height)
        )
    }
    
    // MARK: - 数据录入区域
    private var inputArea: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "pencil.and.list.clipboard")
                    .font(.title3)
                    .foregroundColor(Theme.secondary)
                
                Text("录入数据")
                    .font(Theme.headlineFont)
                    .foregroundColor(Theme.textPrimary)
                
                Spacer()
                
                if let item = selectedItem, let unit = item.unit {
                    Text("单位: \(unit)")
                        .font(Theme.captionFont)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            
            // 录入表单
            if selectedItem != nil {
                VStack(spacing: 16) {
                    // 数值输入
                    HStack {
                        Text("数值")
                            .font(Theme.bodyFont)
                            .foregroundColor(Theme.textPrimary)
                            .frame(width: 60, alignment: .leading)
                        
                        TextField("请输入数值", text: $value)
                            .keyboardType(.decimalPad)
                            .padding(10)
                            .background(Theme.surfaceElevated)
                            .cornerRadius(Theme.cornerRadiusSmall)
                    }
                    
                    // 日期选择
                    HStack {
                        Text("日期")
                            .font(Theme.bodyFont)
                            .foregroundColor(Theme.textPrimary)
                            .frame(width: 60, alignment: .leading)
                        
                        DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "zh_CN"))
                        Spacer()
                    }
                    
                    // 图片选择
                    HStack(alignment: .top) {
                        Text("图片")
                            .font(Theme.bodyFont)
                            .foregroundColor(Theme.textPrimary)
                            .frame(width: 60, alignment: .leading)
                            .padding(.top, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(selectedImages.indices, id: \.self) { index in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: selectedImages[index])
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 60, height: 60)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        
                                        Button {
                                            selectedImages.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.white)
                                                .background(Circle().fill(Color.black.opacity(0.5)))
                                        }
                                        .offset(x: 5, y: -5)
                                    }
                                }
                                
                                if selectedImages.count < 3 {
                                    Button {
                                        showImagePicker = true
                                    } label: {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Theme.surfaceElevated)
                                                .frame(width: 60, height: 60)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                                        .foregroundColor(Theme.secondary.opacity(0.5))
                                                )
                                        
                                            Image(systemName: "plus")
                                                .font(.system(size: 24))
                                                .foregroundColor(Theme.secondary)
                                        }
                                    }
                                }
                            }
                            .padding(.top, 4)
                            .padding(.horizontal, 4)
                        }
                    }
                    
                    // 备注输入
                    HStack {
                        Text("备注")
                            .font(Theme.bodyFont)
                            .foregroundColor(Theme.textPrimary)
                            .frame(width: 60, alignment: .leading)
                        
                        TextField("可选备注", text: $note)
                            .padding(10)
                            .background(Theme.surfaceElevated)
                            .cornerRadius(Theme.cornerRadiusSmall)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("请先选择或创建一个项目")
                        .font(Theme.bodyFont)
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .fill(Theme.surface)
                .shadow(color: Theme.shadowColor, radius: Theme.shadowRadius, x: Theme.shadowOffset.width, y: Theme.shadowOffset.height)
        )
    }
    
    // MARK: - 提交按钮
    private var submitButton: some View {
        Button {
            submitData()
        } label: {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                
                Text("提交数据")
                    .font(Theme.bodyFont)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                canSubmit ? Theme.primaryGradient : LinearGradient(
                    colors: [Theme.textSecondary.opacity(0.3)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .shadow(
                color: canSubmit ? Theme.shadowColor.opacity(0.3) : .clear,
                radius: canSubmit ? 8 : 0,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!canSubmit)
        .scaleEffect(canSubmit ? 1.0 : 0.95)
        .animation(Theme.springAnimation, value: canSubmit)
    }
    
    private var recentBar: some View {
        HStack(spacing: 12) {
            if let last = lastRecord {
                Text("最近一次记录")
                    .font(Theme.captionFont)
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                Button("编辑") { prefillFrom(record: last) }
                    .font(Theme.captionFont)
                    .foregroundColor(Theme.primary)
                Button("撤销") { undoLast(record: last) }
                    .font(Theme.captionFont)
                    .foregroundColor(Theme.error)
            } else {
                Text("暂无最近记录")
                    .font(Theme.captionFont)
                    .foregroundColor(Theme.textSecondary)
                Spacer()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .fill(Theme.surfaceElevated)
        )
    }
    
    private var canSubmit: Bool {
        selectedItem != nil && !value.isEmpty && Double(value) != nil
    }
    
    private func loadItems() {
        Task {
            do {
                let fetched = try await CoreDataManager.shared.fetchTrackerItems()
                await MainActor.run {
                    var allItems = fetched
                    
                    if let initialId = initialSelectedItemId, 
                       let found = allItems.first(where: { $0.id == initialId }) {
                        // Priority 1: Use passed ID
                        selectedItem = found
                        loadRecent(for: found)
                        
                        // Move selected item to first position
                        if let index = allItems.firstIndex(where: { $0.id == initialId }) {
                            allItems.remove(at: index)
                            allItems.insert(found, at: 0)
                        }
                    } else if selectedItem == nil, let first = allItems.first {
                        // Priority 2: Default to first
                        selectedItem = first
                        loadRecent(for: first)
                    }
                    
                    items = allItems
                    showErrorBanner = false
                }
            } catch {
                await MainActor.run {
                    items = []
                    errorText = "加载项目失败，请重试"
                    showErrorBanner = true
                }
            }
        }
    }
    
    private func loadRecent(for item: TrackerItem) {
        Task {
            do {
                let list = try await CoreDataManager.shared.fetchTrackerRecords(for: item.id)
                await MainActor.run {
                    recentRecords = list
                    lastRecord = list.first
                }
            } catch {
                await MainActor.run {
                    recentRecords = []
                    lastRecord = nil
                }
            }
        }
    }
    
    private func submitData() {
        guard let item = selectedItem, let val = Double(value) else { return }
        
        let imagesData = selectedImages.compactMap { $0.jpegData(compressionQuality: 0.7) }
        
        let record = TrackerRecord(
            itemId: item.id,
            value: val,
            date: date,
            note: note.isEmpty ? nil : note,
            images: imagesData.isEmpty ? nil : imagesData
        )
        
        Task {
            do {
                try await CoreDataManager.shared.saveTrackerRecord(record)
                await MainActor.run {
                    showSubmitSuccess = true
                    lastRecord = record
                    // Reset input but keep item selected
                    value = ""
                    note = ""
                    selectedImages = []
                    date = Date()
                }
            } catch {
                await MainActor.run {
                    showSubmitSuccess = false
                }
            }
        }
    }
    
    private func prefillFrom(record: TrackerRecord) {
        value = String(record.value)
        note = record.note ?? ""
        date = record.date
        if let imagesData = record.images {
            selectedImages = imagesData.compactMap { UIImage(data: $0) }
        } else {
            selectedImages = []
        }
    }
    
    private func undoLast(record: TrackerRecord) {
        Task {
            do {
                try await CoreDataManager.shared.deleteTrackerRecord(record)
                await MainActor.run {
                    lastRecord = nil
                }
            } catch {
                await MainActor.run {}
            }
        }
    }
}

#Preview {
    EntryView()
}
