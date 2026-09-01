//
//  ViewfinderCorners.swift
//  OutfitMatch
//
//  Camera-viewfinder corner brackets, drawn once and reused wherever the
//  app wants to signal "this is what the AI is looking at."

import SwiftUI

struct ViewfinderCorners: View {
    var color: Color = .scanMint
    var length: CGFloat = 22
    var thickness: CGFloat = 2
    var inset: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Path { path in
                path.move(to: CGPoint(x: inset, y: inset + length))
                path.addLine(to: CGPoint(x: inset, y: inset))
                path.addLine(to: CGPoint(x: inset + length, y: inset))

                path.move(to: CGPoint(x: w - inset - length, y: inset))
                path.addLine(to: CGPoint(x: w - inset, y: inset))
                path.addLine(to: CGPoint(x: w - inset, y: inset + length))

                path.move(to: CGPoint(x: inset, y: h - inset - length))
                path.addLine(to: CGPoint(x: inset, y: h - inset))
                path.addLine(to: CGPoint(x: inset + length, y: h - inset))

                path.move(to: CGPoint(x: w - inset - length, y: h - inset))
                path.addLine(to: CGPoint(x: w - inset, y: h - inset))
                path.addLine(to: CGPoint(x: w - inset, y: h - inset - length))
            }
            .stroke(color, style: StrokeStyle(lineWidth: thickness, lineCap: .round, lineJoin: .round))
        }
        .allowsHitTesting(false)
    }
}
