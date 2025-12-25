import SwiftUI
import CoreLocation

struct DiscoveryView: View {
    @EnvironmentObject var userService: UserService
    @EnvironmentObject var messageService: MessageService
    @EnvironmentObject var purchaseManager: PurchaseManager
    
    @StateObject var audioPlayer = AudioPlayer()
    
    @State private var showFilter = false
    @State private var showMatchAnimation = false
    @State private var matchedPartnerName = ""
    @State private var showDisplaySettings = false
    
    // フィルタリング用ステート
    @State private var filterConditions: [String: String] = [:]
    @State private var minCommonPoints = 0
    @State private var commonPointsMode = "以上"
    @State private var maxDistance: Double = 100.0
    
    // 表示オプション
    @State private var showMatchedUsers = false
    @State private var showSkippedUsers = false
    
    var filteredUsers: [UserProfile] {
        let users = userService.discoveryUsers
        guard let currentUser = userService.currentUserProfile else { return users }
        
        return users.filter { user in
            // ブロック関係
            if currentUser.blockedUserIDs.contains(user.uid) || user.blockedUserIDs.contains(currentUser.uid) {
                return false
            }
            
            // 表示オプション
            let isMatched = currentUser.matchedUserIDs.contains(user.uid)
            if !showMatchedUsers && isMatched { return false }
            
            let isSkipped = currentUser.skippedUserIDs.contains(user.uid)
            if !showSkippedUsers && isSkipped { return false }
            
            // 距離フィルター
            if maxDistance < 100 {
                if let myLoc = currentUser.location, let userLoc = user.location {
                    let distanceInKm = myLoc.distance(from: userLoc) / 1000
                    if distanceInKm > maxDistance { return false }
                } else {
                    return false
                }
            }
            
            // 共通点フィルター
            let commonCount = calculateCommonPoints(user: user)
            if commonPointsMode == "ピッタリ" {
                if commonCount != minCommonPoints { return false }
            } else {
                if commonCount < minCommonPoints { return false }
            }
            
            // 属性フィルター
            for (key, requiredValue) in filterConditions {
                guard let userValue = user.profileItems[key], userValue == requiredValue else {
                    return false
                }
            }
            
            return true
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 位置情報アラート
                    if maxDistance < 100 && userService.currentUserProfile?.location == nil {
                        VStack(spacing: 8) {
                            Text("距離で絞り込むには位置情報をオンにしてください")
                                .font(.caption)
                                .foregroundColor(.red)
                            Button("設定を開く") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.caption.bold())
                        }
                        .padding()
                        .background(Color.white)
                    }
                    
                    if filteredUsers.isEmpty {
                        Spacer()
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
                                maxDistance = 100.0
                            }
                            .foregroundColor(.brandPurple)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 15) {
                                ForEach(filteredUsers) { user in
                                    UserDiscoveryCard(
                                        user: user,
                                        audioPlayer: audioPlayer,
                                        commonPoints: calculateCommonPoints(user: user),
                                        distanceText: calculateDistanceInfo(targetUser: user),
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
            .sheet(isPresented: $showFilter) {
                FilterView(
                    filterConditions: $filterConditions,
                    minCommonPoints: $minCommonPoints,
                    commonPointsMode: $commonPointsMode,
                    maxDistance: $maxDistance
                )
            }
            .sheet(isPresented: $showDisplaySettings) {
                displaySettingsSheet
            }
            .fullScreenCover(isPresented: $showMatchAnimation) {
                MatchAnimationView(partnerName: matchedPartnerName, isPresented: $showMatchAnimation)
            }
            .refreshable {
                await userService.fetchUsersForDiscovery()
            }
            .task {
                await syncProStatus()
                await userService.fetchUsersForDiscovery()
            }
        }
    }
    
    // Helper Methods
    private func syncProStatus() async {
        guard let user = userService.currentUserProfile else { return }
        if purchaseManager.isPro != user.isProUser {
            await userService.syncProStatus(isPro: purchaseManager.isPro)
        }
    }
    
    private func calculateCommonPoints(user: UserProfile) -> Int {
        guard let myProfile = userService.currentUserProfile else { return 0 }
        var count = 0
        for (key, myVal) in myProfile.profileItems {
            let isPublic = user.privacySettings[key] ?? true
            if isPublic, let userVal = user.profileItems[key], !userVal.isEmpty, userVal == myVal {
                count += 1
            }
        }
        return count
    }
    
    private func calculateDistanceInfo(targetUser: UserProfile) -> String? {
        guard let currentUser = userService.currentUserProfile,
              purchaseManager.isPro,
              currentUser.isLocationPublic,
              targetUser.isLocationPublic,
              let myLoc = currentUser.location,
              let targetLoc = targetUser.location else { return nil }
        
        let distanceKm = myLoc.distance(from: targetLoc) / 1000
        if distanceKm < 1 { return "1km以内" }
        if distanceKm < 5 { return "5km以内" }
        let rounded = Int(ceil(distanceKm / 5.0) * 5.0)
        return "\(rounded)km以内"
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") { showDisplaySettings = false }
                }
            }
        }
        .presentationDetents([.height(250)])
    }
}

// ユーザーカードビュー
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
                            
                            if user.privacySettings["age"] ?? true, let age = user.profileItems["age"] {
                                Text(age).font(.subheadline).foregroundColor(.secondary)
                            }
                        }
                        
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
                            
                            if let dist = distanceText {
                                HStack(spacing: 2) {
                                    Image(systemName: "location.fill").font(.caption2)
                                    Text(dist).font(.caption)
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
            
            // 自己紹介ボイス再生ボタン
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
            
            // アプローチボタン
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
