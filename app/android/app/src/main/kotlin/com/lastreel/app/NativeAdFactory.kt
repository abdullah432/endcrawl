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
 */
class LastReelNativeAdFactory(private val context: Context) : NativeAdFactory {
    override fun createNativeAd(nativeAd: NativeAd, customOptions: MutableMap<String, Any>?): NativeAdView {
        fun colour(key: String, fallback: String) =
            Color.parseColor((customOptions?.get(key) as? String) ?: fallback)
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
    }
}
