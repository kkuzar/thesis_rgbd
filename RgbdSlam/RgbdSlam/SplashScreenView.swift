//
//  SplashScreenView.swift
//  RgbdSlam
//
//  Created by Kyzyrbek Kuzar on 13.4.2024.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var isLoaded = false
    @State private var size = 0.95
    @State private var opacity = 0.5
    var body: some View {
        
        if isLoaded {
            ContentView()
        } else {
            VStack{
                VStack{
                    Image("hamk_logo")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                    Text("RGBD 3D Scanner")
                        .font(Font.system(size: 30))
                        .foregroundColor(.black.opacity(0.8))
                        .padding()
                    Text("A Kuzar Thesis Project")
                        .font(Font.system(size: 16))
                        .foregroundColor(.black.opacity(0.4))
                        .padding()
                }
                .scaleEffect(size)
                .opacity(opacity)
                .onAppear{
                    withAnimation(.easeIn(duration: 1.2)){
                        self.size = 0.75
                        self.opacity = 1.0
                    }
                }
                
            }
            
            .onAppear{
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5){
                    withAnimation(.easeOut(duration: 1.2)){
                        self.opacity = 0.1
                    } completion: {
                        self.isLoaded = true
                    }
                }
            }
            .frame(
                minWidth: 0,
                maxWidth: .infinity,
                minHeight: 0,
                maxHeight: .infinity,
                alignment: .center
            )
            .background(Gradient(colors: [.white, .white, .white, .white,.teal, .blue]).opacity(0.85))
        }
        
        
    }
}

#Preview {
    SplashScreenView()
}
