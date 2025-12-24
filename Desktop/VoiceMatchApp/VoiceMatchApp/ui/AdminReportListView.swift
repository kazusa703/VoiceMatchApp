import SwiftUI
import FirebaseFirestore

// 通報データの構造体
struct Report: Identifiable, Codable {
    @DocumentID var id: String?
    let reporterID: String
    let targetID: String
    let reason: String
    let comment: String
    let audioURL: String?
    let timestamp: Date
}

struct AdminReportListView: View {
    @EnvironmentObject var userService: UserService
    @State private var reports: [Report] = []
    @State private var isLoading = true
    
    private let db = Firestore.firestore()
    
    var body: some View {
        List {
            if reports.isEmpty && !isLoading {
                Text("現在、未対応の通報はありません。")
                    .foregroundColor(.secondary)
            }
            
            ForEach(reports) { report in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(report.reason)
                            .font(.headline)
                            .foregroundColor(.red)
                        Spacer()
                        Text(report.timestamp, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("対象者ID: \(report.targetID)")
                        .font(.system(size: 10, design: .monospaced))
                    
                    if !report.comment.isEmpty {
                        Text("詳細: \(report.comment)")
                            .font(.subheadline)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(5)
                    }
                    
                    // AdminReportListView.swift の ForEach(reports) { report in ... } 内の HStack を書き換え

                    HStack {
                        // 注意勧告ボタン
                        Button(action: {
                            Task { await userService.sendWarningNotification(targetUID: report.targetID) }
                        }) {
                            Label("注意", systemImage: "exclamationmark.triangle")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)

                        // ★追加: 手動ロックボタン
                        Button(action: {
                            Task { await userService.updateAccountLockStatus(targetUID: report.targetID, isLocked: true) }
                        }) {
                            Label("停止", systemImage: "lock.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.bordered)
                        
                        // ★追加: ロック解除ボタン
                        Button(action: {
                            Task { await userService.updateAccountLockStatus(targetUID: report.targetID, isLocked: false) }
                        }) {
                            Label("解除", systemImage: "lock.open.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Button(action: {
                            deleteReport(id: report.id)
                        }) {
                            Text("完了")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("通報一覧")
        .onAppear { fetchReports() }
    }
    
    private func fetchReports() {
        db.collection("reports")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { snapshot, _ in
                guard let documents = snapshot?.documents else { return }
                self.reports = documents.compactMap { try? $0.data(as: Report.self) }
                self.isLoading = false
            }
    }
    
    private func deleteReport(id: String?) {
        guard let id = id else { return }
        db.collection("reports").document(id).delete()
    }
}
