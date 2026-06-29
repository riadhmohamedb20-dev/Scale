import SwiftUI

struct LaunchAnimationView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var visibleSegments: Set<Int> = []

    private let logoSize: CGFloat = 380
    private let startDelay = 0.15
    private let segmentInterval = 0.16
    private let segmentFadeDuration = 0.22

    private let segments = [
        "LaunchLogoGreen",
        "LaunchLogoOrange",
        "LaunchLogoRed",
        "LaunchLogoPurple",
        "LaunchLogoBlue"
    ]

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()

            ZStack {
                ForEach(Array(segments.enumerated()), id: \.offset) { index, imageName in
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: logoSize, height: logoSize)
                        .opacity(visibleSegments.contains(index) ? 1 : 0)
                }
            }
        }
        .onAppear {
            runAnimation()
        }
    }

    private func runAnimation() {
        for index in segments.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + startDelay + Double(index) * segmentInterval) {
                withAnimation(.easeOut(duration: segmentFadeDuration)) {
                    _ = visibleSegments.insert(index)
                }
            }
        }
    }
}
