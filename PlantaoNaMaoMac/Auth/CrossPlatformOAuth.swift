import Foundation

// Public native client already used by Kepleræ, in the same Google Cloud project as iOS.
// Session credentials and Plantão sync files remain specific to this application.
enum CrossPlatformOAuth {
    static let nativeClientID = GoogleCloudConfiguration.macOSClientID
}
