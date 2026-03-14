//
//  GlassBackground.swift
//  informed
//

import SwiftUI

struct GlassBackground: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            Color.backgroundLight
                .ignoresSafeArea()
            
            // Animated blobs for the liquid glass effect
            Circle()
                .fill(LinearGradient(colors: [.brandTeal.opacity(0.4), .brandTeal.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: animate ? 100 : -50, y: animate ? -100 : 50)
            
            Circle()
                .fill(LinearGradient(colors: [.brandBlue.opacity(0.4), .brandBlue.opacity(0.1)], startPoint: .topTrailing, endPoint: .bottomLeading))
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(x: animate ? -100 : 150, y: animate ? 150 : -50)
            
            Circle()
                .fill(Color.purple.opacity(0.2))
                .frame(width: 250, height: 250)
                .blur(radius: 50)
                .offset(x: animate ? 50 : 200, y: animate ? 200 : 100)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
    }
}
