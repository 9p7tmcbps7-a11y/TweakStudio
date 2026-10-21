# TweakStudio 0.4.1 quick start

1. Open the TweakStudio Home Screen icon; create/select a Theos tweak or UIKit app project.
2. In the app's **Settings** tab, use **Set up Theos + iOS SDK** once. It downloads Theos, an iOS SDK, and the arm64e compatibility helper. Keep the app open and see **Activity → Setup** for output. Setup is resumable and skips an up-to-date converter build.
3. Import a `.gguf` file in **Models**; the picker opens provider files in place and large imports copy in the background. Tap the imported file to load the on-device CPU runner. Smaller quantized models are recommended. Models are not included in the package or uploaded with source.
4. Ask the local agent to implement a small feature. It can inspect supplied project files/local skills, propose changes for review, request a build, and use build output for bounded diagnosis; it is not equivalent to Manus or a web-connected general agent. Review its complete proposed source/metadata files before **Apply**. Optional automatic build repairs are limited to two source-only rounds and never install a package.
5. Build the project. Follow complete output in **Activity → Build**, then share the `.deb` to Sileo or Zebra.
6. Install optional local `.md`/`.txt` reference skills in **Skills**. GitHub publishing to a private repository is an explicit action in **Settings**; the token is stored in iOS Keychain. **Disconnect & forget token** removes it from this device.

Workspace: `/var/mobile/Documents/TweakStudio/`. Activity event log: `Logs/activity.jsonl`; build, setup, and local-runner output: `Logs/latest-build.log`, `Logs/latest-setup.log`, and `Logs/llama-server.log`.

The bundled llama.cpp server is CPU-only arm64 with a 6144-token context configuration and listens on loopback. Device memory, model quantization, and thermals limit practical model size and speed. Physical-device runtime has not yet been validated for this release. TweakStudio does not bundle a GGUF model.

Security note: the Home Screen app uses `com.apple.private.security.no-container` so it can reach the shared `/var/mobile/Documents/TweakStudio` workspace and launch Theos tools. It runs as `mobile`, not root, but has broader filesystem access than a normal sandboxed app. Install only trusted builds; the chat allowlist does not remove this process-level permission.
