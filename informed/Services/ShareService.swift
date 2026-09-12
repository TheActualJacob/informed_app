//
//  ShareService.swift
//  informed
//
//  Single entry point for sharing a fact check. Builds the informed-app.com/share
//  link, presents the system share sheet from the top-most view controller (so it
//  also works from inside a sheet), and — only when the user actually completes a
//  share — bumps the local "Shared" stat and records a `share` interaction on the
//  backend so the reel's share_count and analytics stay in step with the app.
//

import UIKit

@MainActor
enum ShareService {

    /// Presents the share sheet for a fact check.
    /// - Parameters:
    ///   - reelID: backend uniqueID; when present the shared item is the web preview link.
    ///   - fallbackLink: original social URL used when there is no backend id yet.
    ///   - title: last-resort text if neither link is available.
    static func shareFactCheck(reelID: String?, fallbackLink: String?, title: String) {
        HapticManager.lightImpact()

        let shareURL: URL? = {
            if let rid = reelID, !rid.isEmpty {
                return URL(string: Config.Endpoints.shareBase + rid)
            }
            return fallbackLink.flatMap { URL(string: $0) }
        }()
        let items: [Any] = shareURL.map { [$0] } ?? [title]

        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        activityVC.completionWithItemsHandler = { _, completed, _, _ in
            // Cancelled sheets must not count as a share.
            guard completed else { return }
            Task { @MainActor in recordShare(reelID: reelID) }
        }

        guard let presenter = topViewController() else { return }
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX,
                                        y: presenter.view.bounds.midY,
                                        width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        presenter.present(activityVC, animated: true)
    }

    /// Bumps the local counter and tells the backend. Called only after a completed share.
    private static func recordShare(reelID: String?) {
        PersistenceService.shared.incrementSharedCount()

        guard let reelID, !reelID.isEmpty,
              let userId = UserManager.shared.currentUserId,
              let sessionId = UserManager.shared.currentSessionId else { return }
        Task {
            try? await NetworkService.shared.trackInteraction(
                userId: userId,
                sessionId: sessionId,
                factCheckId: reelID,
                interactionType: "share"
            )
        }
    }

    /// The view controller currently on top of the key window's presentation stack.
    /// Presenting from the root controller fails silently whenever a sheet is already up.
    static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap { $0.windows }.first { $0.isKeyWindow }
            ?? scenes.first?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
