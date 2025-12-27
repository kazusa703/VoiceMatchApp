import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var purchaseManager: PurchaseManager
    
    @State private var showProfileEdit = false
    @State private var showSettings = false
    @State private var showPurchase = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // プロフィールカード
                    profileCard
                    
                    // ボイスプロフィール一覧
                    voiceProfilesSection
                    
                    // プレミアム
                    premiumSection
                    
                    // 設定ボタン
                    settingsButton
                    
                    // ログアウト
                    logoutButton
                    
                    Spacer().frame(height: 50)
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("プロフィール")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showProfileEdit) {
                if let user = userService.currentUserProfile {
                    ProfileEditView(user: user)
                        .environmentObject(userService)
                        .environmentObject(purchaseManager)
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(authService)
                    .environmentObject(userService)
            }
            .sheet(isPresented: $showPurchase) {
                PurchaseView()
                    .environmentObject(purchaseManager)
            }
        }
    }
    
    // MARK: - Profile Card
    
    private var profileCard: some View {
        VStack(spacing: 16) {
            if let user = userService.currentUserProfile {
                UserAvatarView(imageURL: user.iconImageURL, size: 100)
                
                Text(user.username)
                    .font(.title2)
                    .fontWeight(.bold)
                
                if user.hasNaturalVoice {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("地声登録済み")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("地声を登録してください")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                if purchaseManager.isPro {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                        Text("プレミアム会員")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(15)
                }
            } else {
                ProgressView()
                    .padding()
            }
            
            // プロフィール編集ボタン
            Button(action: {
                showProfileEdit = true
            }) {
                HStack {
                    Image(systemName: "pencil")
                    Text("プロフィールを編集")
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.brandPurple)
                .cornerRadius(20)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(15)
    }
    
    // MARK: - Voice Profiles Section
    
    private var voiceProfilesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ボイスプロフィール")
                .font(.headline)
            
            if let user = userService.currentUserProfile {
                ForEach(VoiceProfileConstants.items) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.displayName)
                                    .font(.subheadline)
                                
                                if item.isRequired {
                                    Text("必須")
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.red)
                                        .cornerRadius(4)
                                }
                            }
                            
                            if let voice = user.voiceProfiles[item.key] {
                                Text(String(format: "%.1f秒", voice.duration))
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else {
                                Text("未設定")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: user.voiceProfiles[item.key] != nil ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(user.voiceProfiles[item.key] != nil ? .green : .gray)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
    }
    
    // MARK: - Premium Section
    
    private var premiumSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "crown.fill")
                    .foregroundColor(.yellow)
                Text("プレミアム")
                    .font(.headline)
            }
            
            if purchaseManager.isPro {
                Text("ご利用ありがとうございます！")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 8) {
                    Text("すべてのエフェクトが使い放題")
                    Text("1日100いいね")
                    Text("広告なし")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                Button(action: {
                    showPurchase = true
                }) {
                    Text("プレミアムに登録")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(20)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(15)
    }
    
    // MARK: - Settings Button
    
    private var settingsButton: some View {
        Button(action: {
            showSettings = true
        }) {
            HStack {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.gray)
                Text("設定")
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(15)
        }
    }
    
    // MARK: - Logout Button
    
    private var logoutButton: some View {
        Button(action: {
            authService.signOut()
        }) {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .foregroundColor(.red)
                Text("ログアウト")
                    .foregroundColor(.red)
                Spacer()
            }
            .padding()
            .background(Color.white)
            .cornerRadius(15)
        }
    }
}
