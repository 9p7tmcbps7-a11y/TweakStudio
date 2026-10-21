# TweakStudio

TweakStudio is a UI-first, rootless iOS developer workspace for Dopamine-style jailbreaks. It appears inside **Settings** and lets you create tweak or UIKit app projects, edit their source and Makefile in a native editor, run Theos builds on the phone, and share the resulting `.deb` through the iOS share sheet.

## What it does

- Creates starter Theos projects for Logos/Objective-C tweaks and UIKit apps.
- Switches between existing projects and edits their primary source file, Makefile, package control file, and project/filter plist in a native text editor.
- Installs the Theos source tree and latest iOS SDK using the **Set up Theos + iOS SDK** button. The package depends on Procursus' `theos-dependencies`, `git`, `curl`, and `xz` packages.
- Builds the current project on-device with Theos, converts legacy arm64e output with `allemande`, and stores package output in the project's `packages/` directory.
- Shares the latest `.deb` for importing into Sileo/Zebra.

This is an early open-source release. The toolchain bootstrap and package build are designed for the on-device Procursus environment, but this build was compiled in a Linux cross-build environment and was **not installed or tested on an iPhone**. The generated tweaks/apps are starter projects, not an unrestricted App Store signing solution. The build helper applies `allemande` to arm64e Mach-O files in the generated package. Its maintainer warns it is not a complete solution and does not support Swift code; keep projects Objective-C/Logos for this release.

## Install and use

Download the prebuilt package from the [TweakStudio 0.2.0 GitHub release](https://github.com/9p7tmcbps7-a11y/TweakStudio/releases/download/v0.2.0/tweakstudio_0.2.0_iphoneos-arm64.deb).

1. Install the rootless `com.tweakstudio.ios` package using Sileo or Zebra.
2. Open **Settings → TweakStudio**.
3. Enter a project name, then tap **New tweak project** or **New app project**.
4. Tap **Edit project source** to modify the source, Makefile, or package control file. Save before leaving the editor.
5. Tap **Set up Theos + iOS SDK** once. This downloads the Theos source tree, the latest iOS SDK, and builds `allemande` into the TweakStudio tools folder. The package manager supplies compiler/build tools.
6. Tap **Build current project (.deb)**. The result is saved inside that project's `packages/` folder.
7. Tap **Share latest package** and choose Sileo or Zebra to import/install it.

Projects are stored at `~/Documents/TweakStudio/Projects/`. The UI remembers the current project and provides a project picker.

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
- Device installation and runtime verification: not yet performed

## License

MIT. Theos, Procursus tools, and the iOS SDK retain their respective licenses; none of those third-party toolchains or SDK files are bundled in this repository.

## Technical references

- [Theos: Rootless packaging](https://theos.dev/docs/Rootless.html)
- [Theos: Installing on iOS](https://theos.dev/docs/installation-ios)
- [Theos: arm64e deployment caveats](https://theos.dev/docs/arm64e-deployment)
- [p0358/allemande: arm64e old-ABI converter and limitations](https://github.com/p0358/allemande)
