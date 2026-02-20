//
//  SettingsView.swift
//  Swift Cleaner
//
//  Created by APPLE on 14/2/2026.
//


import SwiftUI

struct SettingsView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.contentTop, AppTheme.contentBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 10) {
                Text("Settings")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Text("Coming soon")
                    .foregroundColor(.white.opacity(0.75))
            }
        }
    }
}
