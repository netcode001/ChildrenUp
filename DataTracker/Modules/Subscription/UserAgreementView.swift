import SwiftUI

struct UserAgreementView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("用户协议")
                    .font(.largeTitle)
                    .bold()
                    .padding(.bottom, 10)
                
                Group {
                    section(title: "1. 服务说明", content: """
                    FlashMo Pro（以下简称"本应用"）是一款个人数据追踪和分析工具。本应用提供数据记录、统计分析、AI 辅助等功能。
                    
                    我们致力于为用户提供优质的服务，但不对服务的及时性、安全性、准确性作任何担保。
                    """)
                    
                    section(title: "2. 用户账号", content: """
                    您在使用本应用时可能需要注册账号。您有责任妥善保管您的账号信息和密码。
                    
                    因您保管不善可能导致账号被他人使用（包括但不限于遭受黑客攻击、账号被盗用等）而造成的一切损失，由您自行承担。
                    """)
                    
                    section(title: "3. 订阅服务", content: """
                    本应用提供 FlashMo Pro 订阅服务（包括月度、年度订阅及终身买断）。
                    
                    - 订阅周期：订阅将根据您选择的方案自动续期。
                    - 付款：确认购买后，费用将从您的 Apple ID 账户扣除。
                    - 取消订阅：如需取消续订，请在当前订阅周期结束前至少 24 小时在 Apple ID 设置中关闭自动续订。
                    """)
                    
                    section(title: "4. 用户行为规范", content: """
                    您同意不利用本应用进行任何违法或不当活动，包括但不限于：
                    - 上传或发布违反法律法规的内容。
                    - 干扰或破坏本应用的服务或服务器。
                    - 未经授权访问本应用的系统或数据。
                    """)
                    
                    section(title: "5. 免责声明", content: """
                    本应用提供的 AI 分析建议仅供参考，不构成任何专业（如医疗、金融等）建议。您应根据自身情况自行判断并承担风险。
                    
                    对于因不可抗力或我们无法控制的原因造成的服务中断或数据丢失，我们将尽力减少损失，但不承担相关责任。
                    """)
                    
                    section(title: "6. 协议修改", content: """
                    我们保留随时修改本协议的权利。修改后的协议将在本应用中公布。如果您继续使用本应用，即视为您接受修改后的协议。
                    """)
                    
                    section(title: "7. 联系我们", content: """
                    如果您对本协议有任何疑问，请联系我们：support@flashmo.app
                    """)
                }
            }
            .padding()
        }
        .navigationTitle("用户协议")
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
        UserAgreementView()
    }
}
