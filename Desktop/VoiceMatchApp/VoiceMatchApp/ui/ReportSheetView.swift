import SwiftUI

struct ReportSheetView: View {
    let targetUID: String
    let audioURL: String?
    @EnvironmentObject var userService: UserService
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedReason = "セクシャルハラスメント"
    @State private var comment = ""
    @State private var isSubmitting = false
    
    let reasons = ["セクシャルハラスメント", "嫌がらせ・ストーカー", "不快な音声・暴言", "出会い目的以外", "詐欺・スパム", "その他"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("通報の理由")) {
                    Picker("理由を選択", selection: $selectedReason) {
                        ForEach(reasons, id: \.self) { Text($0) }
                    }
                }
                
                Section(header: Text("具体的な内容 (任意)")) {
                    TextEditor(text: $comment)
                        .frame(height: 100)
                }
            }
            .navigationTitle("ユーザーを通報")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("送信") {
                        submitReport()
                    }
                    .fontWeight(.bold)
                    .disabled(isSubmitting)
                }
            }
        }
    }
    
    private func submitReport() {
        isSubmitting = true
        Task {
            await userService.reportUser(targetUID: targetUID, reason: selectedReason, comment: comment, audioURL: audioURL)
            dismiss()
        }
    }
}
