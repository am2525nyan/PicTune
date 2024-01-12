//
//  Lottie.swift
//  sotsugyo
//
//  Created by saki on 2024/01/12.
//
import SwiftUI
import Lottie

class LottieViewModel: ObservableObject {
    @Published var playAnimation = false

    func startAnimation() {
        playAnimation = true
    }
}

struct LottieView: UIViewRepresentable {
    var filename: String
    var loopMode: LottieLoopMode
    var animationSpeed: Double
    @Binding var isPlaying: Bool
  
    func makeUIView(context: Context) -> some UIView {
        let animationView = LottieAnimationView(name: filename)
        animationView.loopMode = loopMode
        animationView.animationSpeed = CGFloat(animationSpeed)
        return animationView
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {
        guard let animationView = uiView as? LottieAnimationView else { return }
        isPlaying ? animationView.play() : animationView.stop()
    }
}


struct LottieStartView: View {
    @State private var playAnimation = false
    @StateObject var viewModel: MainContentModel

    var body: some View {
            VStack {
                LottieView(filename: "fireworks", loopMode: .playOnce, animationSpeed: 0.5, isPlaying: $viewModel.isAnimating)
                    .frame(width: 300, height: 300)
                    
            }
        }
}

