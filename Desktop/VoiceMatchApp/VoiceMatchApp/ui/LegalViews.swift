import SwiftUI

// MARK: - 利用規約同意画面（初回登録時に表示）
struct TermsAgreementView: View {
    @Binding var hasAgreedToTerms: Bool
    @State private var agreedToTerms = false
    @State private var agreedToPrivacy = false
    @State private var showTerms = false
    @State private var showPrivacy = false
    
    var canProceed: Bool {
        agreedToTerms && agreedToPrivacy
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            VStack(spacing: 16) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.brandPurple)
                
                Text("利用規約への同意")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("VoiceMatchをご利用いただくには、以下の規約に同意していただく必要があります。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 40)
            .padding(.bottom, 30)
            
            // 同意内容
            VStack(spacing: 16) {
                // 利用規約
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Button(action: { agreedToTerms.toggle() }) {
                            Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                                .font(.title2)
                                .foregroundColor(agreedToTerms ? .brandPurple : .gray)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("利用規約に同意する")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("不適切なコンテンツの投稿、嫌がらせ行為を行わないことに同意します")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: { showTerms = true }) {
                            Text("全文")
                                .font(.caption)
                                .foregroundColor(.brandPurple)
                        }
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                
                // プライバシーポリシー
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Button(action: { agreedToPrivacy.toggle() }) {
                            Image(systemName: agreedToPrivacy ? "checkmark.square.fill" : "square")
                                .font(.title2)
                                .foregroundColor(agreedToPrivacy ? .brandPurple : .gray)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("プライバシーポリシーに同意する")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("個人情報の取り扱いについて理解し、同意します")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: { showPrivacy = true }) {
                            Text("全文")
                                .font(.caption)
                                .foregroundColor(.brandPurple)
                        }
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
            }
            .padding(.horizontal)
            
            Spacer()
            
            // 重要事項
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("以下の行為は禁止されています")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("• 不適切な性的コンテンツの投稿")
                    Text("• 他のユーザーへの嫌がらせや誹謗中傷")
                    Text("• スパム行為や商業目的の利用")
                    Text("• 18歳未満の方の利用")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Spacer()
            
            // 同意ボタン
            Button(action: {
                hasAgreedToTerms = true
            }) {
                Text("同意して始める")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canProceed ? Color.brandPurple : Color.gray)
                    .cornerRadius(30)
            }
            .disabled(!canProceed)
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .sheet(isPresented: $showTerms) {
            NavigationView {
                TermsOfServiceView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("閉じる") { showTerms = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showPrivacy) {
            NavigationView {
                PrivacyPolicyView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("閉じる") { showPrivacy = false }
                        }
                    }
            }
        }
    }
}

// MARK: - 利用規約
struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("利用規約")
                    .font(.largeTitle.bold())
                    .padding(.bottom)
                
                Group {
                    TermsSection(
                        title: "第1条（はじめに）",
                        content: "この利用規約（以下「本規約」）は、VoiceMatch（以下「本アプリ」）の利用条件を定めるものです。ユーザーの皆様には、本規約に従って本サービスをご利用いただきます。本アプリを利用することにより、本規約に同意したものとみなされます。"
                    )
                    
                    TermsSection(
                        title: "第2条（利用資格）",
                        content: "本アプリは18歳以上の方のみご利用いただけます。18歳未満の方の利用は固くお断りいたします。"
                    )
                    
                    TermsSection(
                        title: "第3条（禁止事項）",
                        content: """
                        ユーザーは、本サービスの利用にあたり、以下の行為をしてはなりません。
                        
                        • 法令または公序良俗に違反する行為
                        • 犯罪行為に関連する行為
                        • 他のユーザーに対する嫌がらせ、脅迫、誹謗中傷
                        • 不適切な性的コンテンツの投稿
                        • 暴力的、差別的なコンテンツの投稿
                        • スパム行為や商業目的の利用
                        • 他人になりすます行為
                        • 虚偽の情報を登録する行為
                        • 本アプリの運営を妨害する行為
                        • その他、運営者が不適切と判断する行為
                        """
                    )
                    
                    TermsSection(
                        title: "第4条（アカウントの停止・削除）",
                        content: "本規約に違反した場合、事前の通知なくアカウントを停止または削除する場合があります。また、ユーザーは設定画面からいつでもアカウントを削除することができます。"
                    )
                    
                    TermsSection(
                        title: "第5条（通報機能）",
                        content: "ユーザーは、本規約に違反するコンテンツやユーザーを発見した場合、アプリ内の通報機能を使用して報告することができます。通報された内容は運営者が確認し、適切な対応を行います。"
                    )
                    
                    TermsSection(
                        title: "第6条（免責事項）",
                        content: "本アプリは、ユーザー同士のマッチングの機会を提供するものであり、マッチングの結果やユーザー間のやり取りについて何ら保証するものではありません。ユーザー間のトラブルについて、運営者は一切の責任を負いません。"
                    )
                    
                    TermsSection(
                        title: "第7条（規約の変更）",
                        content: "運営者は、必要に応じて本規約を変更することができます。変更後の規約は、アプリ内で通知した時点から効力を生じるものとします。"
                    )
                }
                
                Text("最終更新日: 2024年1月1日")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top)
            }
            .padding()
        }
        .navigationTitle("利用規約")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - プライバシーポリシー
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("プライバシーポリシー")
                    .font(.largeTitle.bold())
                    .padding(.bottom)
                
                Group {
                    TermsSection(
                        title: "1. 収集する情報",
                        content: """
                        本アプリは、以下の情報を収集します。
                        
                        • ユーザー名、プロフィール画像
                        • 音声データ（ボイスプロフィール、メッセージ）
                        • プロフィール情報（年齢、趣味など）
                        • 利用状況に関するデータ
                        • デバイス情報
                        """
                    )
                    
                    TermsSection(
                        title: "2. 利用目的",
                        content: """
                        収集した情報は、以下の目的で利用します。
                        
                        • 本サービスの提供・運営
                        • ユーザー同士のマッチング
                        • ユーザーサポート
                        • サービスの改善
                        • 不正利用の防止
                        """
                    )
                    
                    TermsSection(
                        title: "3. 第三者提供",
                        content: "法令に基づく場合を除き、ユーザーの同意なく個人情報を第三者に提供することはありません。"
                    )
                    
                    TermsSection(
                        title: "4. データの保管",
                        content: "ユーザーのデータは、適切なセキュリティ対策を施したサーバーに保管されます。"
                    )
                    
                    TermsSection(
                        title: "5. アカウント削除",
                        content: "ユーザーは設定画面からいつでもアカウントを削除することができます。アカウント削除により、すべての個人情報、音声データ、メッセージ履歴が完全に削除されます。"
                    )
                    
                    TermsSection(
                        title: "6. お問い合わせ",
                        content: "プライバシーに関するお問い合わせは、アプリ内のサポート機能よりご連絡ください。"
                    )
                }
                
                Text("最終更新日: 2024年1月1日")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top)
            }
            .padding()
        }
        .navigationTitle("プライバシーポリシー")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - ヘルパービュー
struct TermsSection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.body)
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    TermsAgreementView(hasAgreedToTerms: .constant(false))
}
