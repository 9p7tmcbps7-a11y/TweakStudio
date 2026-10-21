# TweakStudio 0.4.3

## Fixes and changes

- Reduced llama.cpp defaults to two CPU threads, a 2,048-token context, and at most 512 generated tokens per chat request; removed forced JSON response formatting.
- Bounded project context, skill notes, and chat history. General conversation no longer includes project files. Large GGUF files trigger a memory warning, and an iOS memory warning stops the local runner.
- Hardened response parsing so unexpected JSON structures and HTTP errors become visible chat errors rather than unsafe Objective-C subscripting. Local requests time out after three minutes.
- Serialized model start/stop, added stale health-check generation guards, and added a bounded shutdown with SIGKILL fallback.
- Added an Autopilot setting (on by default for new installs): allowlisted source-only changes are backed up, applied, built into a .deb, and may receive at most two source-only repair attempts. It never edits Makefiles/control files, installs packages, or publishes to GitHub.
- Successful AI builds now expose the `.deb` through the iOS share sheet for Save to Files or transfer to a package manager.
- The local agent can auto-select relevant installed local skill notes, save one small AI-generated Markdown guidance note when useful, and request one public GitHub repository-metadata search. Only the short search query is sent; source files, GGUFs, and credentials are not uploaded. Remote skills are not auto-downloaded or executed.
- Added explicit app Keychain group entitlements and surfaced the numeric iOS Keychain OSStatus while keeping token bytes out of logs.

## Limitations

- Physical-device testing on iPhone 11 Pro Max / Dopamine / iOS 18.4.1 is still required. Model-dependent memory use can still exceed iOS limits; the large-model warning is advisory.
- The GitHub search tool searches public repository metadata, not general web pages. OAuth/device sign-in is not enabled in this release because TweakStudio needs its own registered GitHub OAuth client; the GitHub permission used by Manus cannot be shared with an installed iOS app. The existing token flow remains.
- Generated packages are shared/exported, not installed by the AI. Review the package and install it with Sileo/Zebra; the AI never invokes arbitrary shell commands.
