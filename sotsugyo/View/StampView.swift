//
//  StampView.swift
//  PIcTune
//
//  Created by saki on 2024/02/03.
//

import SwiftUI

struct StampView: View {
    @Binding var selectedImage: String
    @EnvironmentObject private var selectedImageManager: SelectedImageManager
    
    
    var body: some View {
        
        Spacer()
        ScrollView(.horizontal) {  // ⬅︎
            
            HStack { // ⬅︎
                ForEach(1..<17) { index in
                    Image("\(index)")
                        .resizable()
                        .frame(width: 70, height: 120)
                        .padding(3)
                        .onTapGesture {
                            selectedImageManager.selectedImage = "\(index)"
                            
                        }
                }
            } // HStack
            .frame(maxHeight: 120)
        } // ScrollView
        .background(Color.white)
    }
}

#Preview {
    StampView(selectedImage: .constant(""))
}
