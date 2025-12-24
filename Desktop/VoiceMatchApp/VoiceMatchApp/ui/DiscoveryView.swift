import SwiftUI
import AVFoundation
import CoreLocation

struct DiscoveryView: View {
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var messageService: MessageService
    // 課金状態確認用
    @EnvironmentObject var purchaseManager: PurchaseManager
    
    @StateObject var audioPlayer = AudioPlayer()
    
    // 検索・絞り込みフィルター
    @State private var showFilter = false
    @State private var filterConditions: [String: String] = [:]
    @State private var minCommonPoints = 0
    @State private var commonPointsMode = "以上"
    
    // ★追加: 距離フィルター用の状態変数 (初期値100.0)
    @State private var maxDistance: Double = 100.0
    
    @State private var showMatchedUsers = false
    @State private var showSkippedUsers = false
    @State private var showDisplaySettings = false
    
    var filteredUsers: [UserProfile] {
        guard let currentUser = userService.currentUserProfile else { return [] }
        
        return userService.discoveryUsers.filter { user in
            // 1. 表示オプションによるフィルタリング
            if !showMatchedUsers && currentUser.matchedUserIDs.contains(user.uid) { return false }
            if !showSkippedUsers && currentUser.skippedUserIDs.contains(user.uid) { return false }
            
            // ★追加: 距離フィルタの適用
            // maxDistance が 100 未満の場合のみ制限を適用（100は「制限なし」の扱い）
            if maxDistance < 100 {
                // 自分と相手の両方が位置情報を持っている場合のみ計算
                if let myLoc = currentUser.location, let userLoc = user.location {
                    let distanceInKm = myLoc.distance(from: userLoc) / 1000
                    if distanceInKm > maxDistance { return false }
                } else {
                    // 位置情報が取得できていないユーザーは、距離指定時は非表示にする
                    return false
                }
            }
            
            // 2. 共通点数フィルタ (非公開設定を考慮した計算)
            let commonCount = calculateCommonPoints(user: user)
            if commonPointsMode == "ピッタリ" {
                if commonCount != minCommonPoints { return false }
            } else {
                if commonCount < minCommonPoints { return false }
            }
            
            // 3. 必須項目一致フィルタ
            for (key, value) in filterConditions {
                if user.profileItems[key] != value { return false }
            }
            
            return true
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
                if filteredUsers.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("条件に合うユーザーがいません")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Button("条件をクリア") {
                            filterConditions.removeAll()
                            minCommonPoints = 0
                            commonPointsMode = "以上"
                            maxDistance = 100.0 // 距離条件もリセット
                        }
                        .foregroundColor(.brandPurple)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 15) {
                            ForEach(filteredUsers) { user in
                                // 距離情報の計算
                                let distanceInfo = calculateDistanceInfo(targetUser: user)
                                
                                UserDiscoveryCard(
                                    user: user,
                                    audioPlayer: audioPlayer,
                                    commonPoints: calculateCommonPoints(user: user),
                                    distanceText: distanceInfo,
                                    onSkip: {
                                        Task { await userService.skipUser(targetUID: user.uid) }
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("探す")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showDisplaySettings = true }) {
                        Image(systemName: "eye.circle").foregroundColor(.primary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showFilter = true }) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor((!filterConditions.isEmpty || minCommonPoints > 0 || maxDistance < 100) ? .brandPurple : .primary)
                    }
                }
            }
            .sheet(isPresented: $showDisplaySettings) {
                displaySettingsSheet
            }
            .sheet(isPresented: $showFilter) {
                // ★修正: maxDistanceを渡す
                FilterView(
                    filterConditions: $filterConditions,
                    minCommonPoints: $minCommonPoints,
                    commonPointsMode: $commonPointsMode,
                    maxDistance: $maxDistance
                )
            }
            .refreshable {
                await userService.fetchUsersForDiscovery()
            }
        }
    }
    
    // 共通点の計算ロジック（相手の非公開設定を尊重）
    func calculateCommonPoints(user: UserProfile) -> Int {
        guard let myProfile = userService.currentUserProfile else { return 0 }
        var count = 0
        for (key, myVal) in myProfile.profileItems {
            // 相手がその項目を「公開」に設定している場合のみ、一致をカウントする
            let isPublic = user.privacySettings[key] ?? true
            if isPublic, let userVal = user.profileItems[key], !userVal.isEmpty, userVal == myVal {
                count += 1
            }
        }
        return count
    }
    
    // 距離情報の計算ロジック
    private func calculateDistanceInfo(targetUser: UserProfile) -> String? {
        guard let currentUser = userService.currentUserProfile else { return nil }
        
        // 条件: 自分がProプラン && 自分と相手が位置情報を公開 && 両者の位置情報が存在
        if purchaseManager.isPro,
           currentUser.isLocationPublic,
           targetUser.isLocationPublic,
           let myLoc = currentUser.location,
           let targetLoc = targetUser.location {
            
            return getRoughDistance(myLoc: myLoc, userLoc: targetLoc)
        }
        return nil
    }
    
    // 距離を「大まかなエリア」に変換するヘルパー
    private func getRoughDistance(myLoc: CLLocation?, userLoc: CLLocation?) -> String? {
        guard let my = myLoc, let user = userLoc else { return nil }
        let meters = my.distance(from: user)
        let km = meters / 1000
        
        if km < 1 { return "1km以内" }
        if km < 5 { return "5km以内" }
        if km < 10 { return "10km以内" }
        if km < 50 { return "50km以内" }
        return "遠くにいます"
    }
    
    private var displaySettingsSheet: some View {
        NavigationView {
            List {
                Section(header: Text("表示オプション")) {
                    Toggle("マッチした人を表示", isOn: $showMatchedUsers)
                    Toggle("拒否した人を表示", isOn: $showSkippedUsers)
                }
            }
            .navigationTitle("表示設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") { showDisplaySettings = false }
                }
            }
        }
        .presentationDetents([.height(250)])
    }
}

