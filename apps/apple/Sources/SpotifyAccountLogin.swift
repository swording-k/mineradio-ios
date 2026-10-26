#if os(iOS)
import AuthenticationServices
import UIKit

@MainActor final class SpotifyAccountLogin: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?
    func open(_ url: URL) async throws -> URL {
        guard session == nil else { throw SpotifyNativeAPI.Failure.busy }
        return try await withCheckedThrowingContinuation { continuation in
            let next = ASWebAuthenticationSession(url: url, callbackURLScheme: "com.swordingk.mineradio.apple") { [weak self] callback, error in
                Task { @MainActor in
                    self?.session = nil
                    if let callback { continuation.resume(returning: callback) }
                    else { continuation.resume(throwing: error ?? CancellationError()) }
                }
            }
            next.presentationContextProvider = self
            // Use the system browser's existing Spotify login when available.
            // Account passwords/cookies stay in AuthenticationServices.
            next.prefersEphemeralWebBrowserSession = false
            session = next
            if !next.start() { session = nil; continuation.resume(throwing: URLError(.cannotLoadFromNetwork)) }
        }
    }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes.compactMap {$0 as? UIWindowScene}.filter {$0.activationState == .foregroundActive}.flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}
#endif
