TweakStudio 0.3.1 installs both a Home Screen app icon and a Settings > TweakStudio pane. Both open the same native workspace for creating and editing rootless Theos tweak and UIKit app projects.

Quick start:
1. Open Settings > TweakStudio and create a tweak or app project.
2. Use Choose existing project and Edit project source to work on saved projects.
3. Tap Set up Theos + iOS SDK once. This fetches Theos, the SDK, and the arm64e helper.
4. Tap Build current project (.deb), then Share latest package to send it to Sileo/Zebra.

Projects and Theos are stored under /var/mobile/Documents/TweakStudio so both entry points can use the same workspace. This early release has not been installed or runtime-tested on a physical iPhone. The arm64e helper's upstream documentation notes limitations, especially Swift; see the source README for details.
