//
//  ThumbnailAlertView.swift
//  RgbdSlam
//
//  Created by Kyzyrbek Kuzar on 26.4.2024.
//

import SwiftUI

struct ThumbnailAlertView: View {
    @Binding var isPresented: Bool
    var image: UIImage

    var body: some View {
        
        VStack {
            ZStack{
                // Use the UIImageViewWrapper to display the image
                UIImageViewWrapper(uiImage: image, contentMode: .scaleAspectFit)
                    .frame(width: 400, height: 600, alignment: .center)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                
                
            }
            .padding()
            .background(Color.white)
            .cornerRadius(15)
            .shadow(radius: 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.3).edgesIgnoringSafeArea(.all))
            
            Button("Dismiss") {
                isPresented = false
            }
            .foregroundColor(.white)
            .padding()
            .background(Color.blue)
            .clipShape(Capsule())
        }
        
        
    }
}

