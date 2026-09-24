# Sign OmaDeck Watch for Firefox and Zen

## Status

Prepared for **unlisted / self-distributed** Mozilla signing. There is no signed
XPI yet and no public AMO listing. The plugin-store release remains a separate
draft. A local lint pass does not establish Mozilla approval or signature validity.

## When Erik is back at his computer

1. Open https://addons.mozilla.org/developers/ and sign in to your Mozilla
   developer account. No password or API secret needs to be shared with Codex.
2. Choose **Submit a New Add-on**, then **On your own**. For later versions use
   this same add-on's version-upload page, not a new add-on entry.
3. Upload `omadeck-watch-firefox-v0.10.0-unsigned.zip` from the prepared kit.
   Choose **Linux** as the supported platform; the companion app needs Omarchy.
4. The extension contains its original readable JavaScript with no compilation,
   minification or external libraries. Answer the source-processing question
   accordingly. `companion-source.zip` is included if Mozilla asks to inspect the
   native companion; it is not the add-on upload.
5. If reviewer notes or privacy details are requested, use `REVIEWER-NOTES.md`
   and `PRIVACY.md` from the kit. Resolve validation errors before proceeding.
6. Complete the submission. When signing finishes, download the **signed `.xpi`**
   from that version's details and retain the original bytes. Renaming a ZIP to
   XPI does not sign it. Keep `submission.json` and `SHA256SUMS` with the download.

Signing may require review. Do not change the stable add-on ID
`pretty.omadeck.watch@theairick`: the installed native-host registration uses it.

## Reproduce the kit (maintainer)

Commit the intended source first, then:

```bash
./scripts/prepare-firefox-signing --ref HEAD --output "$HOME/Downloads/OmaDeck-Firefox-Signing-v0.10.0"
```

The output must be new or empty. The script reads only the chosen Git commit,
includes its source archive and records its SHA. It never signs, uploads, reads
credentials, changes browser profiles or updates the release draft.

For local Mozilla validation, extract the unsigned ZIP into a disposable folder
and run `web-ext lint --source-dir THAT_FOLDER --self-hosted` with **web-ext
10.7.0** (Node 22+). The `--self-hosted` flag is necessary because this extension
intentionally includes its own update URL. Retain the results beside the kit.

### Preparation checks — September 24, 2026

- 13 focused tests passed: committed-source packaging, byte-for-byte repeatable
  ZIPs/checksums, agreement with the release packager, preserving existing kits,
  rejecting version/consent mismatches, and browser/native handoff regressions.
- Mozilla `web-ext 10.7.0` lint: zero errors, zero notices, one Android warning
  (`KEY_FIREFOX_ANDROID_UNSUPPORTED_BY_MIN_VERSION`). Android introduced consent
  later than desktop; this extension's platform is **Linux desktop only**. Do
  not select Android during submission. Desktop's minimum remains Firefox 140.
- Temporary-load checks passed in disposable Firefox 156 and Zen profiles:
  extension active, YouTube origins and both consent categories recognized.
  Unique test IDs prevented connecting to the owner's native host. These checks
  do not verify a signed install, its consent dialog, persistence after restart
  or automatic updating; those require the signed XPI.

## After Mozilla returns the signed file

Before distributing it:

1. Compare every non-signature file in the XPI against the submitted ZIP. Only
   Mozilla's signature metadata may be added. Check ID, version and update URL.
2. Install the XPI in a disposable normal Firefox profile **with signature
   enforcement enabled**, then restart and verify it remains installed. Repeat
   with Zen. File names or `META-INF` entries alone do not verify the signature.
3. In the isolated native-host fixture, test Watch here, Return with the updated
   timestamp, closed-source-tab recovery, and consent/install behavior. Then
   complete the owner's normal installed-profile round trip when available.
4. Attach the untouched XPI as `omadeck-watch-firefox-v0.10.0.xpi` to the correct
   OmaDeck release draft, recording its SHA-256 and the submitted source SHA.
   Rebuild the other release assets from the approved current source. Release
   publication and the Omarchy store submission need their separate release gates.

## Automatic updates

The installed extension will check this stable HTTPS feed:

https://raw.githubusercontent.com/TheAirick/OmaDeck/main/browser/watch-extension/firefox-updates.json

It currently advertises **no versions**. Keep this path available permanently.
The feed must only advertise a Mozilla-signed, browser-verified, publicly
downloadable XPI after release approval. Draft GitHub assets cannot be downloaded
by ordinary users and must not be advertised. An example entry is:

```json
{
  "version": "0.10.0",
  "update_link": "https://github.com/TheAirick/OmaDeck/releases/download/v0.10.0/omadeck-watch-firefox-v0.10.0.xpi",
  "update_hash": "sha256:REPLACE_WITH_THE_SIGNED_XPI_SHA256",
  "applications": { "gecko": { "strict_min_version": "140.0" } }
}
```

Add the entry under `addons["pretty.omadeck.watch@theairick"].updates`. Verify an
unauthenticated download matches that hash **before** committing the feed entry.
Never repoint an existing version to changed bytes. Future changes require a
higher extension version and a new Mozilla signature. Use a disposable profile
to test an actual signed-version upgrade when two signed versions exist; no
automatic-upgrade success is claimed from an empty feed.

## Mozilla references

- [Unlisted submission steps](https://extensionworkshop.com/documentation/publish/submitting-an-add-on/#self-distribution)
- [Self-distribution](https://extensionworkshop.com/documentation/publish/self-distribution/)
- [Update manifests](https://extensionworkshop.com/documentation/manage/updating-your-extension/)
- [Built-in data consent](https://extensionworkshop.com/documentation/develop/firefox-builtin-data-consent/)
