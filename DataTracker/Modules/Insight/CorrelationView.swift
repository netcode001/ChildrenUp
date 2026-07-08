import SwiftUI
import Charts

struct CorrelationView: View {
    @State private var items: [TrackerItem] = []
    @State private var selectedItem1: TrackerItem?
    @State private var selectedItem2: TrackerItem?
    @State private var timeRange: Int = 30 // Days
    @State private var points: [CorrelationPoint] = []
    @State private var series1: [DateValue] = []
    @State private var series2: [DateValue] = []
    @State private var isLoading = false
    @State private var chartMode: Int = 0 // 0: Trend, 1: Scatter
    @State private var showAnalysis = false
    
    struct CorrelationPoint: Identifiable {
        let id = UUID()
        let date: Date
        let xValue: Double
        let yValue: Double
    }
    
    struct DateValue: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Controls
                VStack(spacing: 12) {
                    HStack {
                        Picker("指标 1", selection: $selectedItem1) {
                            Text("选择指标").tag(nil as TrackerItem?)
                            ForEach(items) { item in
                                Text(item.name).tag(item as TrackerItem?)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(Theme.surface)
                        .cornerRadius(8)
                        
                        Text("vs")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        
                        Picker("指标 2", selection: $selectedItem2) {
                            Text("选择指标").tag(nil as TrackerItem?)
                            ForEach(items) { item in
                                Text(item.name).tag(item as TrackerItem?)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(Theme.surface)
                        .cornerRadius(8)
                    }
                    
                    HStack {
                        Picker("时间范围", selection: $timeRange) {
                            Text("30天").tag(30)
                            Text("90天").tag(90)
                            Text("半年").tag(180)
                            Text("一年").tag(365)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                        
                        Spacer()
                        
                        Picker("图表模式", selection: $chartMode) {
                            Image(systemName: "chart.xyaxis.line").tag(0) // Trend
                            Image(systemName: "chart.dots.scatter").tag(1) // Scatter
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 100)
                    }
                }
                .padding()
                .background(Theme.surfaceElevated)
                .cornerRadius(Theme.cornerRadius)
                .padding(.horizontal)
                
                // Chart
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(chartMode == 0 ? "趋势对比" : "关联分析")
                            .font(Theme.headlineFont)
                        Spacer()
                        if selectedItem1 != nil && selectedItem2 != nil && !points.isEmpty {
                            Button(action: { showAnalysis = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "sparkles")
                                    Text("AI 分析")
                                }
                                .font(Theme.captionFont)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(Theme.primaryGradient))
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    if selectedItem1 == nil || selectedItem2 == nil {
                        Text("请选择两个指标进行对比")
                            .foregroundColor(Theme.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 300)
                            .background(Theme.surface)
                            .cornerRadius(Theme.cornerRadius)
                            .padding(.horizontal)
                    } else if points.isEmpty {
                        Text(isLoading ? "加载中..." : "暂无重叠数据")
                            .foregroundColor(Theme.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 300)
                            .background(Theme.surface)
                            .cornerRadius(Theme.cornerRadius)
                            .padding(.horizontal)
                    } else {
                        Group {
                            if chartMode == 0 {
                                trendChartView
                            } else {
                                scatterChartView
                            }
                        }
                        .padding()
                        .background(Theme.surface)
                        .cornerRadius(Theme.cornerRadius)
                        .padding(.horizontal)
                        
                        // Description
                        Text(chartMode == 0 
                             ? "观察两条曲线的走势。如果它们同时上升或下降，可能存在正相关。"
                             : "每个点代表一天。如果点分布呈对角线趋势，说明两者存在相关性。")
                            .font(Theme.captionFont)
                            .foregroundColor(Theme.textSecondary)
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .onAppear {
            loadItems()
        }
        .onChange(of: selectedItem1) { _, _ in loadData() }
        .onChange(of: selectedItem2) { _, _ in loadData() }
        .onChange(of: timeRange) { _, _ in loadData() }
        .sheet(isPresented: $showAnalysis) {
            AnalysisResultView(
                item1: selectedItem1!,
                item2: selectedItem2!,
                points: points,
                chartView: AnyView(chartMode == 0 ? AnyView(trendChartView) : AnyView(scatterChartView))
            )
            .presentationDetents([.medium, .large])
        }
    }
    
    private var trendChartView: some View {
        Chart {
            trendSeries1
            trendSeries2
        }
        .chartForegroundStyleScale([
            (selectedItem1?.name ?? "1"): Theme.primary,
            (selectedItem2?.name ?? "2"): Theme.secondary
        ])
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine()
            }
        }
        .chartYScale(domain: 0...1) // Normalized scale
        .frame(height: 300)
    }
    
    @ChartContentBuilder
    private var trendSeries1: some ChartContent {
        ForEach(series1) { p in
            LineMark(
                x: .value("日期", p.date),
                y: .value("数值", normalize(p.value, in: series1))
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(by: .value("指标", selectedItem1?.name ?? "1"))
        }
    }
    
    @ChartContentBuilder
    private var trendSeries2: some ChartContent {
        ForEach(series2) { p in
            LineMark(
                x: .value("日期", p.date),
                y: .value("数值", normalize(p.value, in: series2))
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(by: .value("指标", selectedItem2?.name ?? "2"))
        }
    }
    
    private var scatterChartView: some View {
        Chart {
            ForEach(points) { point in
                PointMark(
                    x: .value(selectedItem1?.name ?? "X", point.xValue),
                    y: .value(selectedItem2?.name ?? "Y", point.yValue)
                )
                .foregroundStyle(Theme.primary.opacity(0.6))
            }
            if let trend = calculateTrendLine() {
                LineMark(
                    x: .value("X", trend.start.x),
                    y: .value("Y", trend.start.y)
                )
                .foregroundStyle(Theme.secondary)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                
                LineMark(
                    x: .value("X", trend.end.x),
                    y: .value("Y", trend.end.y)
                )
                .foregroundStyle(Theme.secondary)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
            }
        }
        .chartXAxisLabel(selectedItem1?.nameWithUnit ?? "")
        .chartYAxisLabel(selectedItem2?.nameWithUnit ?? "")
        .frame(height: 300)
    }
    
    private func normalize(_ value: Double, in series: [DateValue]) -> Double {
        let values = series.map { $0.value }
        guard let min = values.min(), let max = values.max(), max > min else { return 0.5 }
        return (value - min) / (max - min)
    }
    
    private func calculateTrendLine() -> (start: (x: Double, y: Double), end: (x: Double, y: Double))? {
        guard points.count > 1 else { return nil }
        
        let n = Double(points.count)
        let sumX = points.reduce(0) { $0 + $1.xValue }
        let sumY = points.reduce(0) { $0 + $1.yValue }
        let sumXY = points.reduce(0) { $0 + $1.xValue * $1.yValue }
        let sumXX = points.reduce(0) { $0 + $1.xValue * $1.xValue }
        
        let slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX)
        let intercept = (sumY - slope * sumX) / n
        
        let xValues = points.map { $0.xValue }
        guard let minX = xValues.min(), let maxX = xValues.max() else { return nil }
        
        return (
            start: (x: minX, y: slope * minX + intercept),
            end: (x: maxX, y: slope * maxX + intercept)
        )
    }

    private func loadItems() {
        Task {
            do {
                let all = try await CoreDataManager.shared.fetchTrackerItems()
                await MainActor.run {
                    self.items = all
                    if all.count >= 2 {
                        self.selectedItem1 = all[0]
                        self.selectedItem2 = all[1]
                    }
                }
            } catch {
                print("Error loading items: \(error)")
            }
        }
    }
    
    private func loadData() {
        guard let item1 = selectedItem1, let item2 = selectedItem2 else { return }
        isLoading = true
        
        Task {
            do {
                let calendar = Calendar.current
                let now = Date()
                let startDate = calendar.date(byAdding: .day, value: -timeRange, to: now)!
                
                let allRecords = try await CoreDataManager.shared.fetchRecords(from: startDate, to: now)
                
                let recs1 = allRecords.filter { $0.itemId == item1.id }
                let recs2 = allRecords.filter { $0.itemId == item2.id }
                
                // Aggregate by day for Series 1
                var map1: [Date: Double] = [:]
                for r in recs1 {
                    let day = calendar.startOfDay(for: r.date)
                    map1[day, default: 0] += r.value
                }
                
                // Aggregate by day for Series 2
                var map2: [Date: Double] = [:]
                for r in recs2 {
                    let day = calendar.startOfDay(for: r.date)
                    map2[day, default: 0] += r.value
                }
                
                // Prepare Series Data (Sorted)
                let s1 = map1.map { DateValue(date: $0.key, value: $0.value) }.sorted { $0.date < $1.date }
                let s2 = map2.map { DateValue(date: $0.key, value: $0.value) }.sorted { $0.date < $1.date }
                
                // Find intersection days for Scatter
                let commonDays = Set(map1.keys).intersection(Set(map2.keys))
                let scatterPoints = commonDays.map { day in
                    CorrelationPoint(date: day, xValue: map1[day]!, yValue: map2[day]!)
                }.sorted(by: { $0.date < $1.date })
                
                await MainActor.run {
                    self.series1 = s1
                    self.series2 = s2
                    self.points = scatterPoints
                    self.isLoading = false
                }
                
            } catch {
                print("Error loading data: \(error)")
                await MainActor.run { isLoading = false }
            }
        }
    }
}

struct AnalysisResultView: View {
    let item1: TrackerItem
    let item2: TrackerItem
    let points: [CorrelationView.CorrelationPoint]
    let chartView: AnyView
    
    @Environment(\.dismiss) var dismiss
    @State private var analysisText: String = "正在分析..."
    @State private var correlationScore: Double = 0.0
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Chart Preview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("数据概览")
                            .font(Theme.headlineFont)
                        chartView
                            .frame(height: 200)
                            .padding()
                            .background(Theme.surface)
                            .cornerRadius(Theme.cornerRadius)
                    }
                    
                    // Analysis Content
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(Theme.primary)
                            Text("AI 智能分析")
                                .font(Theme.headlineFont)
                        }
                        
                        if analysisText == "正在分析..." {
                            HStack {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text(analysisText)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .padding()
                        } else {
                            VStack(alignment: .leading, spacing: 16) {
                                // Score Card
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading) {
                                        Text("相关系数")
                                            .font(Theme.captionFont)
                                            .foregroundColor(Theme.textSecondary)
                                        Text(String(format: "%.2f", correlationScore))
                                            .font(.system(size: 32, weight: .bold))
                                            .foregroundColor(colorForScore(correlationScore))
                                    }
                                    
                                    Divider()
                                    
                                    VStack(alignment: .leading) {
                                        Text("关联强度")
                                            .font(Theme.captionFont)
                                            .foregroundColor(Theme.textSecondary)
                                        Text(strengthDescription(correlationScore))
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundColor(Theme.textPrimary)
                                    }
                                }
                                .padding()
                                .background(Theme.surfaceElevated)
                                .cornerRadius(Theme.cornerRadius)
                                
                                Text(analysisText)
                                    .font(Theme.bodyFont)
                                    .foregroundColor(Theme.textPrimary)
                                    .lineSpacing(4)
                            }
                        }
                    }
                    .padding()
                    .background(Theme.surface)
                    .cornerRadius(Theme.cornerRadius)
                    
