# GitHub native-app authentication references

Research checked 2026-10-21 for TweakStudio's GitHub integration.

- GitHub's OAuth app registration flow assigns an app-specific client ID and requires the app owner to register/configure the OAuth application. Device flow must be enabled in that app's settings: https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/creating-an-oauth-app
- OAuth authorization-code exchange requires `client_id`, `client_secret`, `code`, and recommends `redirect_uri`; if a code challenge was sent, the exchange must include its `code_verifier`. GitHub’s docs also describe device authorization separately for headless clients: https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps
- GitHub announced S256 PKCE support/recommendation for OAuth and GitHub Apps on 2025-07-14. PKCE protects the code exchange, but does not make the existing Manus credential/client ID reusable by TweakStudio. Device flow does not use PKCE: https://github.blog/changelog/2025-07-14-pkce-support-for-oauth-and-github-app-authentication/
- GitHub's public REST repository search is the API used by TweakStudio's limited agent search; it returns repository metadata and is not a general web search: https://docs.github.com/en/rest/search/search?apiVersion=2022-11-28#search-repositories

Implementation implication: native TweakStudio must have its own registered OAuth/GitHub App identity. Never embed a client secret or reuse Manus's token. The 0.4.3 build retains the user-supplied token option, and its app UI reports Keychain OSStatus if storage is rejected. The public GitHub search only receives a short search query; repository results are untrusted reference data and no project/model/token content is sent by the search service.
