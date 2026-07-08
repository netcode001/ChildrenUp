import SwiftUI

struct HistoryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var records: [TrackerRecord] = []
    @State private var modelMap: [UUID: TrackerItem] = [:]
    @State private var isLoading = true
    
    // Filters
    @State private var searchText: String = "" // Matches Item Name or Note
    @State private var selectedTimeRange: TimeRangeOption = .all
    @State private var customStartDate: Date = Date().addingTimeInterval(-86400 * 30)
    @State private var customEndDate: Date = Date()
    @State private var showDatePicker = false
    
    enum TimeRangeOption: String, CaseIterable {
        case all = "全部"
        case thisWeek = "本周"
        case thisMonth = "本月"
        case custom = "自定义"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search & Filter Header
                    VStack(spacing: 12) {
                        // Search Bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(Theme.textSecondary)
                            TextField("搜索名称或备注...", text: $searchText)
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
                        .background(Theme.surface)
                        .cornerRadius(10)
                        
                        // Filter Row
                        HStack {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(TimeRangeOption.allCases, id: \.self) { option in
                                        Button {
                                            withAnimation {
                                                selectedTimeRange = option
                                                if option == .custom {
                                                    showDatePicker = true
                                                }
                                            }
                                        } label: {
                                            Text(option.rawValue)
                                                .font(Theme.subheadlineFont)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(selectedTimeRange == option ? Theme.primary : Theme.surface)
                                                .foregroundColor(selectedTimeRange == option ? .white : Theme.textPrimary)
                                                .cornerRadius(20)
                                        }
                                    }
                                }
                            }
                        }
                        
                        if selectedTimeRange == .custom {
                            HStack {
                                DatePicker("开始", selection: $customStartDate, displayedComponents: .date)
                                    .labelsHidden()
                                Text("-")
                                DatePicker("结束", selection: $customEndDate, displayedComponents: .date)
                                    .labelsHidden()
                            }
                            .font(Theme.captionFont)
                        }
                    }
                    .padding()
                    .background(Theme.background)
                    
                    // List
                    if isLoading {
                        ProgressView()
                            .padding(.top, 50)
                        Spacer()
                    } else if filteredRecords.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundColor(Theme.textSecondary)
                            Text("没有找到相关记录")
                                .font(Theme.subheadlineFont)
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding(.top, 50)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredRecords) { record in
                                    HistoryRecordRow(record: record, item: modelMap[record.itemId])
                                        .padding(.horizontal)
                                }
                            }
                            .padding(.vertical)
                        }
                    }
                }
            }
            .navigationTitle("历史记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear {
                loadData()
            }
        }
    }
    
    private var filteredRecords: [TrackerRecord] {
        records.filter { record in
            // 1. Time Filter
            let dateMatch: Bool
            switch selectedTimeRange {
            case .all:
                dateMatch = true
            case .thisWeek:
                dateMatch = Calendar.current.isDate(record.date, equalTo: Date(), toGranularity: .weekOfYear)
            case .thisMonth:
                dateMatch = Calendar.current.isDate(record.date, equalTo: Date(), toGranularity: .month)
            case .custom:
                dateMatch = record.date >= Calendar.current.startOfDay(for: customStartDate) &&
                           record.date <= Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: customEndDate)!
            }
            if !dateMatch { return false }
            
            // 2. Search Text (Name or Note)
            if searchText.isEmpty { return true }
            
            let item = modelMap[record.itemId]
            let nameMatch = item?.name.localizedCaseInsensitiveContains(searchText) ?? false
            let noteMatch = record.note?.localizedCaseInsensitiveContains(searchText) ?? false
            
            return nameMatch || noteMatch
        }
    }
    
    private func loadData() {
        Task {
            do {
                // Load all items for mapping
                let items = try await CoreDataManager.shared.fetchTrackerItems()
                var map: [UUID: TrackerItem] = [:]
                for item in items { map[item.id] = item }
                
                // Load all records (or reasonably large set, e.g., last year?)
                // User said "All records". Assuming local DB can handle it.
                // Fetching all might be heavy if > 10k records. But for personal tracker usually fine.
                let allRecords = try await CoreDataManager.shared.fetchRecords(from: nil, to: nil)
                
                await MainActor.run {
                    self.modelMap = map
                    // Sort by date descending (newest first)
                    self.records = allRecords.sorted { $0.date > $1.date }
                    self.isLoading = false
                }
            } catch {
                print("Error loading history: \(error)")
                await MainActor.run { self.isLoading = false }
            }
        }
    }
}

struct HistoryRecordRow: View {
    let record: TrackerRecord
    let item: TrackerItem?
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: item?.icon ?? "doc.text.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Theme.accent)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item?.name ?? "未知记录")
                        .font(Theme.subheadlineFont)
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    Text(formatDate(record.date))
                        .font(Theme.captionFont)
                        .foregroundColor(Theme.textSecondary)
                }
                
                HStack {
                    if let unit = item?.unit {
                        Text("\(String(format: "%.1f", record.value)) \(unit)")
                            .font(Theme.bodyFont)
                            .foregroundColor(Theme.textPrimary)
                    } else {
                        Text("\(String(format: "%.1f", record.value))")
                            .font(Theme.bodyFont)
                            .foregroundColor(Theme.textPrimary)
                    }
                    
                    if let note = record.note, !note.isEmpty {
                        Text(note)
                            .font(Theme.captionFont)
                            .foregroundColor(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding()
        .background(Theme.surface)
        .cornerRadius(Theme.cornerRadius)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
            return "今天 " + formatter.string(from: date)
        } else if Calendar.current.isDateInYesterday(date) {
            formatter.dateFormat = "HH:mm"
            return "昨天 " + formatter.string(from: date)
        } else {
            formatter.dateFormat = "MM-dd HH:mm"
            return formatter.string(from: date)
        }
    }
}
