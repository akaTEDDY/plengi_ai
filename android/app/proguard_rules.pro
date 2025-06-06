# Add project specific ProGuard rules here.
# By default, the flags in this file are appended to flags specified
# in /Users/koojh74/Library/Android/sdk/tools/proguard/proguard-android.txt
# You can edit the include path and order by changing the proguardFiles
# directive in build.gradle.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# Add any project specific keep options here:


-keepattributes Signature, Exceptions, *Annotation*, SourceFile, LineNumberTable, EnclosingMethod

# R8 compatibility for GSON
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

-dontnote retrofit2.Platform
-dontwarn okio.**
-dontwarn retrofit2.Platform$Java8
-dontwarn okhttp3.**
-dontwarn javax.annotation.**
-keepclasseswithmembers class * {
    @retrofit2.http.* <methods>;
}
-dontwarn okhttp3.internal.platform.*
-dontwarn org.conscrypt.*
