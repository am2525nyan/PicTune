//
//  ProfileView.swift
//  sotsugyo
//
//  Created by saki on 2023/11/26.
//

import SwiftUI

struct ProfileView: View {
    @State private var isPresentingSearchMusic = false
    var body: some View {
        VStack{
          
            Text("Hello, World!")
            Button("音楽設定") {
                    isPresentingSearchMusic = true
                      }
            .fullScreenCover(isPresented: $isPresentingSearchMusic) {
                SearchMusicView(isPresentingSearchMusic: $isPresentingSearchMusic)
                          }
        }
    }
}

#Preview {
    ProfileView()
}
