import UIKit

/// Keeps the edge swipe-back gesture working on screens that hide the system back button
/// (see `circleBackButton()`). UIKit disables the gesture when the back button is hidden,
/// so the navigation controller becomes the gesture's delegate and allows it whenever
/// there is a screen to go back to.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === interactivePopGestureRecognizer else {
            return true
        }

        return viewControllers.count > 1 && transitionCoordinator == nil
    }
}
