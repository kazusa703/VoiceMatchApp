import SwiftUI
import AVFoundation
import FirebaseAuth

struct ProfileView: View {
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var purchaseManager: PurchaseManager
    
    @State private var showEditProfile = false
    @State private var showSettings = false
    @State private var showPaywall = false
    
    @StateObject var audioPlayer = AudioPlayer()
    
    var body: some View {
        NavigationView {
            ScrollView {
                if let user = userService.currentUserProfile {
                    VStack(spacing: 24) {
                        // 1. プロフィールトップ
                        VStack(spacing: 16) {
                            // アバター（グラデーション枠付き）
                            UserAvatarView(imageURL: user.profileImageURL, size: 100)
                                .padding(4)
                                .background(LinearGradient.instaGradient)
                                .clipShape(Circle())
                            
                            Text(user.username)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            // 統計データ
                            HStack(spacing: 40) {
                                VStack(spacing: 4) {
                                    Text("\(user.matchCountCurrentCycle)")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    Text("今日の送信")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                VStack(spacing: 4) {
                                    // 残り回数の計算
                                    let limit = user.isProUser ? 50 : 5
                                    let remaining = max(0, limit - user.matchCountCurrentCycle)
                                    Text("\(remaining)")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(remaining == 0 ? .red : .primary)
                                    Text("残り回数")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                VStack(spacing: 4) {
                                    Text(purchaseManager.isPro ? "Pro" : "Free")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(purchaseManager.isPro ? .brandPurple : .primary)
                                    Text("プラン")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.top)
                        
                        // 2. Proアップグレードバナー
                        if !purchaseManager.isPro {
                            Button(action: { showPaywall = true }) {
                                HStack {
                                    Image(systemName: "crown.fill")
                                        .foregroundColor(.yellow)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Proプランにアップグレード")
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        Text("無制限マッチ・ボイス効果全開放")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.white)
                                }
                                .padding()
                                .background(LinearGradient.instaGradient)
                                .cornerRadius(15)
                                .shadow(color: .brandPurple.opacity(0.4), radius: 8, y: 4)
                            }
                            .padding(.horizontal)
                        }
                        
                        // 3. プロフィール編集ボタン
                        Button(action: { showEditProfile = true }) {
                            Text("プロフィールを編集")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.gray.opacity(0.1))
                                .foregroundColor(.primary)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        
                        // 4. 自己紹介ボイスボタン
                        if let audioURL = user.bioAudioURL, let url = URL(string: audioURL) {
                            Button(action: {
                                if audioPlayer.isPlaying && audioPlayer.currentlyPlayingURL == audioURL {
                                    audioPlayer.stopPlayback()
                                } else {
                                    audioPlayer.startPlayback(url: url)
                                }
                            }) {
                                HStack {
                                    Image(systemName: "mic.fill")
                                        .foregroundColor(.brandPurple)
                                    Text("登録済みの自己紹介ボイス")
                                        .foregroundColor(.brandPurple)
                                    Spacer()
                                    if audioPlayer.isPlaying {
                                        Image(systemName: "waveform")
                                            .foregroundColor(.brandPurple)
                                    }
                                }
                                .padding()
                                .background(Color.brandPurple.opacity(0.05))
                                .cornerRadius(15)
                            }
                            .padding(.horizontal)
                        }
                        
                        Divider().padding(.horizontal)
                        
                        // 5. 詳細データ
                        VStack(alignment: .leading, spacing: 20) {
                            Text("詳細データ")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VStack(spacing: 0) {
                                DetailRow(icon: "mappin.and.ellipse", title: "居住地", value: user.profileItems["residence"])
                                Divider().padding(.leading, 50)
                                DetailRow(icon: "briefcase", title: "職業", value: user.profileItems["occupation"])
                                Divider().padding(.leading, 50)
                                DetailRow(icon: "person", title: "年齢", value: user.profileItems["age"])
                            }
                            .background(Color.white) // 背景白
                            .padding(.horizontal)
                        }
                        
                        Spacer(minLength: 100)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("マイページ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.black)
                    }
                }
            }
            .sheet(isPresented: $showEditProfile) { ProfileEditView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .refreshable {
                if let uid = userService.currentUserProfile?.uid {
                    try? await userService.fetchOrCreateUserProfile(uid: uid)
                }
            }
        }
    }
}

// 詳細データの行デザイン
struct DetailRow: View {
    let icon: String
    let title: String
    let value: String?
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 30)
                .foregroundColor(.gray)
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value ?? "未設定")
                .fontWeight(.medium)
        }
        .padding()
    }
}
