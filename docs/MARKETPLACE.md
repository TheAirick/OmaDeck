# Marketplace installation

Investigated 2026-09-05. These are dated marketplace facts, not settings
controlled by OmaDeck's manifest.

The [OmaDeck listing](https://plugins.omarchy.org/plugin.html?id=pretty.omadeck)
is snapshot-verified and its upstream compatibility check passes. The
[marketplace registry](https://github.com/omacom/omarchy-plugin-marketplace/blob/main/registry.json)
contains an explicit `installation.mode: "manual"` override for `pretty.omadeck`.
That suppresses the install command even for a verified root plugin.

Removing the override allows the catalog to generate:

```bash
omarchy plugin add https://github.com/TheAirick/OmaDeck.git --enable
```

This command clones current upstream HEAD. The default branch is `main`,
verified at `36578b3ba701db709b69ac6dccb32e61d53e34a0` during this investigation.
It does not deliver uncommitted changes or `codex/preferences-center` by default.

## Existing request and remaining requirement

[Issue #4838: OmaDeck standard installation](https://github.com/omacom/omarchy-plugin-marketplace/issues/4838)
was opened by TheAirick on September 4. It already selects “Verify the listed
snapshot and enable standard installation,” supplies the exact listed SHA, and
checks both acknowledgments. It was open with no labels or comments when
checked. Continue this request rather than creating another submission.

The [verification workflow](https://github.com/omacom/omarchy-plugin-marketplace/blob/main/VERIFICATION.md)
requires a passing automated baseline and an authenticated
`standard-installation-approved` maintainer action before removing the override.
A snapshot-verification attestation alone does not satisfy this separate gate.

The recorded baseline is `review-required`, with no findings and one
`remote-build` capability. Running the current marketplace source analyzer on
that exact Git snapshot reproduced the capability, pointing to README.md line
154: the developer `git clone` example. Standard-mode installation itself has no
build step; native touch/tray compilation is optional and documented separately.
This local reproduction is diagnostic evidence, not an official marketplace scan.
The marketplace must resolve the classification and obtain a passing baseline;
its current standard-installation workflow does not permit a maintainer review
to override that requirement.

## v0.8.0 release coordination

The v0.8.0-rc.1 candidate consolidates the duplicate developer checkout example
into the existing CONTRIBUTING.md guide. The README still documents the
standard install path and optional native build openly. No runtime helper,
dependency, or native capability was removed or hidden by this documentation
change; the optional build continues to compile local checked-out source.

Local analysis of the candidate using the marketplace's current baseline-v3
analyzer returned `passed`, with no findings or review capabilities. The
analyzer source was retrieved at marketplace commit
`4e3900bc510556e50b50e01f644f8e1e7a29341a`. This is diagnostic evidence;
marketplace verification requires its own scan of the published exact SHA.

Erik accepted the v0.8.0-rc.1 hardware tests on September 7. The final v0.8.0
package changes only version metadata and documentation from that candidate.
Its release notes cover all changes since v0.7.2.
The existing issue should receive the exact final candidate SHA and links to
its release, PR, and CI. Do not retarget its standard-installation action to a
commit that is not yet the listed snapshot: the workflow rejects that mismatch.

After the accepted release reaches `main`, use the newer-upstream verification
workflow to publish that exact snapshot. Then request standard installation
against the newly listed SHA, including the changed developer documentation and
passing scan evidence. Maintainer approval is still required. This keeps the
Bash command, default branch, and verified snapshot aligned.
