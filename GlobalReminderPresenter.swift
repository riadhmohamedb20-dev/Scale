import SwiftUI
import UIKit
import Combine

/// Hosts the global Reminder popup in its own always-on-top `UIWindow` (above alerts, so it
/// wins over any `.sheet`/`.fullScreenCover` the rest of the app happens to have presented) —
/// a plain SwiftUI `.overlay` on the root view would only ever render *underneath* those
/// modal presentations, not above them. The window is fully click-through when no reminder is
/// showing, so it never intercepts touches meant for the real UI.
@MainActor
final class GlobalReminderPresenter {
    static let shared = GlobalReminderPresenter()

    private var window: PassthroughWindow?
    private var cancellable: AnyCancellable?

    private init() {}

    func attach(to viewModel: TimeCircleViewModel) {
        guard window == nil else { return }
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return }

        let window = PassthroughWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear
        window.isHidden = false

        let hosting = UIHostingController(rootView: GlobalReminderOverlayRoot(viewModel: viewModel))
        hosting.view.backgroundColor = .clear
        window.rootViewController = hosting

        self.window = window

        cancellable = viewModel.$isShowingGlobalReminder
            .receive(on: DispatchQueue.main)
            .sink { [weak window] isShowing in
                window?.isReminderVisible = isShowing
            }
    }
}

private final class PassthroughWindow: UIWindow {
    var isReminderVisible = false

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isReminderVisible else { return nil }
        return super.hitTest(point, with: event)
    }
}

private struct GlobalReminderOverlayRoot: View {
    @ObservedObject var viewModel: TimeCircleViewModel
    // This lives in its own `UIWindow`, entirely separate from the main window's view
    // hierarchy, so it wouldn't otherwise inherit the `.preferredColorScheme` applied to the
    // app's root view — read the same stored preference directly so the popup's light/dark
    // appearance always matches the rest of the app instead of just following the system.
    @AppStorage("appAppearanceMode") private var appearanceModeRaw = AppAppearanceMode.system.rawValue

    private var appearanceMode: AppAppearanceMode {
        AppAppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    var body: some View {
        Group {
            if viewModel.isShowingGlobalReminder, let message = viewModel.currentReminderMessage {
                GlobalReminderView(viewModel: viewModel, message: message)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isShowingGlobalReminder)
        .preferredColorScheme(appearanceMode.colorScheme)
    }
}
