# Keep WorkManager and Room database classes
-keep class * extends androidx.work.Worker { *; }
-keep class * extends androidx.work.ListenableWorker { *; }
-keep class * extends androidx.work.WorkDatabase { *; }
-keep class * extends androidx.room.RoomDatabase { *; }
-keep class * implements androidx.room.RoomDatabase { *; }
-keep class androidx.work.impl.** { *; }
-keep class androidx.room.** { *; }
-dontwarn androidx.work.impl.**
-dontwarn androidx.room.**

# Microsoft Clarity
-keep class com.microsoft.clarity.** { *; }
-keepclassmembers class com.microsoft.clarity.** { *; }
-keep interface com.microsoft.clarity.** { *; }
-keep enum com.microsoft.clarity.** { *; }
-keepnames class com.microsoft.clarity.** { *; }
-dontwarn com.microsoft.clarity.**

# RevenueCat
-keep class com.revenuecat.purchases.** { *; }
