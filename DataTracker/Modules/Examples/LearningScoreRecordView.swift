import SwiftUI

struct LearningScoreRecordView: View {
    @State private var subject: String = "语文"
    @State private var score: String = ""
    @State private var examName: String = ""
    @State private var date: Date = .now
    private let subjects = ["语文", "数学", "英语"]
    var body: some View {
        NavigationStack {
            Form {
                Picker("科目", selection: $subject) {
                    ForEach(subjects, id: \.self) { s in
                        Text(s).tag(s)
                    }
                }
                TextField("分数(0–100)", text: $score)
                    .keyboardType(.numberPad)
                TextField("考试名称", text: $examName)
                DatePicker("日期", selection: $date, displayedComponents: [.date])
                Button("提交占位") {}
                    .disabled(score.isEmpty || examName.isEmpty)
            }
            .navigationTitle("学习成绩记录")
        }
    }
}

#Preview {
    LearningScoreRecordView()
}
