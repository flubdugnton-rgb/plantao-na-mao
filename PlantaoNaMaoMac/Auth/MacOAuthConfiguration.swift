import Foundation

/// Value-only OAuth settings shared by the Mac implementation and its protocol checks.
enum MacOAuthConfiguration {
    static let authorizationEndpoint = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    static let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!
    static let userInfoEndpoint = URL(string: "https://openidconnect.googleapis.com/v1/userinfo")!
    static let driveAppDataScope = "https://www.googleapis.com/auth/drive.appdata"
    static let requestedScopes = [
        "openid", "profile", "email",
        driveAppDataScope
    ]

    static var callbackScheme: String {
        CrossPlatformOAuth.nativeClientID.split(separator: ".").reversed().joined(separator: ".")
    }

    // Match Google Sign-In's native redirect, including the single slash.
    // Native iOS OAuth clients registered in Google Cloud use this fixed callback path.
    static var redirectURL: URL { URL(string: "\(callbackScheme):/oauthredirect")! }

    static func isCallback(_ url: URL) -> Bool {
        url.scheme?.caseInsensitiveCompare(callbackScheme) == .orderedSame &&
            url.host == nil && url.path == redirectURL.path
    }

    static func hasScopes(_ required: [String], granted: String?) -> Bool {
        let granted = Set((granted ?? "").split(whereSeparator: { $0.isWhitespace }).map(String.init))
        return Set(required).isSubset(of: granted)
    }
}
