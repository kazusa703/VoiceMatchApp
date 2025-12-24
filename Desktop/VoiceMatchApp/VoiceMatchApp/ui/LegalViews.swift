import SwiftUI

struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                Text("利用規約")
                    .font(.largeTitle.bold())
                    .padding(.bottom)
                
                Group {
                    Text("第1条（はじめに）")
                        .font(.headline)
                    Text("この利用規約は、VoiceMatch（以下「本アプリ」）の利用条件を定めるものです。ユーザーの皆様には、本規約に従って本サービスをご利用いただきます。")
                    
                    Text("第2条（禁止事項）")
                        .font(.headline)
                    Text("ユーザーは、本サービスの利用にあたり、以下の行為をしてはなりません。\n・法令または公序良俗に違反する行為\n・犯罪行為に関連する行為\n・他のユーザーに対する嫌がらせや誹謗中傷\n・不快な性的コンテンツの投稿")
                    
                    Text("第3条（免責事項）")
                        .font(.headline)
                    Text("本アプリは、ユーザー同士のマッチングの機会を提供するものであり、マッチングの結果について何ら保証するものではありません。")
                }
                .font(.body)
                .foregroundColor(.primary)
            }
            .padding()
        }
        .navigationTitle("利用規約")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                Text("プライバシーポリシー")
                    .font(.largeTitle.bold())
                    .padding(.bottom)
                
                Group {
                    Text("1. 収集する情報")
                        .font(.headline)
                    Text("本アプリは、ユーザー名、プロフィール画像、音声データ、および利用状況に関するデータを収集します。")
                    
                    Text("2. 利用目的")
                        .font(.headline)
                    Text("収集した情報は、本サービスの提供、運営、およびユーザーサポートのために利用します。")
                    
                    Text("3. 第三者提供")
                        .font(.headline)
                    Text("法令に基づく場合を除き、ユーザーの同意なく個人情報を第三者に提供することはありません。")
                    
                    Text("4. アカウント削除")
                        .font(.headline)
                    Text("ユーザーは設定画面からいつでもアカウントを削除することができ、これに伴い個人情報も削除されます。")
                }
                .font(.body)
                .foregroundColor(.primary)
            }
            .padding()
        }
        .navigationTitle("プライバシーポリシー")
        .navigationBarTitleDisplayMode(.inline)
    }
}
