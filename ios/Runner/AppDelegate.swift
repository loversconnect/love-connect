import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var privacyView: UIView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appWillResignActive),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  @objc private func appWillResignActive() {
    guard let window = self.window ?? UIApplication.shared.windows.first else { return }
    if privacyView != nil { return }

    let overlay = UIView(frame: window.bounds)
    overlay.backgroundColor = UIColor.black
    overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]

    let lock = UIImageView(image: UIImage(systemName: "lock.fill"))
    lock.tintColor = UIColor.white
    lock.contentMode = .scaleAspectFit
    lock.frame = CGRect(x: 0, y: 0, width: 42, height: 42)
    lock.center = CGPoint(x: overlay.bounds.midX, y: overlay.bounds.midY)
    lock.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
    overlay.addSubview(lock)

    window.addSubview(overlay)
    privacyView = overlay
  }

  @objc private func appDidBecomeActive() {
    privacyView?.removeFromSuperview()
    privacyView = nil
  }
}
