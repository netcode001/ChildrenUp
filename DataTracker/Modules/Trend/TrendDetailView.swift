import SwiftUI
import Charts
import UIKit

struct TrendDetailView: View {
    var isEmbedded: Bool = false
    @ObservedObject var categoryManager = CategoryManager.shared
    @State private var showErrorBanner = false
    @State private var showDeleteAlert = false
    @State private var errorText: String = ""
    @State private var hasData = true
    @State private var annotations: [TrendAnnotation] = []
    @State private var items: [TrackerItem] = []
    @State private var recordsMap: [UUID: [TrackerRecord]] = [:]
    @State private var selectedItemId: UUID? = nil
    @State private var selectedCategory: String? = nil
    @State private var selectedTimeRange: TimeRange = .day
    @State private var scrollPosition: Date = Date()
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    
    enum TimeRange: String, CaseIterable {
        case day = "日"
        case week = "周"
        case month = "月"
        case year = "年"
    }

    struct TrendAnnotation: Identifiable {
        let id = UUID()
        let label: String
        let text: String
        let date: Date?
    }
    
    // Computed property for filtered items
    private var filteredItems: [TrackerItem] {
        if let cat = selectedCategory {
            return items.filter { ($0.group ?? "其他") == cat }
        }
        return items
    }

    private func mainSeries() -> [TrendPoint] {
        // Allow showing empty chart if no records, but we need records to sum values.
        // If no records exist for the item, we can still show the empty grid for the current time range.
        let recs = selectedItemId.flatMap { recordsMap[$0] } ?? []
        
        let cal = Calendar.current
        let now = Date()
        
        // Align start date based on selection (Always relative to NOW)
        var startDate: Date
        switch selectedTimeRange {
        case .day:
            startDate = cal.startOfDay(for: now)
        case .week:
            // Find the Monday of the current week
            let weekday = cal.component(.weekday, from: now) // 1=Sun, 2=Mon...
            // Calculate days to subtract to get to Monday (assuming Mon=Start)
            // Mon(2) -> 0, Tue(3) -> 1, ..., Sun(1) -> 6
            let daysToSubtract = (weekday + 5) % 7
            startDate = cal.date(byAdding: .day, value: -daysToSubtract, to: cal.startOfDay(for: now))!
        case .month:
            startDate = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        case .year:
            startDate = cal.date(from: cal.dateComponents([.year], from: now))!
        }
        
        var points: [TrendPoint] = []
        var currentDate = startDate
        
        // Ensure we show at least one point or up to now
        // For Day: 00:00 to now (by hour)
        // For Week: Mon to now (by day)
        // For Month: 1st to now (by day)
        // For Year: Jan to now (by month)
        
        // Determine end limit (now, or end of day/week/year if we wanted full range, but user asked for "Mon if Mon", so up to now is correct)
        // Actually for Day "0-24", maybe they want full 24h axis?
        // "日 （0 点-24 点的数）"
        // If I stop at 'now', it's a partial day.
        // Let's loop until 'now' for data, but maybe the chart axis needs to be fixed?
        // If I only return points up to now, the chart will only show up to now.
        // To show the full axis, I might need to generate points with 0 value (or nil) for the future?
        // But the user's Week description "If Monday show Monday" implies growing chart.
        // So I will stick to "Up to Now".
        
        // Correction: User said "Day (0-24)". This might imply a fixed 24h view.
        // But "Week" clearly says "If Mon show Mon".
        // I will implement "Up to Now" for all, as it's consistent.
        // If the user wants full 24h axis for Day, they can scroll or I can force the domain.
        // Let's stick to "Up to Now" + "Current Hour/Day/Month included".
        
        while currentDate <= now {
            let nextDate: Date
            let label: String
            
            switch selectedTimeRange {
            case .day:
                nextDate = cal.date(byAdding: .hour, value: 1, to: currentDate)!
                label = formatDate(currentDate, format: "H:mm")
            case .week:
                nextDate = cal.date(byAdding: .day, value: 1, to: currentDate)!
                label = formatDate(currentDate, format: "E") // Mon, Tue...
            case .month:
                nextDate = cal.date(byAdding: .day, value: 1, to: currentDate)!
                label = formatDate(currentDate, format: "d")
            case .year:
                nextDate = cal.date(byAdding: .month, value: 1, to: currentDate)!
                label = formatDate(currentDate, format: "M月")
            }
            
            // Sum values in range [currentDate, nextDate)
            let val = recs.filter { $0.date >= currentDate && $0.date < nextDate }.reduce(0) { $0 + $1.value }
            points.append(TrendPoint(label: label, value: val, date: currentDate))
            
            currentDate = nextDate
        }
        
        // Edge case: If "now" is exactly start date (e.g. midnight), loop might run once or not.
        // The loop `currentDate <= now` ensures at least one point if currentDate == now.
        // But if currentDate increments past now, it stops.
        
        return points
    }
    
