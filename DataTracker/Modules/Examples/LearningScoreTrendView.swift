import SwiftUI

struct LearningScoreTrendView: View {
    @State private var granularity: Int = 1
    @State private var compareSubject: String = "语文"
    private let subjects = ["语文", "数学", "英语"]
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("粒度", selection: $granularity) {
                    Text("日").tag(0)
                    Text("周").tag(1)
                    Text("月").tag(2)
                }
                .pickerStyle(.segmented)
                Picker("对比科目", selection: $compareSubject) {
                    ForEach(subjects, id: \.self) { s in
                        Text(s).tag(s)
                    }
                }
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.purple.opacity(0.15))
                    .frame(height: 220)
                    .overlay(Text("成绩趋势图占位"))
                Button("导出占位") {}
            }
            .padding()
            .navigationTitle("学习成绩分析")
        }
    }
}

#Preview {
    LearningScoreTrendView()
}
