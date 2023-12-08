//
//  CameraMusicViewModel.swift
//  sotsugyo
//
//  Created by saki on 2023/11/29.
//

import Foundation
import AVFoundation
import FirebaseFirestore
import FirebaseAuth

class CameraMusicViewModel: ObservableObject {
    var audioPlayer: AVPlayer?
    var url = URL.init(string: "https://www.hello.com/sample.wav")
    
    func getMusic()async throws{
        let db = Firestore.firestore()
        if let currentUser = Auth.auth().currentUser {
            let uid = currentUser.uid
            let document = try await db.collection("users").document(uid).collection("personal").document("info").getDocument()
            let data = document.data()
            let musicUrl = data?["previewUrl"] as! String
            url =  URL.init(string: musicUrl )
        }
    }

    func startPlay() {
       
        let sampleUrl = URL.init(string: "https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview115/v4/8f/c1/32/8fc1329a-bf7d-03f2-3082-6536f60666ee/mzaf_1239907852510333018.plus.aac.p.m4a")
        audioPlayer = AVPlayer.init(playerItem: AVPlayerItem(url: url ?? sampleUrl! ))

        // 再生が終わった際のイベント定義
        NotificationCenter.default
            .addObserver(self, selector: #selector(playerDidFinishPlaying),
                         name: .AVPlayerItemDidPlayToEndTime,
                         object: audioPlayer?.currentItem)

        // 秒数の表示
        Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { timer in
            if let audioPlayer = self.audioPlayer,
               let currentItem = audioPlayer.currentItem,
               currentItem.status == .readyToPlay {
                let timeElapsed = CMTimeGetSeconds(audioPlayer.currentTime()) // 現在の再生時間の取得
                let timeDuration = currentItem.duration.seconds
                // 再生中のUI処理 秒数取得されるので / 60 で分数、% 60 で秒数
            }
        }

        audioPlayer?.play()
    }

    @objc func playerDidFinishPlaying(note: NSNotification) {
        // 再生が終わった際のイベント処理
    }

    func stop() {
        audioPlayer?.pause()
        // audioPlayer?.play() で再開
    }

    // 音声再生スピードの変更
    func changeSpeed(speed: Float) {
        audioPlayer?.rate = speed
    }

    // 音声再生位置の移動
    func changeLocation(seconds: Double) {
        guard let audioPlayer = self.audioPlayer else { return }

        let timeScale = CMTimeScale(NSEC_PER_SEC)
        let rhs = CMTime(seconds: seconds, preferredTimescale: timeScale)
        let time = CMTimeAdd(audioPlayer.currentTime(), rhs)
        audioPlayer.seek(to: time)
    }
    
}
