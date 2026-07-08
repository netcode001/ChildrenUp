import SwiftUI
import CoreTransferable
import UniformTypeIdentifiers
import UIKit

// MARK: - ActivityViewController
struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Extensions/Structs here are no longer needed as we use direct URL/Image sharing

