//
//  DataView.swift
//  DataTracker
//
//  Created by Assistant on 2025/11/13.
//

import SwiftUI
import Charts

struct DataView: View {
    @State private var timeRange: TimeRange = .week
    @State private var selectedCategory: String? = nil
    @State private var categories: [String] = []
    
    @State private var totalRecords: Int = 0
    @State private var activeDays: Int = 0
    @State private var dailyCounts: [DailyCount] = []
    @State private var categoryDistribution: [CategoryCount] = []
    @State private var isLoading = false
    
    // For "All" category option
    private let allCategory = "我的"
    
    enum TimeRange: String, CaseIterable {
        case today = "今日"
        case week = "本周"
        case month = "本月"
        case year = "今年"
        
        var days: Int {
            switch self {
            case .today: return 1
            case .week: return 7
            case .month: return 30
            case .year: return 365
            }
        }
    }
    
    struct DailyCount: Identifiable {
        let id = UUID()
        let date: Date
        let count: Int
        let label: String
    }
    
    struct CategoryCount: Identifiable {
        let id = UUID()
        let name: String
        let count: Int
        let color: Color
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.spacing * 1.5) {
                    // 1. Filter Section
                    filterSection
                    
                    if isLoading {
                        ProgressView()
                            .padding(.top, 50)
                    } else {
                        // 2. Summary Cards
                        summarySection
                        
                        // 3. Trend Chart
                        trendSection
                        
                        // 4. Category Breakdown
                        categorySection
                    }
                }
                .padding(.vertical, Theme.spacing)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("数据概览")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadCategories()
                loadData()
            }
            .onChange(of: timeRange) { _, _ in loadData() }
            .onChange(of: selectedCategory) { _, _ in loadData() }
            .refreshable {
                loadData()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var filterSection: some View {
        VStack(spacing: 12) {
            // Time Range Picker
            Picker("时间范围", selection: $timeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Theme.padding)
            
            // Category Selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    categoryButton(title: allCategory, isSelected: selectedCategory == nil) {
                        selectedCategory = nil
                    }
                    
                    ForEach(categories, id: \.self) { cat in
                        categoryButton(title: cat, isSelected: selectedCategory == cat) {
                            selectedCategory = cat
                        }
                    }
                }
                .padding(.horizontal, Theme.padding)
            }
        }
    }
    
    private func categoryButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.captionFont)
                .foregroundColor(isSelected ? .white : Theme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Theme.primary : Theme.surface)
                )
                .overlay(
                    Capsule()
                        .stroke(Theme.surfaceElevated, lineWidth: isSelected ? 0 : 1)
                )
        }
    }
    
    private var summarySection: some View {
        HStack(spacing: Theme.spacing) {
            SummaryCard(
                title: "记录总数",
                value: "\(totalRecords)",
                unit: "条",
                icon: "doc.text.fill",
                color: Theme.primary
            )
            
            SummaryCard(
                title: "活跃天数",
                value: "\(activeDays)",
                unit: "天",
                icon: "calendar",
                color: Theme.secondary
            )
        }
        .padding(.horizontal, Theme.padding)
    }
    
    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("记录趋势")
                .font(Theme.headlineFont)
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal, Theme.padding)
            
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    if dailyCounts.isEmpty {
                        Text("暂无数据")
                            .font(Theme.captionFont)
                            .foregroundColor(Theme.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 150)
                    } else {
                        Chart {
                            ForEach(dailyCounts) { item in
                                BarMark(
                                    x: .value("日期", item.label),
                                    y: .value("数量", item.count)
                                )
                                .foregroundStyle(Theme.primaryGradient)
                                .cornerRadius(4)
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        .frame(height: 200)
                    }
                }
                .padding(12)
            }
            .padding(.horizontal, Theme.padding)
        }
    }
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("分类占比")
                .font(Theme.headlineFont)
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal, Theme.padding)
            
            if categoryDistribution.isEmpty {
                Text("暂无数据")
                    .font(Theme.captionFont)
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                VStack(spacing: 12) {
                    ForEach(categoryDistribution) { item in
                        GlassCard(padding: 12) {
                            VStack(spacing: 8) {
                                HStack {
                                    Text(item.name)
                                        .font(Theme.bodyFont)
                                        .foregroundColor(Theme.textPrimary)
                                    Spacer()
                                    Text("\(item.count) 条")
                                        .font(Theme.bodyFont)
                                        .foregroundColor(Theme.textSecondary)
                                }
                                
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Theme.surface)
                                            .frame(height: 8)
                                        
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(item.color)
                                            .frame(width: calculateWidth(count: item.count, total: totalRecords, width: geometry.size.width), height: 8)
                                    }
                                }
                                .frame(height: 8)
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.padding)
            }
        }
        .padding(.bottom, 20)
    }
    
    private func calculateWidth(count: Int, total: Int, width: CGFloat) -> CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(count) / CGFloat(total) * width
    }
    
    // MARK: - Logic
    
    private func loadCategories() {
        self.categories = CategoryManager.shared.categories
    }
    
    private func loadData() {
        isLoading = true
        Task {
            let (start, end) = getDateRange()
            
            do {
                // 1. Fetch all records in range
                let records = try await CoreDataManager.shared.fetchRecords(from: start, to: end, category: selectedCategory)
                
                // 2. Process Data
                await processRecords(records, start: start, end: end)
                
            } catch {
                print("Error loading data: \(error)")
                await MainActor.run { isLoading = false }
            }
        }
    }
    
    private func getDateRange() -> (Date?, Date?) {
        let now = Date()
        let cal = Calendar.current
        var start: Date?
        
        switch timeRange {
        case .today:
            start = cal.startOfDay(for: now)
        case .week:
            start = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now))
        case .month:
            start = cal.date(byAdding: .day, value: -29, to: cal.startOfDay(for: now))
        case .year:
            start = cal.date(byAdding: .day, value: -364, to: cal.startOfDay(for: now))
        }
        
        return (start, now)
    }
    
    private func processRecords(_ records: [TrackerRecord], start: Date?, end: Date?) async {
        let cal = Calendar.current
        
        // A. Summary Stats
        let total = records.count
        
        // Active Days
        let uniqueDays = Set(records.map { cal.startOfDay(for: $0.date) })
        let active = uniqueDays.count
        
        // B. Daily Counts (Trend)
        var daily: [DailyCount] = []
        
        if timeRange == .today {
            // Group by Hour
            var countsByHour: [Date: Int] = [:]
            for record in records {
                let components = cal.dateComponents([.year, .month, .day, .hour], from: record.date)
                if let hour = cal.date(from: components) {
                    countsByHour[hour, default: 0] += 1
                }
            }
            
            if let startDate = start {
                let now = Date()
                var curr = startDate
                // Show until next hour of now or end of day
                let endLimit = min(now, cal.date(bySetting: .hour, value: 23, of: startDate)!)
                
                while curr <= endLimit {
                    let count = countsByHour[curr] ?? 0
                    let formatter = DateFormatter()
                    formatter.dateFormat = "H:00"
                    daily.append(DailyCount(date: curr, count: count, label: formatter.string(from: curr)))
                    curr = cal.date(byAdding: .hour, value: 1, to: curr)!
                }
            }
        } else if timeRange == .year {
             daily = groupRecordsByMonth(records)
        } else {
            // Group by Day (Week, Month)
            var countsByDay: [Date: Int] = [:]
            for record in records {
                let day = cal.startOfDay(for: record.date)
                countsByDay[day, default: 0] += 1
            }
            
            if let startDate = start, let endDate = end {
                var curr = startDate
                let endLimit = cal.startOfDay(for: endDate)
                
                while curr <= endLimit {
                    let count = countsByDay[curr] ?? 0
                    let label = formatLabel(date: curr)
                    daily.append(DailyCount(date: curr, count: count, label: label))
                    curr = cal.date(byAdding: .day, value: 1, to: curr)!
                }
            }
        }
        
        // C. Category Distribution
        // Need to fetch items to know their group
        // Optimization: We can fetch all items once or rely on record.itemId
        // Since we need group name, we need TrackerItem.
        // We can fetch all items and map.
        
        let allItems = try? await CoreDataManager.shared.fetchTrackerItems()
        let itemMap = Dictionary(uniqueKeysWithValues: (allItems ?? []).map { ($0.id, $0) })
        
        var catCounts: [String: Int] = [:]
        for record in records {
            if let item = itemMap[record.itemId] {
                let groupName = item.group ?? "未知"
                catCounts[groupName, default: 0] += 1
            } else {
                catCounts["未知", default: 0] += 1
            }
        }
        
        let sortedCats = catCounts.map { key, value in
            CategoryCount(
                name: key,
                count: value,
                color: getColor(for: key)
            )
        }.sorted { $0.count > $1.count }
        
        await MainActor.run {
            self.totalRecords = total
            self.activeDays = active
            self.dailyCounts = daily
            self.categoryDistribution = sortedCats
            self.isLoading = false
        }
    }
    
    private func groupRecordsByMonth(_ records: [TrackerRecord]) -> [DailyCount] {
        let cal = Calendar.current
        var counts: [Date: Int] = [:]
        
        // Init last 12 months
        let now = Date()
        for i in 0..<12 {
            if let date = cal.date(byAdding: .month, value: -i, to: now) {
                let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: date))!
                counts[startOfMonth] = 0
            }
        }
        
        for record in records {
            let components = cal.dateComponents([.year, .month], from: record.date)
            if let startOfMonth = cal.date(from: components) {
                counts[startOfMonth, default: 0] += 1
            }
        }
        
        return counts.sorted { $0.key < $1.key }.map { date, count in
            let formatter = DateFormatter()
            formatter.dateFormat = "M月"
            return DailyCount(date: date, count: count, label: formatter.string(from: date))
        }
    }
    
    private func formatLabel(date: Date) -> String {
        let formatter = DateFormatter()
        switch timeRange {
        case .today: formatter.dateFormat = "HH:mm" // Actually grouping by hour would be better for Today
        case .week: formatter.dateFormat = "E"
        case .month: formatter.dateFormat = "d"
        case .year: formatter.dateFormat = "M月"
        }
        return formatter.string(from: date)
    }
    
    private func getColor(for category: String) -> Color {
        switch category {
        case "健身": return .blue
        case "饮食": return .green
        case "健康": return .red
        case "财务": return .orange
        case "考试/学习": return .purple
        case "工作/效率": return .indigo
        case "兴趣/其他": return .pink
        default: return .gray
        }
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.1))
                            .frame(width: 32, height: 32)
                        Image(systemName: icon)
                            .foregroundColor(color)
                            .font(.system(size: 14))
                    }
                    Text(title)
                        .font(Theme.captionFont)
                        .foregroundColor(Theme.textSecondary)
                }
                
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(value)
                        .font(Theme.displayFont)
                        .foregroundColor(Theme.textPrimary)
                    Text(unit)
                        .font(Theme.smallFont)
                        .foregroundColor(Theme.textTertiary)
                }
            }
            .padding(16)
        }
    }
}

#Preview {
    DataView()
}
