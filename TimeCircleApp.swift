//
//  TimeCircleApp.swift
//  TimeCircle
//
//  Created by Riadh Belkahla on 28/6/26.
//

import SwiftUI

@main
struct TimeCircleApp: App {
    @AppStorage("appAppearanceMode") private var appearanceModeRaw = AppAppearanceMode.system.rawValue

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(appearanceMode.colorScheme)
        }
    }

    private var appearanceMode: AppAppearanceMode {
        AppAppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }
}

private struct RootView: View {
    @StateObject private var viewModel = TimeCircleViewModel()
    @State private var isShowingLaunchAnimation = true

    var body: some View {
        ZStack {
            ContentView(viewModel: viewModel)
                .opacity(isShowingLaunchAnimation ? 0 : 1)

            if isShowingLaunchAnimation {
                LaunchAnimationView()
                    .transition(.opacity)
            }
        }
        .onAppear {
            GlobalReminderPresenter.shared.attach(to: viewModel)

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.55) {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isShowingLaunchAnimation = false
                }
            }
        }
    }
}
