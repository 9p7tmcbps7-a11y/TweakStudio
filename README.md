# TweakStudio 0.3.2

TweakStudio is a UI-first, rootless iOS developer workspace for Dopamine-style jailbreaks. It now installs both a dedicated **Home Screen app with its own icon** and a **Settings → TweakStudio** pane. Both host the same project editor and build workflow.

## What it does

- Creates starter Theos projects for Logos/Objective-C tweaks and UIKit apps.
- Installs a native Home Screen app at `/var/jb/Applications/TweakStudioApp.app`; a post-install hook refreshes the jailbreak app registry so SpringBoard can show its icon.
- Switches between existing projects and edits their primary source file, Makefile, package control file, and project/filter plist in a native text editor.
- Installs the Theos source tree and latest iOS SDK using the **Set up Theos + iOS SDK** button. The package depends on Procursus' `theos-dependencies`, `git`, `curl`, and `xz` packages.
- Builds the current project on-device with Theos, converts legacy arm64e output with `allemande`, and stores package output in the project's `packages/` directory.
- Shares the latest `.deb` for importing into Sileo/Zebra.

This is an early open-source release. The toolchain bootstrap and package build are designed for the on-device Procursus environment, but this build was compiled in a Linux cross-build environment and was **not installed or tested on an iPhone**. The generated tweaks/apps are starter projects, not an unrestricted App Store signing solution. The build helper applies `allemande` to arm64e Mach-O files in the generated package. Its maintainer warns it is not a complete solution and does not support Swift code; keep projects Objective-C/Logos for this release.

## Install and use

Download the prebuilt package from the [TweakStudio 0.3.2 GitHub release](https://github.com/9p7tmcbps7-a11y/TweakStudio/releases/download/v0.3.2/tweakstudio_0.3.2_iphoneos-arm64.deb). This release keeps the 0.3.1 registration fixes and uses the gzip-control/LZMA-data Debian archive format produced by Theos for iOS jailbreak packages; the prior manually repacked file used Zstandard compression.

1. Install or upgrade the rootless `com.tweakstudio.ios` package using Sileo or Zebra. Respring once if the icon or pane has not appeared after installation.
2. Open the new **TweakStudio** Home Screen icon, or use **Settings → TweakStudio**.
3. Enter a project name, then tap **New tweak project** or **New app project**.
4. Tap **Edit project source** to modify the source, Makefile, or package control file. Save before leaving the editor.
5. Tap **Set up Theos + iOS SDK** once. This downloads the Theos source tree, the latest iOS SDK, and builds `allemande` into the TweakStudio tools folder. The package manager supplies compiler/build tools.
6. Tap **Build current project (.deb)**. The result is saved inside that project's `packages/` folder.
7. Tap **Share latest package** and choose Sileo or Zebra to import/install it.

Projects are stored at `/var/mobile/Documents/TweakStudio/Projects/`, shared between the Home Screen app and Settings pane. The workspace/toolchain lives at `/var/mobile/Documents/TweakStudio/` so both entry points use the same Theos installation.

## Build the package from source

Theos must be available locally:

```sh
export THEOS="$HOME/theos"
export PATH="$THEOS/toolchain/linux/iphone/bin:$PATH"
make clean package
```

On non-macOS hosts, Theos may emit an older arm64e ABI. TweakStudio's on-device build helper uses the documented `allemande` converter; manually built packages outside the UI do not receive that conversion. Test packages on the intended device before distributing.

## Compatibility

- Rootless package layout: `/var/jb`
- Intended environment: Dopamine rootless; package deployment target iOS 15+
- Device target for the requested use case: iPhone 11 Pro Max, iOS 18.4.1
- Home Screen app and Settings pane are packaged together; physical-device installation/runtime verification has not yet been performed

## License

MIT. Theos, Procursus tools, and the iOS SDK retain their respective licenses; none of those third-party toolchains or SDK files are bundled in this repository.

## Technical references

- [Theos: Rootless packaging](https://theos.dev/docs/Rootless.html)
- [Theos: Installing on iOS](https://theos.dev/docs/installation-ios)
- [Theos: arm64e deployment caveats](https://theos.dev/docs/arm64e-deployment)
- [p0358/allemande: arm64e old-ABI converter and limitations](https://github.com/p0358/allemande)
