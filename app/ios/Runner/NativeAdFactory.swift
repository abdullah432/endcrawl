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
///
/// On an iPad Dart asks for one of the tablet shapes instead
/// (`customOptions["layout"]`), as on Android: see `createTabletAd`.
final class LastReelNativeAdFactory: NSObject, FLTNativeAdFactory {
  static let id = "lastreelCard"

  /// The tablet shapes Dart can ask for (`customOptions["layout"]`), drawn
  /// as on Android: the card and "Remove ads" are Dart's, laid over these.
  private static let tabletLayouts: Set<String> = ["strip", "stripPortrait", "compact"]

  func createNativeAd(_ nativeAd: NativeAd, customOptions: [AnyHashable: Any]? = nil) -> NativeAdView? {
    func colour(_ key: String, _ fallback: String) -> UIColor {
      UIColor(hex: customOptions?[key] as? String ?? fallback) ?? UIColor(hex: fallback)!
    }
    if let layout = customOptions?["layout"] as? String, Self.tabletLayouts.contains(layout) {
      return createTabletAd(nativeAd, layout: layout, colour: colour)
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

    // Main image/video assets must be rendered by the SDK's MediaView.
    // The icon below remains the advertiser's separate app icon.
    let media = MediaView()
    media.translatesAutoresizingMaskIntoConstraints = false
    media.contentMode = .scaleAspectFit
    media.mediaContent = nativeAd.mediaContent
    card.addSubview(media)
    adView.mediaView = media

    let icon = UIImageView()
    icon.contentMode = .scaleAspectFill
    icon.backgroundColor = tint
    icon.layer.cornerRadius = 10
    icon.clipsToBounds = true
    icon.image = nativeAd.icon?.image
    icon.isHidden = nativeAd.icon == nil
    NSLayoutConstraint.activate([
      icon.widthAnchor.constraint(equalToConstant: 24),
      icon.heightAnchor.constraint(equalToConstant: 24),
    ])

    let headline = Self.label(size: 14, weight: .semibold, colour: ink)
    headline.text = nativeAd.headline
    headline.numberOfLines = 2

    let badge = Self.label(size: 10, weight: .bold, colour: muted)
    badge.text = " Ad "
    badge.layer.borderColor = muted.cgColor
    badge.layer.borderWidth = 1
    badge.layer.cornerRadius = 3
    badge.heightAnchor.constraint(greaterThanOrEqualToConstant: 15).isActive = true
    badge.widthAnchor.constraint(greaterThanOrEqualToConstant: 15).isActive = true
    badge.setContentHuggingPriority(.required, for: .horizontal)
    badge.setContentCompressionResistancePriority(.required, for: .horizontal)

    let body = Self.label(size: 11, weight: .regular, colour: muted)
    body.text = nativeAd.body
    body.numberOfLines = 3
    body.isHidden = (nativeAd.body ?? "").isEmpty

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

    let title = UIStackView(arrangedSubviews: [icon, headline])
    title.axis = .horizontal
    title.spacing = 6
    title.alignment = .center
    let actions = UIStackView(arrangedSubviews: [badge, UIView(), cta])
    actions.axis = .horizontal
    actions.spacing = 6
    actions.alignment = .center
    let words = UIStackView(arrangedSubviews: [title, body, actions])
    words.axis = .vertical
    words.spacing = 6
    let row = UIStackView(arrangedSubviews: [media, words])
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
      media.widthAnchor.constraint(equalToConstant: 120),
      media.heightAnchor.constraint(equalToConstant: 120),
      row.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
      row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
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

  /// The tablet shapes (T3.1, T5.2, T8.1, P1.2, P3.1), on a clear ground so
  /// the Dart card shows through, leaving room for the "Remove ads" link
  /// Dart lays over them.
  ///
  /// - strip: 16:9 still · "AD" + advertiser / headline / body · action,
  ///   with the link's space under the action.
  /// - stripPortrait: the same, with the link's space under the headline in
  ///   place of the body.
  /// - compact: "AD" on top (the link opposite), then 128 × 128 media and
  ///   the headline.
  private func createTabletAd(
    _ nativeAd: NativeAd,
    layout: String,
    colour: (String, String) -> UIColor
  ) -> NativeAdView {
    let surface = colour("surface", "#FFFFFF")
    let tint = colour("tint", "#EFE8DD")
    let ink = colour("ink", "#1A1612")
    let ink2 = colour("ink2", "#FF3D352C")
    let muted = colour("muted", "#6B6053")
    let line2 = colour("line2", "#331A1612")
    let compact = layout == "compact"
    let portrait = layout == "stripPortrait"

    let adView = NativeAdView()
    adView.backgroundColor = .clear

    let stillSize: CGSize = compact
      ? CGSize(width: 128, height: 128)
      : portrait ? CGSize(width: 168, height: 128) : CGSize(width: 184, height: 128)
    func framed(_ view: UIView, radius: CGFloat) {
      view.backgroundColor = tint
      view.layer.cornerRadius = radius
      view.layer.cornerCurve = .continuous
      view.layer.borderWidth = 1 / UIScreen.main.scale
      view.layer.borderColor = line2.cgColor
      view.clipsToBounds = true
      view.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        view.widthAnchor.constraint(equalToConstant: stillSize.width),
        view.heightAnchor.constraint(equalToConstant: stillSize.height),
      ])
    }

    let badge = PaddedLabel()
    badge.text = "AD"
    badge.font = .monospacedSystemFont(ofSize: 9.5, weight: .medium)
    badge.textColor = ink2
    badge.backgroundColor = tint
    badge.layer.cornerRadius = 6
    badge.layer.borderWidth = 1 / UIScreen.main.scale
    badge.layer.borderColor = line2.cgColor
    badge.clipsToBounds = true
    badge.setContentHuggingPriority(.required, for: .horizontal)
    badge.setContentCompressionResistancePriority(.required, for: .horizontal)

    let headline = Self.label(size: compact ? 13 : portrait ? 15.5 : 16, weight: .semibold, colour: ink)
    headline.numberOfLines = compact ? 2 : 1
    headline.text = nativeAd.headline
    adView.headlineView = headline

    let appIcon = UIImageView()
    appIcon.contentMode = .scaleAspectFit
    appIcon.image = nativeAd.icon?.image
    appIcon.isHidden = nativeAd.icon == nil
    appIcon.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      appIcon.widthAnchor.constraint(equalToConstant: 24),
      appIcon.heightAnchor.constraint(equalToConstant: 24),
    ])
    adView.iconView = appIcon

    let root: UIView
    if compact {
      let media = MediaView()
      media.contentMode = .scaleAspectFit
      media.mediaContent = nativeAd.mediaContent
      framed(media, radius: 10)
      adView.mediaView = media

      let top = UIStackView(arrangedSubviews: [badge, UIView()])
      top.axis = .horizontal
      let title = UIStackView(arrangedSubviews: [appIcon, headline])
      title.axis = .horizontal
      title.spacing = 6
      title.alignment = .center
      let cta = UIButton(type: .custom)
      cta.setTitle(nativeAd.callToAction, for: .normal)
      cta.setTitleColor(ink, for: .normal)
      cta.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
      cta.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
      cta.backgroundColor = surface
      cta.layer.borderColor = line2.cgColor
      cta.layer.borderWidth = 1 / UIScreen.main.scale
      cta.layer.cornerRadius = 16
      cta.isHidden = (nativeAd.callToAction ?? "").isEmpty
      cta.isUserInteractionEnabled = false
      adView.callToActionView = cta
      let details = UIStackView(arrangedSubviews: [title, cta])
      details.axis = .vertical
      details.spacing = 8
      details.alignment = .leading
      let body = UIStackView(arrangedSubviews: [media, details])
      body.axis = .horizontal
      body.spacing = 10
      body.alignment = .center
      let column = UIStackView(arrangedSubviews: [top, body])
      column.axis = .vertical
      column.spacing = 8
      root = column
    } else {
      let media = MediaView()
      media.contentMode = .scaleAspectFill
      media.mediaContent = nativeAd.mediaContent
      framed(media, radius: 14)
      adView.mediaView = media

      let advertiser = Self.label(size: 12, weight: .regular, colour: muted)
      advertiser.text = nativeAd.advertiser
      advertiser.isHidden = (nativeAd.advertiser ?? "").isEmpty
      adView.advertiserView = advertiser

      let tag = UIStackView(arrangedSubviews: [badge, appIcon, advertiser])
      tag.axis = .horizontal
      tag.spacing = 8
      tag.alignment = .center
      var lines: [UIView] = [tag, headline]
      if portrait {
        // Where Dart puts "Remove ads".
        let room = UIView()
        room.heightAnchor.constraint(equalToConstant: 21).isActive = true
        lines.append(room)
      } else {
        let body = Self.label(size: 12.5, weight: .regular, colour: muted)
        body.text = nativeAd.body
        body.isHidden = (nativeAd.body ?? "").isEmpty
        adView.bodyView = body
        lines.append(body)
      }
      let words = UIStackView(arrangedSubviews: lines)
      words.axis = .vertical
      words.spacing = 6
      words.alignment = .leading
      words.setContentHuggingPriority(.defaultLow, for: .horizontal)

      let cta = UIButton(type: .custom)
      cta.setTitle(nativeAd.callToAction, for: .normal)
      cta.setTitleColor(ink, for: .normal)
      cta.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
      cta.backgroundColor = surface
      cta.contentEdgeInsets = UIEdgeInsets(top: 0, left: portrait ? 16 : 18, bottom: 0, right: portrait ? 16 : 18)
      cta.layer.cornerRadius = 20
      cta.layer.borderWidth = 1 / UIScreen.main.scale
      cta.layer.borderColor = line2.cgColor
      cta.alpha = (nativeAd.callToAction ?? "").isEmpty ? 0 : 1
      // The SDK handles the tap on the whole ad; the button must not take it.
      cta.isUserInteractionEnabled = false
      cta.heightAnchor.constraint(equalToConstant: 40).isActive = true
      cta.setContentHuggingPriority(.required, for: .horizontal)
      cta.setContentCompressionResistancePriority(.required, for: .horizontal)
      adView.callToActionView = cta

      var actionViews: [UIView] = [cta]
      if !portrait {
        // Where Dart puts "Remove ads", under the action.
        let room = UIView()
        room.heightAnchor.constraint(equalToConstant: 23).isActive = true
        actionViews.append(room)
      }
      let actions = UIStackView(arrangedSubviews: actionViews)
      actions.axis = .vertical
      actions.alignment = .trailing

      let row = UIStackView(arrangedSubviews: [media, words, actions])
      row.axis = .horizontal
      row.spacing = portrait ? 16 : 18
      row.alignment = .center
      root = row
    }

    root.translatesAutoresizingMaskIntoConstraints = false
    adView.addSubview(root)

    // AdChoices: top right on a strip, bottom right on the compact card,
    // whose top right is "Remove ads".
    let choices = AdChoicesView()
    choices.translatesAutoresizingMaskIntoConstraints = false
    adView.addSubview(choices)

    NSLayoutConstraint.activate([
      root.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
      root.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
      compact
        ? root.topAnchor.constraint(equalTo: adView.topAnchor)
        : root.centerYAnchor.constraint(equalTo: adView.centerYAnchor),
      root.topAnchor.constraint(greaterThanOrEqualTo: adView.topAnchor),
      choices.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
      compact
        ? choices.bottomAnchor.constraint(equalTo: adView.bottomAnchor)
        : choices.topAnchor.constraint(equalTo: adView.topAnchor),
      choices.widthAnchor.constraint(equalToConstant: 15),
      choices.heightAnchor.constraint(equalToConstant: 15),
    ])
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
    label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    return label
  }
}

/// The "AD" tag: a label with room inside its rounded border.
private final class PaddedLabel: UILabel {
  private let inset = UIEdgeInsets(top: 2, left: 7, bottom: 2, right: 7)

  override func drawText(in rect: CGRect) {
    super.drawText(in: rect.inset(by: inset))
  }

  override var intrinsicContentSize: CGSize {
    let size = super.intrinsicContentSize
    return CGSize(width: size.width + inset.left + inset.right, height: size.height + inset.top + inset.bottom)
  }
}

private extension UIColor {
  /// "#RRGGBB", or "#AARRGGBB" for the tablet shapes' translucent lines.
  convenience init?(hex: String) {
    let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
    guard digits.count == 6 || digits.count == 8, let value = UInt32(digits, radix: 16) else { return nil }
    self.init(
      red: CGFloat((value >> 16) & 0xFF) / 255,
      green: CGFloat((value >> 8) & 0xFF) / 255,
      blue: CGFloat(value & 0xFF) / 255,
      alpha: digits.count == 8 ? CGFloat((value >> 24) & 0xFF) / 255 : 1
    )
  }
}
