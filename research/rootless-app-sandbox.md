# Rootless app filesystem access notes

The official Dopamine overview describes Dopamine as rootless and says rootless jailbreaks do not provide full access to the iOS operating system; only selected filesystem areas are writable: https://ellekit.space/dopamine/.

A Stack Overflow developer discussion about Theos-built apps outside the App Store sandbox reports use of `com.apple.private.security.no-container` to disable the app container. This is community guidance rather than official Apple or Dopamine documentation: https://stackoverflow.com/questions/53028840/ios-accessing-filesystem-outside-sandbox-on-a-jailbroken-device.

TweakStudio’s standalone Home Screen app uses this private entitlement because its architecture needs the shared `/var/mobile/Documents/TweakStudio` workspace and Theos tools under `/var/jb`. It runs as the `mobile` user, not root. The Settings PreferenceBundle is hosted by the system Settings process and does not receive this entitlement. The entitlement was disclosed to the user, who explicitly approved it on 2026-10-21.
