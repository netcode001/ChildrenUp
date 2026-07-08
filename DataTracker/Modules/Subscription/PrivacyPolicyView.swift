import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("隐私政策")
                    .font(.largeTitle)
                    .bold()
                    .padding(.bottom, 10)
                
                Group {
                    section(title: "1. 信息收集", content: """
                    我们尊重并保护您的隐私。在使用 FlashMo Pro 时，我们可能会收集以下信息：
                    
                    - 账号信息：如果您注册账号，我们会收集您的用户名、邮箱地址等信息。
                    - 使用数据：我们会收集您在使用应用过程中产生的数据，如追踪记录、设置偏好等。
                    - 设备信息：我们会收集您的设备型号、操作系统版本等信息，用于优化应用体验。
                    """)
                    
                    section(title: "2. 信息使用", content: """
                    我们收集的信息将用于以下目的：
                    
                    - 提供和改进本应用的服务。
                    - 个性化您的用户体验。
                    - 进行数据分析和研究。
                    - 发送服务通知和更新。
                    """)
                    
                    section(title: "3. 数据存储与同步", content: """
                    - 本地存储：您的数据默认存储在您的设备本地。
                    - iCloud 同步：如果您开启 iCloud 同步功能，您的数据将通过 Apple 的 iCloud 服务进行加密传输和存储。我们无法直接访问您的 iCloud 数据。
                    """)
                    
                    section(title: "4. 信息共享", content: """
                    我们不会将您的个人信息出售给第三方。我们仅在以下情况下共享您的信息：
                    
                    - 获得您的明确同意。
                    - 遵守法律法规的要求。
                    - 保护我们的合法权益。
                    """)
                    
                    section(title: "5. 数据安全", content: """
                    我们采取合理的安全措施保护您的个人信息，防止未经授权的访问、使用或泄露。
                    
                    请注意，互联网传输并非绝对安全，我们无法保证信息的绝对安全。
                    """)
                    
                    section(title: "6. 第三方服务", content: """
                    本应用可能包含指向第三方网站或服务的链接。我们不对第三方的内容或隐私惯例负责。建议您在使用第三方服务前阅读其隐私政策。
                    """)
                    
                    section(title: "7. 儿童隐私", content: """
                    本应用不面向 13 岁以下的儿童。我们不会有意收集儿童的个人信息。如果您发现我们误收集了儿童的信息，请联系我们，我们将尽快删除。
                    """)
                    
                    section(title: "8. 政策更新", content: """
                    我们可能会不时更新本隐私政策。更新后的政策将在本应用中公布。
                    """)
                    
                    section(title: "9. 联系我们", content: """
                    如果您对本隐私政策有任何疑问，请联系我们：privacy@flashmo.app
                    """)
                }
            }
            .padding()
        }
        .navigationTitle("隐私政策")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func section(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