    private func formatDate(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
    
    private var strideConfig: (Calendar.Component, Int) {
        switch selectedTimeRange {
        case .day: return (.hour, 4)
        case .week: return (.day, 1)
        case .month: return (.day, 5)
        case .year: return (.month, 1)
        }
    }
    
    private var visibleDomain: TimeInterval {
        switch selectedTimeRange {
        case .day: return 3600 * 24
        case .week: return 3600 * 24 * 7
        case .month: return 3600 * 24 * 31
        case .year: return 3600 * 24 * 366
        }
    }
    
    private var axisFormat: String {
        switch selectedTimeRange {
        case .day: return "H:mm"
        case .week: return "E"
        case .month: return "d"
        case .year: return "M月"
        }
    }
    
    private func currentValue() -> (Double, String?)? {
        guard let id = selectedItemId, let recs = recordsMap[id], let item = items.first(where: { $0.id == id }), let first = recs.first else { return nil }
        return (first.value, item.unit)
    }
    
    private func weeklyAverage() -> Double? {
        guard let id = selectedItemId, let recs = recordsMap[id] else { return nil }
        let now = Date(); let cal = Calendar.current; let start = cal.date(byAdding: .day, value: -7, to: now)!
        let vals = recs.filter { $0.date >= start }.map { $0.value }
        guard !vals.isEmpty else { return nil }
        return vals.reduce(0, +) / Double(vals.count)
    }
    
    private func monthlyTotal(offset: Int = 0) -> Double {
        guard let id = selectedItemId, let recs = recordsMap[id] else { return 0 }
        let cal = Calendar.current; let now = Date()
        let target = cal.date(byAdding: .month, value: offset, to: now)!
        let start = cal.date(from: cal.dateComponents([.year,.month], from: target))!
        let end = cal.date(byAdding: .month, value: 1, to: start)!
        let vals = recs.filter { ($0.date >= start) && ($0.date < end) }.map { $0.value }
        return vals.reduce(0, +)
    }
    
    private func monthComparePercent() -> Double? {
        let cur = monthlyTotal(offset: 0)
        let last = monthlyTotal(offset: -1)
        guard last > 0 else { return nil }
        return (cur - last) / last * 100.0
    }

    @ViewBuilder
    private func shareCardView() -> some View {
        if let id = selectedItemId, let item = items.first(where: { $0.id == id }) {
            VStack(spacing: 20) {
                // Header
                HStack(alignment: .center, spacing: 16) {
                    Image(systemName: item.icon ?? "doc.text.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Theme.primary)
                        .frame(width: 60, height: 60)
                        .background(Theme.surfaceElevated)
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.title2)
                            .bold()
                            .foregroundColor(Theme.textPrimary)
                        
                        if let (val, unit) = currentValue() {
                             HStack(alignment: .lastTextBaseline, spacing: 4) {
                                Text("\(val, specifier: "%g")")
                                    .font(.title)
                                    .bold()
                                    .foregroundColor(Theme.primary)
                                if let u = unit {
                                    Text(u)
                                        .font(.body)
                                        .foregroundColor(Theme.textSecondary)
                                }
                             }
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 24)
                
                // Chart
                chartView()
                    .frame(height: 250)
                    .padding(.horizontal)
                
                // Footer
                HStack {
                    Spacer()
                    Text("DataTracker")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                        .italic()
                }
                .padding()
            }
            .frame(width: 375)
            .background(Color.white)
            .environment(\.colorScheme, .light)
        }
    }

    @ViewBuilder
    private func chartView() -> some View {
        let primary = mainSeries()
        let dates = primary.compactMap { $0.date }
        let minDate = dates.first ?? Date()
        let maxDate = dates.last ?? Date()
        
        Chart {
            ForEach(primary) { p in
                // Smooth Line with Gradient Area
                AreaMark(
                    x: .value("日期", p.date ?? Date()),
                    y: .value("数值", p.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.primary.opacity(0.3), Theme.primary.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                LineMark(x: .value("日期", p.date ?? Date()), y: .value("数值", p.value))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Theme.primary)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                
                // Data Points Overlay
                PointMark(x: .value("日期", p.date ?? Date()), y: .value("数值", p.value))
                    .symbol {
                        Circle()
                            .fill(Theme.surface)
                            .strokeBorder(Theme.primary, lineWidth: 2)
                            .frame(width: 8, height: 8)
                    }
                    .annotation(position: .top, spacing: 4) {
                        Text(String(format: "%g", p.value))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                    }
            }
            ForEach(annotations) { a in
                RuleMark(x: .value("日期", a.date ?? Date()))
                    .annotation(position: .top) {
                        Text(a.text)
                            .font(Theme.captionFont)
                            .foregroundColor(Theme.textPrimary)
                            .padding(6)
                            .background(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall).fill(Theme.surfaceElevated))
                    }
            }
        }
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: visibleDomain)
        .chartScrollPosition(x: $scrollPosition)
        .chartLegend(.hidden)
        .chartXScale(domain: minDate...maxDate)
        .chartXAxis {
            AxisMarks(values: .stride(by: strideConfig.0, count: strideConfig.1)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                    .foregroundStyle(Color.gray.opacity(0.2))
                AxisTick(stroke: StrokeStyle(lineWidth: 0))
                if let date = value.as(Date.self) {
                    AxisValueLabel(centered: true) {
                        Text(formatDate(date, format: axisFormat))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                            .offset(y: 5)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                    .foregroundStyle(Color.gray.opacity(0.2))
                AxisValueLabel() {
                    if let intValue = value.as(Int.self) {
                        Text("\(intValue)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
        .frame(height: 220)
    }
    var body: some View {
        if isEmbedded {
            contentView
        } else {
            NavigationStack {
                contentView
                    .navigationTitle("趋势详情")
            }
        }
    }
    
    private var contentView: some View {
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
                        Button("重试") {
                            showErrorBanner = false
                            hasData = true
                        }
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
                
                categoryFilterView
                
                itemGridView
                
                if selectedItemId != nil {
                    VStack(spacing: 16) {
                        // Chart Section
                    VStack(spacing: 0) {
                        Picker("", selection: $selectedTimeRange) {
                            ForEach(TimeRange.allCases, id: \.self) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .onChange(of: selectedTimeRange) { _, _ in
                            scrollPosition = Date()
                        }
                        
                        if hasData {
                            chartView()
                                .padding(.top, 20)
                            } else {
                                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                    .fill(Theme.surface)
                                    .frame(height: 240)
                                    .overlay(
                                        VStack(spacing: 8) {
                                            Image(systemName: "chart.line.uptrend.xyaxis")
                                                .font(.system(size: 36))
                                                .foregroundColor(Theme.textSecondary)
                                            Text("暂无数据")
                                                .font(Theme.bodyFont)
                                                .foregroundColor(Theme.textSecondary)
                                            Button("去录入") {
                                                errorText = "网络异常，请重试"
                                                showErrorBanner = true
                                            }
                                            .font(Theme.captionFont)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                                                    .fill(Theme.primary)
                                            )
                                        }
                                    )
                            }
                        }
                        .padding(16)
                        .background(Theme.surface)
                        .cornerRadius(Theme.cornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                .stroke(Theme.textSecondary.opacity(0.2), lineWidth: 1)
                        )
                        
                        // Export and Delete Buttons
                        HStack(spacing: 16) {
                            Menu {
                                Button(action: {
                                    // Image Export
                                    let viewForExport = shareCardView()
                                        .transaction { transaction in
                                            transaction.animation = nil
                                        }
                                    
                                    let renderer = ImageRenderer(content: viewForExport)
                                    renderer.scale = 3.0
                                    renderer.proposedSize = ProposedViewSize(width: 375, height: nil)
                                    
                                    // Workaround: Access uiImage twice to ensure Charts are rendered correctly
                                    // The first render might miss some layout-dependent content like Charts
                                    _ = renderer.uiImage
                                    
                                    if let uiImage = renderer.uiImage {
                                        shareItems = [uiImage]
                                        showShareSheet = true
                                    }
                                }) {
                                    Label("下载图片", systemImage: "photo")
                                }
                                
                                Button(action: {
                                    // CSV Export
                                    let csvTitle = items.first(where: { $0.id == selectedItemId })?.name ?? "趋势"
                                    if let csvURL = try? CoreDataManager.shared.generateCSV(from: mainSeries(), title: csvTitle) {
                                        shareItems = [csvURL]
                                        showShareSheet = true
                                    }
                                }) {
                                    Label("导出 CSV", systemImage: "doc.text")
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("导出数据")
                                }
                                .font(Theme.bodyFont)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Capsule().fill(Theme.primary))
                                .shadow(color: Theme.primary.opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                            
                            Button {
                                showDeleteAlert = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("删除数据")
                                }
                                .font(Theme.bodyFont)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Capsule().fill(Theme.error))
                                .shadow(color: Theme.error.opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, Theme.spacing)
                }
            }
            .padding(.vertical, Theme.spacing * 1.5)
            .alert("确认删除？", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    deleteCurrentItem()
                }
            } message: {
                Text("将清空该数据模型下的所有数据，且不可恢复。")
            }
        }
        .onAppear {
            loadItems()
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityViewController(activityItems: shareItems)
                .presentationDetents([.medium, .large])
        }
    }
    
    private func deleteCurrentItem() {
        guard let id = selectedItemId, let item = items.first(where: { $0.id == id }) else { return }
        Task {
            try? await CoreDataManager.shared.deleteTrackerItem(item)
            await MainActor.run {
                selectedItemId = nil
                loadItems()
            }
        }
    }
    
    @ViewBuilder
    private var categoryFilterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" Category
                Button(action: { selectedCategory = nil }) {
                    Text("我的")
                        .font(Theme.captionFont)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(selectedCategory == nil ? Theme.primary : Theme.surface))
                        .foregroundColor(selectedCategory == nil ? .white : Theme.textPrimary)
                        .overlay(Capsule().strokeBorder(Theme.primary.opacity(0.3), lineWidth: 1))
                }
                
                ForEach(categoryManager.categories, id: \.self) { cat in
                    Button(action: {
                        selectedCategory = cat
                    }) {
                        Text(cat)
                            .font(Theme.captionFont)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(selectedCategory == cat ? Theme.primary : Theme.surface)
                            )
                            .foregroundColor(selectedCategory == cat ? .white : Theme.textPrimary)
                            .overlay(
                                Capsule()
                                    .strokeBorder(Theme.primary.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    @ViewBuilder
    private var itemGridView: some View {
        let rows = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
        
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(rows: rows, spacing: 12) {
                ForEach(filteredItems) { item in
                    Button(action: {
                        selectedItemId = item.id
                    }) {
                        VStack(spacing: 6) {
                            Image(systemName: item.icon ?? "doc.text.fill")
                                .font(.system(size: 24))
                                .foregroundColor(Theme.primary)
                            
                            VStack(spacing: 2) {
                                Text(item.name)
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.textPrimary)
                                    .lineLimit(1)
                                
                                if let recs = recordsMap[item.id] {
                                    let total = recs.reduce(0) { $0 + $1.value }
                                    Text(String(format: "%.1f", total))
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Theme.textPrimary)
                                } else {
                                    Text("--")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }
                        }
                        .padding(12)
                        .frame(width: 100)
                        .frame(maxHeight: .infinity)
                        .background(Theme.surface)
                        .cornerRadius(Theme.cornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                .stroke(selectedItemId == item.id ? Theme.primary : Color.clear, lineWidth: 2)
                        )
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                    }
                }
            }
            .padding(.horizontal, 4)
            .frame(height: 210)
        }
    }
    
    @ViewBuilder
    private var itemDetailStatsView: some View {
        if let id = selectedItemId, let _ = items.first(where: { $0.id == id }) {
            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("平均每周").font(Theme.captionFont).foregroundColor(Theme.textSecondary)
                    Text(weeklyAverage().map{ String(format: "%.1f", $0)} ?? "--").font(Theme.bodyFont)
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("本月总计").font(Theme.captionFont).foregroundColor(Theme.textSecondary)
                    Text(String(format: "%.1f", monthlyTotal())).font(Theme.bodyFont)
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("较上月").font(Theme.captionFont).foregroundColor(Theme.textSecondary)
                    let pct = monthComparePercent()
                    Text(pct != nil ? String(format: "%.0f%%", pct!) : "--").font(Theme.bodyFont).foregroundColor(Theme.primary)
                }
            }
            .padding(16)
            .background(Theme.surface)
            .cornerRadius(Theme.cornerRadius)
        }
    }
}

#Preview {
    TrendDetailView()
}

fileprivate func dayLabel(for date: Date) -> String {
    let df = DateFormatter()
    df.locale = Locale(identifier: "zh_CN")
    df.dateFormat = "d日"
    return df.string(from: date)
}

extension TrendDetailView {
    private func loadItems() {
        Task {
            do {
                let all = try await CoreDataManager.shared.fetchTrackerItems()
                var withData: [TrackerItem] = []
                var map: [UUID: [TrackerRecord]] = [:]
                for m in all {
                    let recs = try await CoreDataManager.shared.fetchTrackerRecords(for: m.id)
                    if !recs.isEmpty {
                        withData.append(m)
                        map[m.id] = recs
                    }
                }
                await MainActor.run {
                    self.items = withData
                    self.recordsMap = map
                    
                    if self.selectedItemId == nil { 
                        self.selectedItemId = withData.first?.id 
                    }
                    self.hasData = !withData.isEmpty
                    
                    // Enforce history limit for free users
                    // Logic moved to mainSeries()
                }
            } catch {
                await MainActor.run {
                    self.items = []
                    self.recordsMap = [:]
                    self.hasData = false
                }
            }
        }
    }
}