                    // Export Button
                    ShareLink(
                        item: generateReportImage(),
                        preview: SharePreview("分析报告", image: generateReportImage())
                    ) {
                        HStack {
                            Spacer()
                            Image(systemName: "square.and.arrow.up")
                            Text("导出分析报告")
                            Spacer()
                        }
                        .padding()
                        .background(Theme.primary)
                        .foregroundColor(.white)
                        .cornerRadius(Theme.cornerRadius)
                    }
                }
                .padding()
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("分析报告")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .onAppear {
            performAnalysis()
        }
    }
    
    private func performAnalysis() {
        // Simulate AI Analysis with delay
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            let n = Double(points.count)
            guard n > 1 else {
                await MainActor.run {
                    analysisText = "数据不足，无法进行有效分析。"
                }
                return
            }
            
            let sumX = points.reduce(0) { $0 + $1.xValue }
            let sumY = points.reduce(0) { $0 + $1.yValue }
            let sumXY = points.reduce(0) { $0 + $1.xValue * $1.yValue }
            let sumXX = points.reduce(0) { $0 + $1.xValue * $1.xValue }
            let sumYY = points.reduce(0) { $0 + $1.yValue * $1.yValue }
            
            let numerator = n * sumXY - sumX * sumY
            let denominator = sqrt((n * sumXX - sumX * sumX) * (n * sumYY - sumY * sumY))
            
            let r = denominator == 0 ? 0 : numerator / denominator
            
            await MainActor.run {
                self.correlationScore = r
                self.analysisText = generateInsightText(r: r)
            }
        }
    }
    
    private func generateInsightText(r: Double) -> String {
        let absR = abs(r)
        var text = ""
        
        // 1. Correlation Type
        if absR < 0.3 {
            text += "根据当前数据分析，\(item1.name)与\(item2.name)之间**几乎没有明显的直接关联** (r=\(String(format: "%.2f", r)))。"
            text += "\n\n这意味着其中一个指标的变化通常不会直接影响另一个指标。它们可能受完全不同的因素影响。"
        } else if absR < 0.7 {
            let type = r > 0 ? "正相关" : "负相关"
            text += "数据显示两者存在**中等强度的\(type)** (r=\(String(format: "%.2f", r)))。"
            if r > 0 {
                text += "\n\n当\(item1.name)增加时，\(item2.name)往往也会随之增加。这表明两者之间可能存在某种间接联系或共同的影响因素。"
            } else {
                text += "\n\n当\(item1.name)增加时，\(item2.name)往往会呈现下降趋势。建议关注这种消长关系来平衡您的生活习惯。"
            }
        } else {
            let type = r > 0 ? "正相关" : "负相关"
            text += "分析发现两者存在**非常显著的\(type)** (r=\(String(format: "%.2f", r)))！"
            if r > 0 {
                text += "\n\n这几乎可以确定两者紧密绑定。保持良好的\(item1.name)可能是提升\(item2.name)的关键驱动力。"
            } else {
                text += "\n\n这显示了明显的互斥关系。如果您希望提升\(item2.name)，可能需要控制\(item1.name)的水平。"
            }
        }
        
        // 2. Actionable Advice (Mock)
        text += "\n\n**建议**：\n建议持续记录更多数据以验证这一趋势。您可以尝试在未来一周有意识地调整\(item1.name)，观察\(item2.name)的变化是否符合预期。"
        
        return text
    }
    
    private func strengthDescription(_ r: Double) -> String {
        let absR = abs(r)
        if absR < 0.3 { return "弱相关" }
        if absR < 0.7 { return "中等相关" }
        return "强相关"
    }
    
    private func colorForScore(_ r: Double) -> Color {
        let absR = abs(r)
        if absR < 0.3 { return Theme.textSecondary }
        if absR < 0.7 { return Theme.primary }
        return Theme.secondary // Strong
    }
    
    @MainActor
    private func generateReportImage() -> Image {
        let renderer = ImageRenderer(content: 
            VStack(spacing: 20) {
                Text("数据洞察分析报告")
                    .font(.largeTitle)
                    .bold()
                
                chartView
                    .frame(height: 300)
                    .padding()
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("分析对象：\(item1.name) vs \(item2.name)")
                        .font(.headline)
                    Text("相关系数：\(String(format: "%.2f", correlationScore)) (\(strengthDescription(correlationScore)))")
                        .font(.subheadline)
                    Divider()
                    Text(analysisText) // Note: Markdown might not render in ImageRenderer directly, simple text is safer
                }
                .padding()
                .background(Color.white)
                .cornerRadius(10)
            }
            .padding(40)
            .background(Color(UIColor.systemBackground))
            .frame(width: 600)
        )
        
        if let image = renderer.uiImage {
            return Image(uiImage: image)
        }
        return Image(systemName: "doc.text")
    }
}

extension TrackerItem {
    var nameWithUnit: String {
        if let u = unit, !u.isEmpty {
            return "\(name) (\(u))"
        }
        return name
    }
}
