import Foundation

enum QueryTimeRange: String, Codable {
    case today
    case yesterday
    case thisWeek = "this_week"
    case lastWeek = "last_week"
    case thisMonth = "this_month"
    case lastMonth = "last_month"
    case allTime = "all_time"
}

enum QueryOperation: String, Codable {
    case sum
    case average
    case count
    case latest // Latest value
    case max
    case min
    case list
}

struct QueryIntent: Codable {
    let targetName: String
    let targetNames: [String]?
    let timeRange: QueryTimeRange
    let operation: QueryOperation
    
    enum CodingKeys: String, CodingKey {
        case targetName = "target_name"
        case targetNames = "target_names"
        case timeRange = "time_range"
        case operation
    }
}

class LocalQueryEngine {
    static let shared = LocalQueryEngine()
    
    private init() {}
    
    // Exposed for AI Service to call directly
    func executeQuery(_ intent: QueryIntent, userId: UUID? = nil) async -> String {
        let (start, end) = getDateRange(for: intent.timeRange)
        
        // Handle Multi-Select Case
        if let names = intent.targetNames, !names.isEmpty {
            return await executeMultiQuery(names: names, intent: intent, start: start, end: end, userId: userId)
        }
        
        do {
            let allItems = try await CoreDataManager.shared.fetchTrackerItems(in: nil)
            
            guard let (bestMatch, matchingIds) = findBestMatch(for: intent.targetName, in: allItems) else {
                // Template Match (if still empty)
                // Check if it's a known template
                let allTemplates = CategoryManager.shared.getAllTemplates()
                let target = intent.targetName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                
                // Try to find a template match
                if let _ = allTemplates.first(where: {
                    let name = $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    return name == target || name.contains(target) || target.contains(name)
                }) {
                     return "您还没有开始记录“\(intent.targetName)”，请先添加一条记录吧。"
                }
                
                return "抱歉，我没有找到关于“\(intent.targetName)”的记录项目。"
            }
            
            // Update intent target name for display if we found a better match
            let displayTargetName = bestMatch.name
            
            // Now query records
            let records = try await CoreDataManager.shared.fetchRecords(from: start, to: end, userId: userId)
            // Filter by item ID (match any of the duplicate items)
            let targetRecords = records.filter { matchingIds.contains($0.itemId) }
            
            if targetRecords.isEmpty {
                return "在\(timeRangeDescription(intent.timeRange))没有找到“\(displayTargetName)”的记录。"
            }
            
            return calculateResult(records: targetRecords, operation: intent.operation, targetName: displayTargetName, unit: bestMatch.unit, timeRange: intent.timeRange)
            
        } catch {
            return "查询出错：\(error.localizedDescription)"
        }
    }
    
    private func executeMultiQuery(names: [String], intent: QueryIntent, start: Date?, end: Date?, userId: UUID? = nil) async -> String {
        do {
            let allItems = try await CoreDataManager.shared.fetchTrackerItems(in: nil)
            var results: [String] = []
            var totalValue: Double = 0
            var sameUnit = true
            var lastUnit: String? = nil
            var foundAny = false
            
            for name in names {
                if let (match, matchingIds) = findBestMatch(for: name, in: allItems) {
                    let records = try await CoreDataManager.shared.fetchRecords(from: start, to: end, userId: userId)
                    let targetRecords = records.filter { matchingIds.contains($0.itemId) }
                    
                    if !targetRecords.isEmpty {
                        foundAny = true
                        let subValue = targetRecords.reduce(0) { $0 + $1.value }
                        let unit = match.unit ?? ""
                        
                        if let last = lastUnit, last != unit {
                            sameUnit = false
                        }
                        lastUnit = unit
                        totalValue += subValue
                        
                        let valStr = formatValue(subValue)
                        results.append("\(match.name): \(valStr)\(unit)")
                    } else {
                        results.append("\(match.name): 0")
                    }
                } else {
                    results.append("\(name): 未找到")
                }
            }
            
            if !foundAny {
                return "没有找到相关记录。"
            }
            
            // If operation is sum and all have same unit, show total
            if intent.operation == .sum && sameUnit && lastUnit != nil {
                 let valStr = formatValue(totalValue)
                 let unit = lastUnit ?? ""
                 return "\(timeRangeDescription(intent.timeRange))一共 \(valStr)\(unit)（其中 " + results.joined(separator: "，") + "）"
            }
            
            return "\(timeRangeDescription(intent.timeRange))统计如下：\n" + results.joined(separator: "\n")
            
        } catch {
            return "查询出错：\(error.localizedDescription)"
        }
    }
    
