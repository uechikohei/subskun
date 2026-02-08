import UIKit

extension UIApplication {
    func topMostViewController(base: UIViewController? = nil) -> UIViewController? {
        let root = base ?? connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow })?
            .rootViewController

        if let navigationController = root as? UINavigationController {
            return topMostViewController(base: navigationController.visibleViewController)
        }

        if let tabBarController = root as? UITabBarController,
           let selectedViewController = tabBarController.selectedViewController {
            return topMostViewController(base: selectedViewController)
        }

        if let presented = root?.presentedViewController {
            return topMostViewController(base: presented)
        }

        return root
    }
}
