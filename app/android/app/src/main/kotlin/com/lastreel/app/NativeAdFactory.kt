package com.lastreel.app

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.google.android.gms.ads.nativead.AdChoicesView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.NativeAdFactory

/**
 * The native ad card the Dart side asks for as factory `lastreelCard`: the
 * design's ad row — icon tile, headline, "Ad" badge and body, a pill button —
 * on a surface card with 16 dp corners. Colours come from Dart
 * (`customOptions`), so the card follows the app's palette.
 *
 * The rounded card sits inside the unclipped NativeAdView, and the AdChoices
 * icon is placed by us, inset from the top-right corner, so rounding never
 * hides a required element.
 *
 * On a tablet Dart asks for one of two other shapes (`customOptions["layout"]`)
 * and draws their card, and "Remove ads", itself: `strip` / `stripPortrait`,
 * the library's foot (T8.1, P1.2), and `compact`, under the Settings list
 * (T7.1). See [createTabletAd].
 */
class LastReelNativeAdFactory(private val context: Context) : NativeAdFactory {
    override fun createNativeAd(nativeAd: NativeAd, customOptions: MutableMap<String, Any>?): NativeAdView {
        fun colour(key: String, fallback: String) =
            Color.parseColor((customOptions?.get(key) as? String) ?: fallback)
        val layout = customOptions?.get("layout") as? String
        if (layout != null && layout in TABLET_LAYOUTS) return createTabletAd(nativeAd, layout, ::colour)
        val surface = colour("surface", "#FFFFFF")
        val line = colour("line", "#E6DFD4")
        val tint = colour("tint", "#EFE8DD")
        val ink = colour("ink", "#1A1612")
        val muted = colour("muted", "#8A8178")
        val onInk = colour("onInk", "#FFFFFF")

        val adView = NativeAdView(context)

        val card = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(12), dp(12), dp(12), dp(12))
            background = GradientDrawable().apply {
                setColor(surface)
                cornerRadius = dp(16).toFloat()
                setStroke(dp(1).coerceAtLeast(1), line)
            }
        }

        val icon = ImageView(context).apply {
            scaleType = ImageView.ScaleType.CENTER_CROP
            background = GradientDrawable().apply {
                setColor(tint)
                cornerRadius = dp(10).toFloat()
            }
            clipToOutline = true
        }
        card.addView(icon, LinearLayout.LayoutParams(dp(44), dp(44)).apply { marginEnd = dp(12) })

        val words = LinearLayout(context).apply { orientation = LinearLayout.VERTICAL }
        val headline = label(14f, ink, bold = true)
        words.addView(headline)
        val meta = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val badge = label(10f, muted, bold = true).apply {
            text = "Ad"
            setPadding(dp(4), 0, dp(4), 0)
            background = GradientDrawable().apply {
                cornerRadius = dp(3).toFloat()
                setStroke(dp(1).coerceAtLeast(1), muted)
            }
        }
        meta.addView(badge, LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply { marginEnd = dp(6) })
        val body = label(12f, muted)
        meta.addView(body)
        words.addView(meta, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(3) })
        card.addView(words, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))

        val cta = label(12.5f, onInk, bold = true).apply {
            setPadding(dp(14), dp(9), dp(14), dp(9))
            background = GradientDrawable().apply {
                setColor(ink)
                cornerRadius = dp(999).toFloat()
            }
            // The whole card is the click target; the SDK handles the tap.
            isClickable = false
        }
        card.addView(cta, LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply { marginStart = dp(10) })

        adView.addView(card, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT))
        val choices = AdChoicesView(context)
        adView.addView(choices, FrameLayout.LayoutParams(FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.TOP or Gravity.END).apply {
            topMargin = dp(6)
            marginEnd = dp(6)
        })

        headline.text = nativeAd.headline
        body.text = nativeAd.body ?: ""
        body.visibility = if (nativeAd.body.isNullOrEmpty()) View.GONE else View.VISIBLE
        cta.text = nativeAd.callToAction ?: ""
        cta.visibility = if (nativeAd.callToAction.isNullOrEmpty()) View.GONE else View.VISIBLE
        val iconImage = nativeAd.icon?.drawable
        icon.setImageDrawable(iconImage)
        icon.visibility = if (iconImage == null) View.GONE else View.VISIBLE

        adView.headlineView = headline
        adView.bodyView = body
        adView.callToActionView = cta
        adView.iconView = icon
        adView.adChoicesView = choices
        adView.setNativeAd(nativeAd)
        return adView
    }

    /**
     * The tablet shapes, on a transparent ground (the Dart card shows
     * through), leaving room for the "Remove ads" link Dart lays over them.
     *
     * - strip: 16:9 still · "Ad" + advertiser / headline / body · action,
     *   with the link's space under the action.
     * - stripPortrait: the same, with the link's space under the headline
     *   in place of the body.
     * - compact: "Ad" on top (the link opposite), then a 72 × 56 still and
     *   the headline.
     */
    private fun createTabletAd(nativeAd: NativeAd, layout: String, colour: (String, String) -> Int): NativeAdView {
        val surface = colour("surface", "#FFFFFF")
        val tint = colour("tint", "#EFE8DD")
        val ink = colour("ink", "#1A1612")
        val ink2 = colour("ink2", "#FF3D352C")
        val muted = colour("muted", "#6B6053")
        val line2 = colour("line2", "#331A1612")
        val compact = layout == "compact"
        val portrait = layout == "stripPortrait"

        val adView = NativeAdView(context)

        val media = MediaView(context).apply {
            setImageScaleType(ImageView.ScaleType.CENTER_CROP)
            background = GradientDrawable().apply {
                setColor(tint)
                cornerRadius = dp(if (compact) 10 else 14).toFloat()
                setStroke(dp(1).coerceAtLeast(1), line2, dp(4).toFloat(), dp(3).toFloat())
            }
            clipToOutline = true
        }
        val (mediaW, mediaH) = when {
            compact -> dp(72) to dp(56)
            portrait -> dp(168) to dp(96)
            else -> dp(184) to dp(104)
        }

        val badge = TextView(context).apply {
            text = "AD"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 9.5f)
            setTextColor(ink2)
            typeface = Typeface.MONOSPACE
            letterSpacing = 0.12f
            setPadding(dp(7), dp(2), dp(7), dp(2))
            background = GradientDrawable().apply {
                setColor(tint)
                cornerRadius = dp(6).toFloat()
                setStroke(dp(1).coerceAtLeast(1), line2)
            }
        }
        val headline = label(if (compact) 13f else if (portrait) 15.5f else 16f, ink, bold = true).apply {
            if (compact) maxLines = 2
        }
        adView.headlineView = headline
        // The compact card's still is too small for a MediaView (AdMob asks
        // for 120 dp), so it shows the ad's icon asset instead.
        val icon = ImageView(context).apply {
            scaleType = ImageView.ScaleType.CENTER_CROP
            background = GradientDrawable().apply {
                setColor(tint)
                cornerRadius = dp(10).toFloat()
                setStroke(dp(1).coerceAtLeast(1), line2, dp(4).toFloat(), dp(3).toFloat())
            }
            clipToOutline = true
            setImageDrawable(nativeAd.icon?.drawable)
        }
        if (compact) adView.iconView = icon else adView.mediaView = media

        val root: View
        if (compact) {
            root = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                addView(LinearLayout(context).apply { addView(badge) })
                addView(LinearLayout(context).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER_VERTICAL
                    addView(icon, LinearLayout.LayoutParams(mediaW, mediaH).apply { marginEnd = dp(10) })
                    addView(headline, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
                }, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(8) })
            }
        } else {
            val advertiser = label(12f, muted)
            val words = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                addView(LinearLayout(context).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER_VERTICAL
                    addView(badge)
                    addView(advertiser, LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply { marginStart = dp(8) })
                })
                addView(headline, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(6) })
                if (portrait) {
                    // Where Dart puts "Remove ads".
                    addView(View(context), LinearLayout.LayoutParams(1, dp(21)).apply { topMargin = dp(6) })
                } else {
                    val body = label(12.5f, muted)
                    body.text = nativeAd.body ?: ""
                    body.visibility = if (nativeAd.body.isNullOrEmpty()) View.GONE else View.VISIBLE
                    adView.bodyView = body
                    addView(body, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply { topMargin = dp(6) })
                }
            }
            advertiser.text = nativeAd.advertiser ?: ""
            advertiser.visibility = if (nativeAd.advertiser.isNullOrEmpty()) View.GONE else View.VISIBLE
            adView.advertiserView = advertiser

            val cta = label(13f, ink, bold = true).apply {
                gravity = Gravity.CENTER
                setPadding(dp(if (portrait) 16 else 18), 0, dp(if (portrait) 16 else 18), 0)
                background = GradientDrawable().apply {
                    setColor(surface)
                    cornerRadius = dp(999).toFloat()
                    setStroke(dp(1).coerceAtLeast(1), line2)
                }
                isClickable = false
            }
            cta.text = nativeAd.callToAction ?: ""
            cta.visibility = if (nativeAd.callToAction.isNullOrEmpty()) View.INVISIBLE else View.VISIBLE
            adView.callToActionView = cta
            val actions = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.END
                addView(cta, LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, dp(40)))
                // Where Dart puts "Remove ads", under the action.
                if (!portrait) addView(View(context), LinearLayout.LayoutParams(1, dp(23)))
            }

            root = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                addView(media, LinearLayout.LayoutParams(mediaW, mediaH).apply { marginEnd = dp(if (portrait) 16 else 18) })
                addView(words, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
                addView(actions, LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply { marginStart = dp(if (portrait) 16 else 18) })
            }
        }

        adView.addView(root, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT, Gravity.CENTER_VERTICAL))
        // AdChoices: top right on a strip, bottom right on the compact card,
        // whose top right is "Remove ads".
        val choices = AdChoicesView(context)
        adView.addView(choices, FrameLayout.LayoutParams(FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT, (if (compact) Gravity.BOTTOM else Gravity.TOP) or Gravity.END))
        adView.adChoicesView = choices

        headline.text = nativeAd.headline
        adView.setNativeAd(nativeAd)
        return adView
    }

    private fun label(sizeSp: Float, colour: Int, bold: Boolean = false) = TextView(context).apply {
        setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp)
        setTextColor(colour)
        if (bold) typeface = Typeface.DEFAULT_BOLD
        maxLines = 1
        ellipsize = TextUtils.TruncateAt.END
    }

    private fun dp(value: Int) = (value * context.resources.displayMetrics.density).toInt()

    companion object {
        const val ID = "lastreelCard"
        private val TABLET_LAYOUTS = setOf("strip", "stripPortrait", "compact")
    }
}