// MARK: - UserDiscoveryCard
struct UserDiscoveryCard: View {
    let user: UserProfile
    @ObservedObject var audioPlayer: AudioPlayer
    let commonPoints: Int
    let distanceText: String?
    var onSkip: () -> Void
    
    var body: some View {
        VStack(spacing: 15) {
            HStack {
                UserAvatarView(imageURL: user.profileImageURL, size: 50)
                
                NavigationLink(destination: UserProfileDetailView(user: user)) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text(user.username)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            // 年齢が非公開ならカード上でも表示しない
                            if user.privacySettings["age"] ?? true, let age = user.profileItems["age"], !age.isEmpty {
                                Text(age)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // 共通点と距離を表示
                        HStack {
                            if commonPoints > 0 {
                                Text("共通点 \(commonPoints)個")
                                    .font(.caption)
                                    .foregroundColor(.brandPurple)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.brandPurple.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            
                            // 距離表示
                            if let distance = distanceText {
                                HStack(spacing: 2) {
                                    Image(systemName: "location.fill")
                                        .font(.caption2)
                                    Text(distance)
                                        .font(.caption)
                                }
                                .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
                
                Button(action: onSkip) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            
            // 音声再生セクション
            if let audioURL = user.bioAudioURL, let url = URL(string: audioURL) {
                Button(action: {
                    if audioPlayer.isPlaying && audioPlayer.currentlyPlayingURL == audioURL {
                        audioPlayer.stopPlayback()
                    } else {
                        audioPlayer.startPlayback(url: url)
                    }
                }) {
                    HStack {
                        Image(systemName: (audioPlayer.isPlaying && audioPlayer.currentlyPlayingURL == audioURL) ? "pause.circle.fill" : "play.circle.fill")
                            .font(.title)
                            .foregroundColor(.brandPurple)
                        
                        Spacer()
                        Text(audioPlayer.isPlaying && audioPlayer.currentlyPlayingURL == audioURL ? "再生中..." : "声を聴く")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.brandPurple)
                    }
                    .padding()
                    .background(Color.bubbleGray)
                    .cornerRadius(15)
                }
            }
            
            NavigationLink(destination: VoiceRecordingView(receiverID: user.uid, mode: .approach)) {
                Text("この声にメッセージを送る")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(LinearGradient.instaGradient)
                    .cornerRadius(10)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 5)
    }
}
