//
//  SignInView.swift
//  sotsugyo
//
//  Created by saki on 2023/12/13.
//

import SwiftUI

struct SignInView: View {
    @StateObject var viewModel: MainContentModel
    @StateObject var Color: ColorModel
    
    
    var body: some View {
        
        Image("icon")
            .resizable()
            .frame(width: 300,height: 300)
            .padding(.top, 30)
        Spacer()
        VStack(alignment: .leading) {
            Text("Welcome!")
                .font(.custom("Roboto", size: 50))
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 30)
        }
        VStack(alignment: .center){
            Button {
                viewModel.isShowSheet.toggle()
                
            } label: {
                Text("Get Started")
                    .font(.custom("Roboto", size: 15))
                    .padding(.all, 4)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .frame(width: 330,height: 50)
                    .foregroundColor(.white)
                
                    .background(Color.backGroundColor())
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke()
                            .foregroundStyle(
                                .linearGradient(
                                    colors: [.white.opacity(0.5), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                    .shadow(color: .black.opacity(0.3), radius: 5, y: 3)
                    .padding(.bottom, 30)
            }
            
            .padding()
            .sheet(isPresented: $viewModel.isShowSheet) {
                LoginView(viewModel: viewModel)
            }
        }
    }
}
