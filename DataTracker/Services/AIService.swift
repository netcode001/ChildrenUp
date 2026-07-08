import Foundation
import NaturalLanguage

// MARK: - API Request/Response Models

struct AIRequest: Codable {
    let text: String
    let existingModels: [SimpleModelInfo]
    
    enum CodingKeys: String, CodingKey {
        case text
        case existingModels = "existing_models"
    }
}

struct SimpleModelInfo: Codable {
    let id: String
    let name: String
    let group: String?
    let unit: String?
}

struct AIResponse: Codable {
    let type: AIResponseType
    let record: AIRecordData?
    let records: [AIRecordData]?
    let query: QueryIntent?
    let message: String?
}

enum AIResponseType: String, Codable {
    case record, query, chat
}

struct AIRecordData: Codable {
    let action: String // create/update
    let targetName: String
    let value: String
    let date: String?
    let newModelInfo: NewModelInfo?
    let compliment: String? // New field for user praise
    
    enum CodingKeys: String, CodingKey {
        case action
        case targetName = "target_name"
        case value
        case date
        case newModelInfo = "new_model_info"
        case compliment
    }
}

struct NewModelInfo: Codable {
    let type: String?
    let group: String? // New field for category
    let unit: String?
    let icon: String?
}

// MARK: - Service

class AIService {
    static let shared = AIService()
    
    // Replace with your actual Supabase Function URL
    private let functionURL = URL(string: "https://aomabgwmlgxwptlpmkwf.supabase.co/functions/v1/analyze-record")!
    // If you have an anon key, you might need it. For now, we assume public or simple header auth.
    private let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFvbWFiZ3dtbGd4d3B0bHBta3dmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQ0NzAzNDUsImV4cCI6MjA3MDA0NjM0NX0.RNjLAi-ge6G73SrsCdrYPAb3y6klYJ0X71fDJ0bpNuc" 
    
    // MARK: - Public Interface
    
    struct ProcessingResult {
        let text: String
        let recordId: UUID?
        let showUpgradeButton: Bool
        
        init(text: String, recordId: UUID?, showUpgradeButton: Bool = false) {
            self.text = text
            self.recordId = recordId
            self.showUpgradeButton = showUpgradeButton
        }
    }
    
    // Track daily usage
    private let dailyUsageKey = "ai_daily_usage"
    private let lastUsageDateKey = "ai_last_usage_date"
    
    // Check if user can send message (helper for UI)
    func checkDailyQuota() -> (canSend: Bool, message: String?) {
        // Just return true/nil, let UI handle display based on getCurrentDailyUsage()
        return (canSend: true, message: nil) 
    }
    
    // Explicitly expose usage for UI
    func getCurrentDailyUsage() -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        let lastDate = UserDefaults.standard.object(forKey: lastUsageDateKey) as? Date ?? Date.distantPast
        
