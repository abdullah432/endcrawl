import GoogleMobileAds
import UIKit
import google_mobile_ads

/// The native ad card the Dart side asks for as factory `lastreelCard`: the
/// design's ad row — icon tile, headline, "Ad" badge and body, a pill button —
/// on a surface card with 16 pt corners. Colours come from Dart
/// (`customOptions`), so the card follows the app's palette.
///
/// The rounded card sits inside the unclipped NativeAdView, and the AdChoices
/// icon is placed by us, inset from the top-right corner, so rounding never
/// hides a required element.
final class LastReelNativeAdFactory: NSObject, FLTNativeAdFactory {
  static let id = "lastreelCard"

  func createNativeAd(_ nativeAd: NativeAd, customOptions: [AnyHashable: Any]? = nil) -> NativeAdView? {
    func colour(_ key: String, _ fallback: String) -> UIColor {
      UIColor(hex: customOptions?[key] as? String ?? fallback) ?? UIColor(hex: fallback)!
    }
    let surface = colour("surface", "#FFFFFF")
    let line = colour("line", "#E6DFD4")
    let tint = colour("tint", "#EFE8DD")
    let ink = colour("ink", "#1A1612")
    let muted = colour("muted", "#8A8178")
    let onInk = colour("onInk", "#FFFFFF")

    let adView = NativeAdView()
    adView.backgroundColor = .clear

    let card = UIView()
    card.backgroundColor = surface
    card.layer.cornerRadius = 16
    card.layer.cornerCurve = .continuous
    card.layer.borderWidth = 1 / UIScreen.main.scale
    card.layer.borderColor = line.cgColor
    card.clipsToBounds = true
    card.translatesAutoresizingMaskIntoConstraints = false
    adView.addSubview(card)

    let icon = UIImageView()
    icon.contentMode = .scaleAspectFill
    icon.backgroundColor = tint
    icon.layer.cornerRadius = 10
    icon.clipsToBounds = true
    icon.image = nativeAd.icon?.image
    icon.isHidden = nativeAd.icon == nil
    NSLayoutConstraint.activate([
      icon.widthAnchor.constraint(equalToConstant: 44),
      icon.heightAnchor.constraint(equalToConstant: 44),
    ])

    let headline = Self.label(size: 14, weight: .semibold, colour: ink)
    headline.text = nativeAd.headline

    let badge = Self.label(size: 10, weight: .bold, colour: muted)
    badge.text = " Ad "
    badge.layer.borderColor = muted.cgColor
    badge.layer.borderWidth = 1
    badge.layer.cornerRadius = 3
    badge.setContentHuggingPriority(.required, for: .horizontal)
    badge.setContentCompressionResistancePriority(.required, for: .horizontal)

    let body = Self.label(size: 12, weight: .regular, colour: muted)
    body.text = nativeAd.body
    body.isHidden = (nativeAd.body ?? "").isEmpty

    let meta = UIStackView(arrangedSubviews: [badge, body])
    meta.axis = .horizontal
    meta.spacing = 6
    meta.alignment = .center

    let words = UIStackView(arrangedSubviews: [headline, meta])
    words.axis = .vertical
    words.spacing = 3

    let cta = UIButton(type: .custom)
    cta.setTitle(nativeAd.callToAction, for: .normal)
    cta.setTitleColor(onInk, for: .normal)
    cta.titleLabel?.font = .systemFont(ofSize: 12.5, weight: .semibold)
    cta.backgroundColor = ink
    cta.contentEdgeInsets = UIEdgeInsets(top: 9, left: 14, bottom: 9, right: 14)
    cta.layer.cornerRadius = 17
    cta.isHidden = (nativeAd.callToAction ?? "").isEmpty
    // The SDK handles the tap on the whole ad; the button must not take it.
    cta.isUserInteractionEnabled = false
    cta.setContentHuggingPriority(.required, for: .horizontal)
    cta.setContentCompressionResistancePriority(.required, for: .horizontal)

    let row = UIStackView(arrangedSubviews: [icon, words, cta])
    row.axis = .horizontal
    row.spacing = 12
    row.alignment = .center
    row.translatesAutoresizingMaskIntoConstraints = false
    card.addSubview(row)

    let choices = AdChoicesView()
    choices.translatesAutoresizingMaskIntoConstraints = false
    adView.addSubview(choices)

    NSLayoutConstraint.activate([
      card.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
      card.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
      card.topAnchor.constraint(equalTo: adView.topAnchor),
      card.bottomAnchor.constraint(equalTo: adView.bottomAnchor),
      row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
      row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
      row.centerYAnchor.constraint(equalTo: card.centerYAnchor),
      row.topAnchor.constraint(greaterThanOrEqualTo: card.topAnchor, constant: 10),
      choices.topAnchor.constraint(equalTo: adView.topAnchor, constant: 6),
      choices.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -6),
      choices.widthAnchor.constraint(equalToConstant: 15),
      choices.heightAnchor.constraint(equalToConstant: 15),
    ])

    adView.headlineView = headline
    adView.bodyView = body
    adView.iconView = icon
    adView.callToActionView = cta
    adView.adChoicesView = choices
    adView.nativeAd = nativeAd
    return adView
  }

  private static func label(size: CGFloat, weight: UIFont.Weight, colour: UIColor) -> UILabel {
    let label = UILabel()
    label.font = .systemFont(ofSize: size, weight: weight)
    label.textColor = colour
    label.numberOfLines = 1
    label.lineBreakMode = .byTruncatingTail
    return label
  }
}

private extension UIColor {
  /// "#RRGGBB".
  convenience init?(hex: String) {
    let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
    guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
    self.init(
      red: CGFloat((value >> 16) & 0xFF) / 255,
      green: CGFloat((value >> 8) & 0xFF) / 255,
      blue: CGFloat(value & 0xFF) / 255,
      alpha: 1
    )
  }
}
