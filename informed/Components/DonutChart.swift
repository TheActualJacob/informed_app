//
//  DonutChart.swift
//  informed
//
//  Animated circular progress chart for credibility scores
//

import SwiftUI

struct DonutChart: View {
    var score: Double
    var color: Color
    
    @State private var animatedScore: CGFloat = 0.0
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 15)
                .opacity(0.1)
                .foregroundColor(color)
            
            Circle()
                .trim(from: 0.0, to: animatedScore)
                .stroke(
                    style: StrokeStyle(
                        lineWidth: 15,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .foregroundColor(color)
                .rotationEffect(Angle(degrees: 270.0))
            
            VStack {
                Text("\(Int(score * 100))%")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                Text("Truth Score")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }
        }
        .frame(width: 120, height: 120)
        .onAppear {
            withAnimation(.spring(response: 1.5, dampingFraction: 0.8)) {
                animatedScore = CGFloat(score)
            }
        }
    }
}