        if Calendar.current.isDate(lastDate, inSameDayAs: today) {
            return UserDefaults.standard.integer(forKey: dailyUsageKey)
        }
        return 0
    }
    
    // Explicitly expose limit constant (or fetch from SubscriptionManager)
    // Since SubscriptionManager defines it, we use that.
    
    func processUserMessage(_ text: String) async -> ProcessingResult {
        // Check Quota
        let today = Calendar.current.startOfDay(for: Date())
        let lastDate = UserDefaults.standard.object(forKey: lastUsageDateKey) as? Date ?? Date.distantPast
        
        var currentUsage = 0
        if Calendar.current.isDate(lastDate, inSameDayAs: today) {
            currentUsage = UserDefaults.standard.integer(forKey: dailyUsageKey)
        } else {
            // Reset for new day
            UserDefaults.standard.set(0, forKey: dailyUsageKey)
            UserDefaults.standard.set(today, forKey: lastUsageDateKey)
        }
        
        // Use SubscriptionManager on MainActor if needed, or assume thread safety of shared instance access for read
        let canUse = await MainActor.run { SubscriptionManager.shared.canUseAI(dailyUsage: currentUsage) }
        
        if !canUse {
             return ProcessingResult(text: "今日免费 AI 对话额度已用完（\(SubscriptionManager.Limits.maxFreeAIDaily)次）。", recordId: nil, showUpgradeButton: true)
        }
        
        // Increment usage
        UserDefaults.standard.set(currentUsage + 1, forKey: dailyUsageKey)
        
        // Detect Target User for Query
        let targetUser = await extractTargetUser(from: text)
        let targetUserId = targetUser?.id
        
        // AI Native Flow: Always send to Cloud
        
        do {
            // Fetch existing items for context
            let existingModels = try await CoreDataManager.shared.fetchTrackerItems()
            
            // Also fetch templates to give AI broader context
            let allTemplates = CategoryManager.shared.getAllTemplates()
            let existingNames = Set(existingModels.map { $0.name })
            
            // Create list of SimpleModelInfo
            var contextModels: [SimpleModelInfo] = []
            
            // 1. Add existing items (Priority)
            contextModels.append(contentsOf: existingModels.map { item in
                SimpleModelInfo(id: item.id.uuidString, name: item.name, group: item.group, unit: item.unit)
            })
            
            // 2. Add templates that are NOT in existing items
            for template in allTemplates {
                if !existingNames.contains(template.name) {
                    contextModels.append(SimpleModelInfo(id: "template_\(template.name)", name: template.name, group: nil, unit: template.unit))
                }
            }
            
            // --- NEW: Local RAG Filtering ---
            // Calculate relevance and filter to top 20
            let relevantModels = filterRelevantModels(input: text, models: contextModels)
            
            // Convert to Compact String Format: Name(Unit)
            let contextString = relevantModels.map { model in
                if let unit = model.unit, !unit.isEmpty {
                    return "\(model.name)(\(unit))"
                } else {
                    return model.name
                }
            }.joined(separator: ", ")
            
            // We inject a system instruction to help AI understand Review Intent without backend changes
            let promptInjection = """
            User Input: \(text)
            
            Available Items (Reference):
            \(contextString)
            
            System Instruction:
            1. If the user asks for a summary or review (e.g. "Review today", "What did I do this week?"), return a QUERY intent.
               Set target_name to "SUMMARY" and set the correct time_range based on user input.
               Example: "Review today" -> target_name="SUMMARY", time_range="today".
               
            2. If the user asks about MULTIPLE items (e.g. "How much coffee and tea?", "Total of apple, banana, and orange"), return a QUERY intent.
               Set target_name to "MULTI_SELECT" and fill "target_names" with the list of items (e.g. ["coffee", "tea"]).
               Set operation to "sum" (or appropriate operation).
            
            3. If the user mentions MULTIPLE record items in one sentence (e.g. "I had 2 eggs and 1 milk", "Record 10 mins reading and 30 mins gym"), return type='record'.
               Instead of a single 'record' object, return a 'records' array containing each item.
               Example: {'type': 'record', 'records': [{'target_name': 'egg', 'value': '2', ...}, {'target_name': 'milk', 'value': '1', ...}]}
               ALSO provide a 'message' field with a short, warm encouragement or compliment. Do NOT repeat the recorded data details in this message. Just provide emotional support or a fun comment.
               
            4. For each new record item (in 'record' or 'records'), try to determine its group/category.
               Populate 'new_model_info' -> 'group' with one of: ["健身", "饮食", "健康", "财务", "考试/学习", "工作/效率", "兴趣/其他"].
               If unsure, use "兴趣/其他". NEVER use "未分类".
               
            5. For single item query, use standard target_name.
            
            6. If the item exists in "Available Items", use that exact name. If it's new, use the user's name.
            """
            
            // Call AI Service with injected prompt
            // Note: We send the modified text to AI so it sees the instruction
            // We send EMPTY contextModels to save tokens/bandwidth, as we've already injected the relevant ones into the prompt.
            let response = try await analyze(text: promptInjection, contextModels: [])
            
            // Handle Response based on Type
            switch response.type {
            case .record:
                // Handle multiple records if present
                if let records = response.records, !records.isEmpty {
                    var successMessages: [String] = []
                    var errorMessages: [String] = []
                    
                    var createdItemsCount = 0
                     
                     // Process sequentially to avoid race conditions and handle limits
                     for recordData in records {
                         // Check if creating new item and enforce limit
                         // We use the initial existingModels count plus any new items we've decided to create in this batch
                         let isNewItem = !existingModels.contains(where: { $0.name == recordData.targetName })
                         
                         if isNewItem {
                             let currentTotal = existingModels.count + createdItemsCount
                             let canCreate = await MainActor.run {
                                 SubscriptionManager.shared.canCreateTracker(currentItemCount: currentTotal)
                             }
                             
                             if !canCreate {
                                 errorMessages.append("无法创建 \"\(recordData.targetName)\" (达到免费版限制)")
                                 continue
                             }
                             createdItemsCount += 1
                         }
                        
                        do {
                            let _ = try await CoreDataManager.shared.processAIRecord(recordData)
                            
                            var unit = recordData.newModelInfo?.unit ?? ""
                            if unit.isEmpty, let existingItem = existingModels.first(where: { $0.name == recordData.targetName }) {
                                unit = existingItem.unit ?? ""
                            }
                            successMessages.append("\(recordData.targetName) \(recordData.value)\(unit)")
                        } catch {
                            errorMessages.append("记录 \"\(recordData.targetName)\" 失败")
                        }
                    }
                    
                    var message = ""
                    if !successMessages.isEmpty {
                        message = "已为您记录：\n" + successMessages.joined(separator: "、")
                    }
                    if !errorMessages.isEmpty {
                        if !message.isEmpty { message += "\n\n" }
                        message += "⚠️ " + errorMessages.joined(separator: "\n")
                    }
                    
                    if message.isEmpty {
                        message = "未能记录任何数据"
                    } else if let responseMsg = response.message, !responseMsg.isEmpty, !successMessages.isEmpty {
                        // Append the AI's general compliment/message if available
                        // Only if there was at least one success, to avoid conflicting messages like "Failed... Good job!"
                        message += "\n\n\(responseMsg)"
                    }
                    
                    // Return the last recordId just for reference, or nil
                    // If there are error messages about limits, show upgrade button
                    let hasLimitError = errorMessages.contains { $0.contains("达到免费版限制") }
                    return ProcessingResult(text: message, recordId: nil, showUpgradeButton: hasLimitError)
                }
                
                // Fallback to single record handling (Legacy)
                guard let recordData = response.record else { return ProcessingResult(text: "AI 返回数据格式错误", recordId: nil) }
                
                // Check if creating new item and enforce limit
                let isNewItem = !existingModels.contains(where: { $0.name == recordData.targetName })
                if isNewItem {
                    // Use MainActor to safely access SubscriptionManager
                    let canCreate = await MainActor.run {
                        SubscriptionManager.shared.canCreateTracker(currentItemCount: existingModels.count)
                    }
                    
                    if !canCreate {
                         return ProcessingResult(text: "无法创建新项目 \"\(recordData.targetName)\"。\n免费版最多只支持 \(SubscriptionManager.Limits.maxFreeTrackers) 个追踪项目。", recordId: nil, showUpgradeButton: true)
                    }
                }
                
                let recordId = try await CoreDataManager.shared.processAIRecord(recordData)
                
                // Find unit for display
                var unit = recordData.newModelInfo?.unit ?? ""
                if unit.isEmpty, let existingItem = existingModels.first(where: { $0.name == recordData.targetName }) {
                    unit = existingItem.unit ?? ""
                }

                // Construct message with optional compliment
                var message = "已为您记录：\(recordData.targetName) \(recordData.value)\(unit)"
                if let compliment = recordData.compliment, !compliment.isEmpty {
                    message += "\n\(compliment)"
                } else if let responseMsg = response.message, !responseMsg.isEmpty {
                     // Heuristic: If message contains the item name, assume it's a full summary and use it (legacy behavior)
                     // Otherwise, assume it's just a compliment/comment and append it
                     if responseMsg.contains(recordData.targetName) {
                        message = responseMsg
                     } else {
                        message += "\n\n\(responseMsg)"
                     }
                }
                
                return ProcessingResult(text: message, recordId: recordId)
                
            case .query:
                guard let queryData = response.query else { return ProcessingResult(text: "AI 返回查询格式错误", recordId: nil) }
                
                // Check for Special SUMMARY intent
                if queryData.targetName == "SUMMARY" {
                    // Stage 2: Fetch Data -> AI Summary
                    let reportText = await LocalQueryEngine.shared.generateReviewReport(timeRange: queryData.timeRange, userId: targetUserId)
                    
                    if reportText.contains("还没有任何记录") {
                         return ProcessingResult(text: reportText, recordId: nil)
                    }
                    
                    // Call AI again for encouragement
                    let aiPrompt = """
                    User Data Summary:
                    \(reportText)
                    
                    Instruction:
                    Provide a short, warm encouragement based on the user's data above. The response MUST be in Chinese.
                    Do not repeat the list. Just give a nice summary comment and encouragement.
                    """
                    
                    // Simple analyze call (empty context)
                    let summaryResponse = try await analyze(text: aiPrompt, contextModels: [])
                    let compliment = summaryResponse.message ?? "继续保持！"
                    
                    return ProcessingResult(text: "\(reportText)-------------------\n\(compliment)", recordId: nil)
                }
                
                // Execute Standard Local Query
                let result = await LocalQueryEngine.shared.executeQuery(queryData, userId: targetUserId)
                return ProcessingResult(text: result, recordId: nil)
                
            case .chat:
                return ProcessingResult(text: response.message ?? "收到", recordId: nil)
            }
            
        } catch {
            print("AI Processing Error: \(error)")
            // Provide more specific error info if possible
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet:
                    return ProcessingResult(text: "网络似乎断开了，请检查您的连接。", recordId: nil)
                case .timedOut:
                    return ProcessingResult(text: "请求超时，网络可能比较慢，请重试。", recordId: nil)
                default:
                    return ProcessingResult(text: "网络连接出现问题：\(urlError.localizedDescription)", recordId: nil)
                }
            }
            return ProcessingResult(text: "发生错误，请稍后再试：\(error.localizedDescription)", recordId: nil)
        }
    }
    
    // MARK: - Internal Logic
    
    private func extractTargetUser(from text: String) async -> User? {
        await MainActor.run {
            let users = UserManager.shared.allUsers
            // Sort by name length descending to match longest name first (e.g. "Bob Smith" before "Bob")
            let sortedUsers = users.sorted { $0.name.count > $1.name.count }
            
            for user in sortedUsers {
                if text.contains(user.name) {
                    return user
                }
            }
            return nil
        }
    }
    
    // Lazy embedding model loading (shared instance)
    // We use .simplifiedChinese for best local language support (since app is Chinese context), or .english as fallback
    private lazy var embeddingModel: NLEmbedding? = {
        return NLEmbedding.sentenceEmbedding(for: .simplifiedChinese) ?? NLEmbedding.sentenceEmbedding(for: .english)
    }()
    
    private func filterRelevantModels(input: String, models: [SimpleModelInfo], limit: Int = 20) -> [SimpleModelInfo] {
        guard let embedding = embeddingModel else {
            // Fallback: If no embedding model available, return truncated list
            return Array(models.prefix(limit))
        }
        
        // Calculate distances
        // Note: distance(between:and:) returns a Double. Smaller is closer.
        let ranked = models.map { model -> (SimpleModelInfo, Double) in
            let distance = embedding.distance(between: input, and: model.name)
            return (model, distance)
        }.sorted { $0.1 < $1.1 } // Sort by distance ascending
        
        return ranked.prefix(limit).map { $0.0 }
    }
    
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForResource = 60
        config.timeoutIntervalForRequest = 60
        return URLSession(configuration: config)
    }()

    private func analyze(text: String, contextModels: [SimpleModelInfo]) async throws -> AIResponse {
        // 1. Prepare Request Data
        let requestBody = AIRequest(text: text, existingModels: contextModels)
        
        // 2. Configure Request
        var request = URLRequest(url: functionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        // timeout is handled by session configuration
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        print("[AIService] Sending request to \(functionURL)")
        if let jsonString = String(data: request.httpBody!, encoding: .utf8) {
            print("[AIService] Request Body: \(jsonString)")
        }
        
        // 3. Send Request with Retry Logic
        var lastError: Error?
        for attempt in 1...3 {
            do {
                let (data, response) = try await session.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("[AIService] Response Status Code: \(httpResponse.statusCode)")
                }
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("[AIService] Response Body: \(responseString)")
                }
                
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    print("[AIService] Error: Bad Server Response")
                    throw URLError(.badServerResponse)
                }
                
                // 4. Parse Response
                let aiResponse = try JSONDecoder().decode(AIResponse.self, from: data)
                return aiResponse
                
            } catch {
                print("[AIService] Attempt \(attempt) failed: \(error)")
                lastError = error
                // If it's a cancellation error, don't retry
                if let urlError = error as? URLError, urlError.code == .cancelled {
                    throw error
                }
                // Wait before retrying (exponential backoff: 1s, 2s, 4s)
                try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt-1)) * 1_000_000_000))
            }
        }
        
        throw lastError ?? URLError(.unknown)
    }
}
