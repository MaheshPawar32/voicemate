# Vokey release shrinker rules.
#
# STARTUP CRASH FIX (2026-11-06):
# google_mobile_ads -> play-services-ads 25.5.0 pulls androidx.work:work-runtime
# 2.7.0 + androidx.room:room-runtime 2.2.5. WorkManager is auto-initialised by
# androidx.startup.InitializationProvider *before* MainActivity or Dart runs.
# Room 2.2.5 creates WorkDatabase_Impl reflectively via Class.newInstance().
# work-runtime 2.7.0 only ships `-keep class * extends RoomDatabase` (no
# members). Under R8 full mode (AGP 9 default) that keeps the class name but
# strips the no-arg constructor, so every release build crashed at launch with
# "Failed to create an instance of androidx.work.impl.WorkDatabase".
-keep class * extends androidx.room.RoomDatabase {
    <init>();
}

# Vosk (offline speech) binds native code through JNA, which relies on
# reflection for Structure/Callback/PointerType subclasses.
-keep class com.sun.jna.** { *; }
-keepclassmembers class * extends com.sun.jna.** { public *; }
-keep class org.vosk.** { *; }
-dontwarn java.awt.**
