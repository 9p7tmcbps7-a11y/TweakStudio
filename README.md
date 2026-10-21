# TweakStudio 0.4.0

TweakStudio is a native, rootless iOS workspace for creating Theos tweak and UIKit app projects on a jailbroken iPhone. Version 0.4.0 adds an offline local-model agent, an importable GGUF library, local prompt skills, transparent logs, bounded build repair, and private GitHub publishing.

## What is included

- A dedicated Home Screen app with a minimal six-tab interface: **Workspace**, **AI Agent**, **Models**, **Skills**, **Activity**, and **Settings**. The Settings pane remains available as a fallback.
- Starter projects for Logos/Objective-C tweaks and UIKit apps, with an editable native source editor. Generated UIKit apps include a replaceable TweakStudio placeholder icon set and a rootless post-install `uicache` hook so Sileo can register the app on the Home Screen.
- A bundled, CPU-only arm64 `llama-server` built from llama.cpp commit `339f3242c761f16c27e5ffcde1d35dcc31933a55`, plus its versioned dylibs and symlinks. The runner is separate from model files: **no GGUF model is bundled**.
- Import and select `.gguf` files through the iOS document picker. Inference runs on `127.0.0.1`; the model is stopped when TweakStudio backgrounds. Small, quantized instruction/chat models are recommended, especially on 4 GB devices; base completion models may not follow chat formatting.
- Imported local Markdown/text skills with search and per-skill enable switches. Search covers the imported notes on the phone only; it is not a web search or online marketplace. Skills are prompt reference material, not executable plugins.
- Chat that reads the selected project's source context and enabled skills. It can propose source and non-executable metadata file replacements. The complete proposed files are shown in a review screen; manual changes are backed up before application.
- On-device Theos builds, package sharing, activity events, complete latest build output, and the llama-server log.
- An opt-in **Automatic repair attempts** setting. For builds launched through the AI Agent, it allows at most two repair rounds; automatic proposals are restricted to source/non-executable metadata files, saved with backups, and rebuilt. It does not edit Makefiles or package control/scripts. Turn it off for manual review-only troubleshooting.
- GitHub token verification and publishing the selected project's safe text files to a **private** repository. The token is stored in iOS Keychain. Hidden files, build outputs, model files, backups, and package archives are excluded.

## Install and start

