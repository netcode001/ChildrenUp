import SwiftUI

struct HeatmapView: View {
    @State private var items: [TrackerItem] = []
    @State private var selectedItemId: UUID? = nil
    @State private var records: [TrackerRecord] = []
    @State private var yearData: [Date: Double] = [:]
    @State private var isLoading = true
    
    // Grid Config
    private let columns = Array(repeating: GridItem(.fixed(16), spacing: 4), count: 53)
    private let weekDays = ["日", "一", "二", "三", "四", "五", "六"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Item Picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FilterChip(title: "全部", isSelected: selectedItemId == nil) {
                            selectedItemId = nil
                            loadData()
                        }
                        
                        ForEach(items) { item in
                            FilterChip(title: item.name, isSelected: selectedItemId == item.id) {
                                selectedItemId = item.id
                                loadData()
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top)
                
                // Heatmap Container
                VStack(alignment: .leading, spacing: 8) {
                    Text("年度贡献")
                        .font(Theme.headlineFont)
                        .foregroundColor(Theme.textPrimary)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 4) {
                            // Weekday Labels
                            /*
                            HStack(spacing: 4) {
                                ForEach(weekDays, id: \.self) { day in
                                    Text(day)
                                        .font(.system(size: 10))
                                        .frame(width: 16, height: 16)
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }
                             */
                            
                            // Grid
                            // We need to organize data by (DayOfWeek, WeekOfYear)
                            // But standard Github graph is Column=Week, Row=Day
                            
                            HStack(spacing: 4) {
                                // Labels Column
                                VStack(spacing: 4) {
                                    ForEach(0..<7) { day in
                                        Text(weekDays[day])
                                            .font(.system(size: 10))
                                            .frame(height: 16)
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                }
                                .padding(.trailing, 4)
                                
                                // Weeks
                                ForEach(0..<52) { week in
                                    VStack(spacing: 4) {
                                        ForEach(0..<7) { day in
                                            if let date = getDate(week: week, day: day), date <= Date() {
                                                let value = yearData[Calendar.current.startOfDay(for: date)] ?? 0
                                                RoundedRectangle(cornerRadius: 2)
                                                    .fill(color(for: value))
                                                    .frame(width: 16, height: 16)
                                            } else {
                                                Color.clear
                                                    .frame(width: 16, height: 16)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                        .fill(Theme.surface)
                )
                .padding(.horizontal)
                
                // Stats
                HStack(spacing: 20) {
                    StatBox(title: "活跃天数", value: "\(yearData.count)")
                    StatBox(title: "最长连续", value: "\(calculateStreak())")
                }
                .padding(.horizontal)
            }
        }
        .onAppear {
            loadItems()
            loadData()
        }
    }
    
    private func loadItems() {
        Task {
            do {
                let all = try await CoreDataManager.shared.fetchTrackerItems()
                await MainActor.run {
                    self.items = all
                }
            } catch {
                print("Failed to load items: \(error)")
            }
        }
    }
    
    private func loadData() {
        isLoading = true
        Task {
            do {
                let calendar = Calendar.current
                let now = Date()
                let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: now)!
                
                let allRecords = try await CoreDataManager.shared.fetchRecords(from: oneYearAgo, to: now)
                
                let filtered = selectedItemId == nil ? allRecords : allRecords.filter { $0.itemId == selectedItemId }
                
                var map: [Date: Double] = [:]
                for record in filtered {
                    let day = calendar.startOfDay(for: record.date)
                    map[day, default: 0] += record.value
                }
                
                await MainActor.run {
                    self.yearData = map
                    self.isLoading = false
                }
            } catch {
                print("Failed to load heatmap data: \(error)")
                await MainActor.run { isLoading = false }
            }
        }
    }
    
    private func getDate(week: Int, day: Int) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        // Calculate start date (1 year ago adjusted to start of week)
        let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: now)!
        // Adjust to Sunday (or start of week)
        let weekday = calendar.component(.weekday, from: oneYearAgo)
        let startOffset = 1 - weekday // Assuming Sunday is 1
        let startDate = calendar.date(byAdding: .day, value: startOffset, to: oneYearAgo)!
        
        return calendar.date(byAdding: .day, value: (week * 7) + day, to: startDate)
    }
    
    private func color(for value: Double) -> Color {
        if value == 0 { return Theme.surfaceElevated }
        // Simple scale for now. Ideally should be relative to max value.
        // Or if "All" is selected (count based), else value based.
        
        let intensity: Double
        if selectedItemId == nil {
            // Count based (frequency) - maybe value represents count if we summed 1s? 
            // Actually in loadData we sum 'value'. For "All", value might be meaningless if units differ.
            // For "All", we should probably count records?
            // Let's assume for "All", we care about "Did I track anything?"
            intensity = value > 0 ? 1.0 : 0.0
        } else {
            // Value based. Let's normalize against an arbitrary max for now or calculate max.
            let maxVal = yearData.values.max() ?? 100
            intensity = min(value / (maxVal * 0.5), 1.0) // Saturate at 50% of max
        }
        
        return Theme.primary.opacity(0.2 + (0.8 * intensity))
    }
    
    private func calculateStreak() -> Int {
        // Simple calculation
        let sortedDates = yearData.keys.sorted()
        var maxStreak = 0
        var currentStreak = 0
        var prevDate: Date?
        
        let calendar = Calendar.current
        
        for date in sortedDates {
            if let prev = prevDate {
                if calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: prev)!) {
                    currentStreak += 1
                } else {
                    currentStreak = 1
                }
            } else {
                currentStreak = 1
            }
            maxStreak = max(maxStreak, currentStreak)
            prevDate = date
        }
        return maxStreak
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.captionFont)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? Theme.primary : Theme.surfaceElevated)
                )
                .foregroundColor(isSelected ? .white : Theme.textPrimary)
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Theme.captionFont)
                .foregroundColor(Theme.textSecondary)
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Theme.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                .fill(Theme.surface)
        )
    }
}
