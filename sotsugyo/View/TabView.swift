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
    
    
    var body: some View {
        TabView(selection: $selection) {
            
            
            MainContentView()
                .tabItem {
                    VStack {
                        Label("Page1", systemImage: "1.circle")
                    }
                    .tag(1)
                    
                }
            
            ProfileView( documentId: $documentId)
                .tabItem {
                    VStack {
                        Label("Page2", systemImage: "2.circle")
                    }
                    .tag(2)
                    
                }
        }
        
    }
}