Download the rootless Debian package from the [TweakStudio 0.4.0 GitHub release](https://github.com/9p7tmcbps7-a11y/TweakStudio/releases/download/v0.4.0/tweakstudio_0.4.0_iphoneos-arm64.deb), then install or upgrade `com.tweakstudio.ios` with Sileo or Zebra. If the icon does not appear after installation, respring once.

1. Open the **TweakStudio** Home Screen icon. Create an **iOS tweak** or **iOS app**, or choose **Build from an idea** to create a starter and send your description to the Agent.
2. In the app’s **Settings** tab, tap **Set up Theos + iOS SDK** once if you have not already prepared the on-device toolchain. This downloads Theos, an iOS SDK, and the arm64e compatibility helper; it requires a network connection and free storage. The older **Settings → TweakStudio** pane also remains available.
3. In **Models**, tap **Import**, choose a `.gguf` file, then tap the imported model to load it. The model file stays in your workspace and is not included in project packages or GitHub uploads.
4. Select a project in **Workspace**, open **AI Agent**, and describe a small feature. The model runs locally. Read the response and proposed files, open **Review**, and tap **Apply** only if you want those changes written.
5. Tap **Build this project** in chat or select **Build .deb** from the project menu. TweakStudio runs its packaged Theos build helper and saves the actual compiler output under **Activity → Build**; toolchain setup and runner output are in **Setup** and **Runner**.
6. On success, share the `.deb` into Sileo/Zebra or save it to Files. If a build fails, open **Activity → Build** and ask the Agent to diagnose it. The optional automatic repair loop is limited to two retries.

Projects, skills, models, build logs, and runner logs are stored under `/var/mobile/Documents/TweakStudio/`. The app does not upload prompts or project files unless you explicitly use the GitHub publish action. Connecting to GitHub and publishing requires internet access.

## GitHub connection

In the app's **Settings** tab, create a GitHub personal access token with permission to create a private repository and read/write repository contents, then tap **Verify & save securely**. A classic token generally needs the `repo` scope; a fine-grained token must grant equivalent repository creation and contents permissions. Review GitHub's token permissions carefully and use a short expiry if possible. TweakStudio keeps the token in the iOS Keychain, does not put it in logs, and uses it only for GitHub API requests. Publishing is an explicit, separately confirmed action and creates/updates a private repository named after the selected project.

## Important boundaries

- TweakStudio is a developer workspace, not an App Store signing service. App distribution and code-signing requirements remain the developer's responsibility.
- The bundled local runner is **CPU-only**. Performance and the largest usable context/model size depend on the model's quantization, free RAM, storage, and device thermals. The first model load can take time. Importing a model does not guarantee that it will fit in memory.
- Treat GGUF files as untrusted input: import models only from sources you trust, because the local runtime must parse the file. The app does not verify model signatures or provenance.
- The agent is a constrained code assistant, not a general shell operator or web-search engine. It cannot install packages, run arbitrary model-generated commands, or alter build scripts/package control through chat. It uses failure logs for bounded retry context but does not train or permanently learn. Review source proposals; code produced by local models may still be wrong or unsafe.
- The optional automatic repair switch is an explicit trade-off: when enabled, it applies allowlisted source/metadata changes and rebuilds without opening the manual review screen, for at most two attempts. It never installs the resulting `.deb`.
- The GitHub token gives access according to the permissions you grant. Use **Disconnect & forget token** in Settings to remove the saved credential from this device, and revoke it in GitHub if it should no longer work.
- The arm64 runner was cross-compiled for iOS 15.0+ with Theos/Clang and its internal dylib paths were rewritten to relocatable `@rpath` names. **This sandbox cannot launch iOS Mach-O binaries and the package has not been runtime-tested on a physical iPhone.** Please keep the prior working `.deb` available when upgrading and report device-side failures with the Activity logs.
- The generated app/tweak templates are intentionally small Objective-C/Logos starters. Swift, advanced package scripting, and unrestricted project-specific build environments are not included in this release.

## Build TweakStudio from source

For the native app and PreferenceBundle, use a Linux Theos toolchain and SDK:

```sh
export THEOS="$HOME/theos"
export PATH="$THEOS/toolchain/linux/iphone/bin:$PATH"
make clean package FINALPACKAGE=1
```

The Debian package is rootless and intended for jailbreak package managers. On non-macOS hosts, the PreferenceBundle's arm64e slice still needs the documented Theos `allemande` conversion before it can be used on an A13-class target. `tools/release-package.sh` performs that conversion and uses Theos `dm.pl` to produce the gzip-control/LZMA-data archive format expected by common jailbreak package managers. The on-device helper already performs the corresponding conversion for generated packages.

### Rebuild the local llama.cpp server

The server build is pinned to one upstream commit and CPU-only configuration:

```sh
export THEOS="$HOME/theos"
export IOS_SDK="$THEOS/sdks/iPhoneOS16.5.sdk"  # or another installed SDK
./tools/build-llama-server.sh
```

The helper requires host `git`, CMake, and make, plus Theos' iOS clang, SDK, Mach-O `install_name_tool`, `otool`, and `ldid`. It places the executable, required dylibs, and their symlinks in `layout/usr/libexec/tweakstudio/` and rejects any load command that still points at its temporary build directory. The llama.cpp MIT license is included in the package documentation.

## Technical references

- [llama.cpp pinned source](https://github.com/ggml-org/llama.cpp/tree/339f3242c761f16c27e5ffcde1d35dcc31933a55)
- [Theos: Rootless packaging](https://theos.dev/docs/Rootless.html)
- [Theos: Linux installation](https://theos.dev/docs/installation-linux)

## Compatibility and verification

- Rootless package layout: `/var/jb`
- Target architecture: arm64, CPU-only local inference
- Minimum iOS deployment target: iOS 15.0
- Intended use case: Dopamine rootless on iPhone 11 Pro Max / iOS 18.4.1
- Compile/package validation was performed in the Linux cross-build environment. Physical-device runtime, large-model memory use, and GitHub token/API permissions depend on the user's device and token and have not been validated here.

## License

TweakStudio is MIT licensed. The included llama.cpp runner is MIT licensed by the ggml authors; its license is installed at `/var/jb/usr/share/doc/tweakstudio/third-party/llama.cpp-LICENSE`. Theos, Procursus packages, and the iOS SDK retain their respective licenses and are not bundled here.
