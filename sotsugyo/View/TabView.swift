//
//  TabView.swift
//  sotsugyo
//
//  Created by saki on 2023/11/26.
//

import SwiftUI

struct TabContentView: View {
    @State var selection = 1
    @Binding var documentId: String
  
    @Binding  var selectedImage: UIImage?

    
    var body: some View {
        TabView(selection: $selection) {
            
            
         MainContentView()
                .tabItem {
                    VStack {
                        Label("Page1", systemImage: "1.circle")
                    }
                    .tag(1)
                    
                }
        }
        
    }
}

