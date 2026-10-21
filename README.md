# TweakStudio 0.4.3

TweakStudio is a native, rootless iOS workspace for creating Theos tweak and UIKit app projects on a jailbroken iPhone. Version 0.4.3 focuses on local-chat stability, serialized llama.cpp lifecycle, bounded Autopilot builds, and Keychain diagnostics. Physical-device testing remains necessary.

## What is included

- A dedicated Home Screen app with a minimal six-tab interface: **Workspace**, **AI Agent**, **Models**, **Skills**, **Activity**, and **Settings**. The Settings pane remains available as a fallback.
- Starter projects for Logos/Objective-C tweaks and UIKit apps, with an editable native source editor. Generated UIKit apps include a replaceable TweakStudio placeholder icon set and a rootless post-install `uicache` hook so Sileo can register the app on the Home Screen.
- A bundled, CPU-only arm64 `llama-server` built from llama.cpp commit `339f3242c761f16c27e5ffcde1d35dcc31933a55`, plus its versioned dylibs and symlinks. The runner is separate from model files: **no GGUF model is bundled**.
- Import `.gguf` files through the iOS in-place document picker; large files copy in the background with coordinated file-provider access and visible status. Inference runs on `127.0.0.1`; the model is stopped when TweakStudio backgrounds. Small, quantized instruction/chat models are recommended, especially on 4 GB devices; base completion models may not follow chat formatting.
- Imported local Markdown/text skills with search and per-skill enable switches. The agent auto-selects relevant installed notes; Autopilot may add one generated local Markdown note. Notes are reference material, not executable plugins. The agent can request one public GitHub repository-metadata search; it is not general web search and does not auto-download remote skills.
- Chat that reads a bounded slice of selected-project context for coding tasks. With Autopilot on, safe allowlisted source edits are backed up, applied, and built into a `.deb`; with it off, the complete proposed files are shown for review.
- On-device keyboard-aware chat composition with tap/scroll dismissal, Theos builds, package sharing, activity events, complete latest build output, and the llama-server log.
- **Autopilot** is on by default for new installs. It automatically applies only allowlisted source changes with backups, builds the `.deb`, and may make at most two source-only repair attempts. It never edits Makefiles, package control/scripts, or installs the package. Turn it off to review and apply changes manually.
- GitHub token verification and publishing the selected project's safe text files to a **private** repository. The token is stored in the app-owned iOS Keychain group; a Keychain failure shows its numeric OSStatus. Hidden files, build outputs, model files, backups, and package archives are excluded.

## Install and start

Download the rootless Debian package from the [TweakStudio 0.4.3 GitHub release](https://github.com/9p7tmcbps7-a11y/TweakStudio/releases/download/v0.4.3/tweakstudio_0.4.3_iphoneos-arm64.deb), then install or upgrade `com.tweakstudio.ios` with Sileo or Zebra. If the icon does not appear after installation, respring once.

1. Open the **TweakStudio** Home Screen icon. Create an **iOS tweak** or **iOS app**, or choose **Build from an idea** to create a starter and send your description to the Agent.
2. In the app’s **Settings** tab, tap **Set up Theos + iOS SDK** once if you have not already prepared the on-device toolchain. This downloads Theos and an iOS SDK; it requires a network connection and free storage. Setup resumes existing installs and does not clone or compile an extra C++ helper on the phone. New tweak starters target arm64, avoiding the converter step that caused the previous setup crash. The older **Settings → TweakStudio** pane also remains available.
3. In **Models**, tap **Import**, choose a `.gguf` file, then tap the imported model to load it. The model file stays in your workspace and is not included in project packages or GitHub uploads.
4. Select a project in **Workspace**, open **AI Agent**, and describe a feature. The model runs locally. With Autopilot on, allowlisted edits are backed up and built automatically; turn Autopilot off if you want to review and apply every change yourself.
5. Tap **Build this project** in chat or select **Build .deb** from the project menu. TweakStudio runs its packaged Theos build helper and saves the actual compiler output under **Activity → Build**; toolchain setup and runner output are in **Setup** and **Runner**.
6. On success, tap the package share action to save the `.deb` to Files or transfer it to Sileo/Zebra; installation is still your explicit step. Build output is available in **Activity → Build**. Autopilot may retry a failed build at most twice.

Projects, skills, models, build logs, and runner logs are stored under `/var/mobile/Documents/TweakStudio/`. To let the Home Screen app access that shared workspace and launch Theos tools, its executable is signed with Apple’s private `com.apple.private.security.no-container` entitlement. It runs as the `mobile` user—not root—but has broader access to files available to that user than a normal containerized app. Install only trusted TweakStudio builds. The Agent’s file-change allowlist does not change the app process’s filesystem permission. TweakStudio does not upload prompts or project files for inference. Public GitHub search sends only the short requested query, never source files, model files, or credentials. Publishing requires internet access and is always explicit.

## GitHub connection

In **Settings**, enter a GitHub personal access token with permission to create a private repository and read/write repository contents, then tap **Verify & save securely**. A classic token generally needs `repo`; a fine-grained token needs equivalent permissions. Use a short expiry if possible. The token stays in the app-owned Keychain group, is not logged, and is used only for GitHub API requests. Publishing is a separately confirmed action. TweakStudio cannot inherit the GitHub authorization you granted to Manus. A future browser/device sign-in needs its own registered GitHub OAuth client; 0.4.3 keeps the token flow.

## Important boundaries

- TweakStudio is a developer workspace, not an App Store signing service. App distribution and code-signing requirements remain the developer's responsibility.
- The bundled local runner is **CPU-only**. Performance and the largest usable context/model size depend on the model's quantization, free RAM, storage, and device thermals. The first model load can take time. Importing a model does not guarantee that it will fit in memory.
- Treat GGUF files as untrusted input: import models only from sources you trust, because the local runtime must parse the file. The app does not verify model signatures or provenance.
- The agent is a constrained on-device coding assistant, not Manus itself or a general shell operator. It can use bounded project context, relevant local skill notes, one public GitHub repository-metadata search, Theos builds, and up to two bounded repairs. It cannot search general web pages, auto-install remote skills, install packages, run arbitrary model-generated commands, or change package scripts/control through chat. It does not train or permanently learn. Local-model output may still be wrong or unsafe.
- Autopilot is the default for new installs. When enabled, it applies allowlisted source changes with backups and builds without opening the manual review screen; it can attempt at most two repairs. It never installs the resulting `.deb`.
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

The Debian package is rootless and intended for jailbreak package managers. On non-macOS hosts, the PreferenceBundle's Linux-built arm64e slice still needs the documented Theos `allemande` conversion. `tools/release-package.sh` performs that conversion, signs the Home Screen app with `TweakStudioApp/Entitlements.plist`, and uses Theos `dm.pl` to produce the gzip-control/LZMA-data archive format expected by common jailbreak package managers. A raw `make package` output is not the complete release package. On-device starter projects target arm64 and use the iPhone's native Theos compiler, so setup/build no longer compile or run the host-side converter. If a tweak project created before 0.4.2 still has `ARCHS := arm64 arm64e`, change that line to `ARCHS := arm64` before building; the helper reports this case without modifying the Makefile.

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