    private func findBestMatch(for targetName: String, in allItems: [TrackerItem]) -> (TrackerItem, [UUID])? {
        // 1. Try Exact Match
        var matchingItems = allItems.filter { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == targetName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        
        // 2. Fuzzy Match
        if matchingItems.isEmpty {
            let target = targetName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            matchingItems = allItems.filter { item in
                let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return name.contains(target) || target.contains(name)
            }
            
            // Sort by length difference to find closest match
            matchingItems.sort { a, b in
                let aDiff = abs(a.name.count - target.count)
                let bDiff = abs(b.name.count - target.count)
                return aDiff < bDiff
            }
        }
        
        guard let bestMatch = matchingItems.first else { return nil }
        
        // Find IDs of duplicates (same name)
        let matchingIds = matchingItems.filter { $0.name == bestMatch.name }.map { $0.id }
        
        return (bestMatch, matchingIds)
    }
    
    private func calculateResult(records: [TrackerRecord], operation: QueryOperation, targetName: String, unit: String?, timeRange: QueryTimeRange) -> String {
        let u = unit ?? ""
        
        switch operation {
        case .sum:
            let sum = records.reduce(0) { $0 + $1.value }
            return "\(timeRangeDescription(timeRange))“\(targetName)”总共 \(formatValue(sum)) \(u)。"
        case .average:
            let sum = records.reduce(0) { $0 + $1.value }
            let avg = sum / Double(records.count)
            return "\(timeRangeDescription(timeRange))“\(targetName)”平均 \(formatValue(avg)) \(u)。"
        case .count:
            return "\(timeRangeDescription(timeRange))共记录了 \(records.count) 次“\(targetName)”。"
        case .latest:
            if let last = records.last {
                return "最近一次“\(targetName)”是 \(formatValue(last.value)) \(u)。"
            } else {
                 return "没有找到记录。"
            }
        case .max:
            if let maxRecord = records.max(by: { $0.value < $1.value }) {
                return "\(timeRangeDescription(timeRange))“\(targetName)”最大值为 \(formatValue(maxRecord.value)) \(u)。"
            } else {
                return "没有找到记录。"
            }
        case .min:
            if let minRecord = records.min(by: { $0.value < $1.value }) {
                return "\(timeRangeDescription(timeRange))“\(targetName)”最小值为 \(formatValue(minRecord.value)) \(u)。"
            } else {
                return "没有找到记录。"
            }
        case .list:
            let recentRecords = records.suffix(5).reversed()
            if recentRecords.isEmpty {
                return "没有找到记录。"
            }
            let listStr = recentRecords.map { "\(formatValue($0.value)) \(u) (\($0.date.formatted(.dateTime.month().day().hour().minute())))" }.joined(separator: "\n")
            return "\(timeRangeDescription(timeRange))“\(targetName)”的记录如下：\n\(listStr)"
        }
    }
    
    // MARK: - Aggregation / Review
    
    private let categoryEmojis: [String: String] = [
        "健身": "💪",
        "饮食": "🦞",
        "健康": "❤️",
        "财务": "💰",
        "考试/学习": "📚",
        "工作/效率": "💻",
        "兴趣/其他": "🎨",
        "未分类": "📦"
    ]
    
    func generateReviewReport(timeRange: QueryTimeRange, userId: UUID? = nil) async -> String {
        let (start, end) = getDateRange(for: timeRange)
        
        do {
            let items = try await CoreDataManager.shared.fetchAggregatedRecords(from: start, to: end, userId: userId)
            
            var timeDesc = ""
            switch timeRange {
            case .today: timeDesc = "今天"
            case .thisWeek: timeDesc = "本周"
            case .thisMonth: timeDesc = "本月"
            case .yesterday: timeDesc = "昨天"
            case .lastWeek: timeDesc = "上周"
            case .lastMonth: timeDesc = "上月"
            case .allTime: timeDesc = "全部"
            }
            
            if items.isEmpty {
                return "\(timeDesc)还没有任何记录哦。"
            }
            
            // Group items by category
            let groupedItems = Dictionary(grouping: items) { item -> String in
                if let group = item.item.group, !group.isEmpty {
                    // Map legacy "未分类" to "其他"
                    return group == "未分类" ? "其他" : group
                }
                return "其他"
            }
            
            // Sort groups (Others at the end)
            let sortedGroups = groupedItems.keys.sorted { group1, group2 in
                if group1 == "其他" { return false }
                if group2 == "其他" { return true }
                return group1 < group2
            }
            
            var listText = "\(timeDesc)一共 \(items.count) 项：\n\n"
            
            for (index, groupName) in sortedGroups.enumerated() {
                guard let groupItems = groupedItems[groupName] else { continue }
                let emoji = categoryEmojis[groupName] ?? "📦"
                listText += "\(index + 1)、\(groupName) \(groupItems.count) 项\(emoji)\n"
                
                for item in groupItems {
                    let unit = item.item.unit ?? ""
                    let valStr = item.totalValue.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", item.totalValue) : String(format: "%.1f", item.totalValue)
                    listText += "\(item.item.name) \(valStr) \(unit)\n"
                }
                listText += "\n"
            }
            
            return listText
        } catch {
            return "生成报告出错：\(error.localizedDescription)"
        }
    }
    
    private func getDateRange(for range: QueryTimeRange) -> (Date?, Date?) {
        let calendar = Calendar.current
        let now = Date()
        
        switch range {
        case .today:
            let start = calendar.startOfDay(for: now)
            return (start, now)
        case .yesterday:
            let startToday = calendar.startOfDay(for: now)
            let startYesterday = calendar.date(byAdding: .day, value: -1, to: startToday)!
            let endYesterday = calendar.date(byAdding: .second, value: -1, to: startToday)!
            return (startYesterday, endYesterday)
        case .thisWeek:
            // Assuming week starts on Monday
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            let startOfWeek = calendar.date(from: components)!
            return (startOfWeek, now)
        case .lastWeek:
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            let startOfThisWeek = calendar.date(from: components)!
            let startOfLastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: startOfThisWeek)!
            let endOfLastWeek = calendar.date(byAdding: .second, value: -1, to: startOfThisWeek)!
            return (startOfLastWeek, endOfLastWeek)
        case .thisMonth:
            let components = calendar.dateComponents([.year, .month], from: now)
            let startOfMonth = calendar.date(from: components)!
            return (startOfMonth, now)
        case .lastMonth:
            let components = calendar.dateComponents([.year, .month], from: now)
            let startOfThisMonth = calendar.date(from: components)!
            let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfThisMonth)!
            let endOfLastMonth = calendar.date(byAdding: .second, value: -1, to: startOfThisMonth)!
            return (startOfLastMonth, endOfLastMonth)
        case .allTime:
            return (nil, nil)
        }
    }
    
    private func timeRangeDescription(_ range: QueryTimeRange) -> String {
        switch range {
        case .today: return "今天"
        case .yesterday: return "昨天"
        case .thisWeek: return "本周"
        case .lastWeek: return "上周"
        case .thisMonth: return "本月"
        case .lastMonth: return "上月"
        case .allTime: return "历史"
        }
    }
    
    private func formatValue(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
}
