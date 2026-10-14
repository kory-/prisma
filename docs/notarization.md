# Developer ID signing and notarization

This is an optional workflow for maintainers with Developer ID credentials. Current public previews use ad-hoc signatures and are **not** notarized; Apple enrollment and notarization are not part of their release process. Having these scripts does **not** mean an artifact has been notarized. Any future release described as notarized requires a real Apple submission with `Accepted` status, a matching log/archive hash, a stapled app ticket, and successful verification of the app extracted from its final ZIP.

## Account setup

Use an active Apple Developer Program team and a **Developer ID Application** certificate with its matching private key in your login keychain. An `Apple Development` certificate is not sufficient. Create or import the certificate through Apple's account tools; never commit the private key.

Store notarization credentials interactively in Keychain:

```sh
xcrun notarytool store-credentials 'Prisma Notary'
```

Use the prompts for an app-specific Apple Account password or the relevant App Store Connect credentials. Do not paste passwords or API keys into issue reports, build scripts, or chat. This command is a one-time local setup; the project does not extract stored credentials.

## Prepare, submit, resume

```sh
./build.command
./test.command
./test-localization.command
./notarize.command prepare
PRISMA_NOTARY_PROFILE='Prisma Notary' ./notarize.command submit
PRISMA_NOTARY_PROFILE='Prisma Notary' ./notarize.command status
```

`prepare` finds a single Developer ID Application identity or accepts `--identity` with a certificate name or hash. It copies build products into `.build/notarization/payload`, signs the Chrome helper, Stream Deck executable and app with hardened runtime and secure timestamps, then creates an upload archive. Only the app receives the Core Audio audio-input resource entitlement; helper/plugin do not need it. App Sandbox and broad runtime exceptions are not enabled.

`submit` records the attempt **before** contacting Apple. A missing response does not trigger an automatic duplicate upload. Use `notarytool history` to locate an interrupted attempt and reconcile the submission ID before continuing. Do not delete submission state or re-upload merely because status remains `In Progress`.

`status` checks the exact existing submission. It does not upload new software. State and logs remain local under `.build/notarization/`, outside Git.

## Finish only after Apple accepts

```sh
PRISMA_NOTARY_PROFILE='Prisma Notary' \
STREAMDECK_CLI="$PWD/.build/tools/node_modules/.bin/streamdeck" \
./notarize.command finish
```

The workflow checks Apple's log against the uploaded archive, staples a distribution copy, validates the ticket, assesses the app using Gatekeeper, and packages the signed plugin. It then extracts the final app ZIP and repeats signature, staple and Gatekeeper verification. Final files go into `dist/notarized/`, separate from ad-hoc preview files. The original submitted payload is retained unchanged for auditing/resume.

Before publishing, test real playback, permission prompts, Chrome helper communication and plugin launch under the new Developer ID identity. Update release documentation to describe the verified final artifacts and upload those exact files, including their checksums. The standalone Stream Deck executable is included in Apple's submission; an executable does not support stapling in the same way an app bundle does.

## References

- [Apple: Notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Apple: Customizing the workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)
- [Apple: Developer ID certificates](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/)
- [Apple: Audio Input entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.device.audio-input)
