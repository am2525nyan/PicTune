//
//  ProfileView.swift
//  sotsugyo
//
//  Created by saki on 2023/11/26.
//

import SwiftUI

struct ProfileView: View {
    @State var isPresentingSearchMusic =  false
    @Binding var documentId: String

    var body: some View {
        VStack {
            Text("Hello, World!")
            
            Button("音楽設定") {
               
                isPresentingSearchMusic = true
               
            }
          
        }
    }
}
