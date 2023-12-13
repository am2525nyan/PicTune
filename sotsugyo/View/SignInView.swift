//
//  SignInView.swift
//  sotsugyo
//
//  Created by saki on 2023/12/13.
//

import SwiftUI

struct SignInView: View {
    @ObservedObject var viewModel: MainContentModel

    var body: some View {
        HStack {
            Spacer()
            Button {
                viewModel.isShowSheet.toggle()
                viewModel.saveUserData()
            } label: {
                Text("Sign-In")
            }
            .padding()
            .sheet(isPresented: $viewModel.isShowSheet) {
                LoginView()
            }
        }
    }
}
