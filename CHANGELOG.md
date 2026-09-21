# Changelog

## 0.7.1 — In preparation

- Add an optional Developer ID signing and resumable Apple notarization workflow for the app, Chrome native helper and Stream Deck executable. Current previews remain ad-hoc signed and not notarized; Marketplace approval is still pending.
- Prepare Stream Deck plugin 0.4.2.0, listing text, thumbnail and three gallery images for submission. Enable SDK 3 for Marketplace processing; the new plugin requires Stream Deck 6.9 or later.
- Verify the exact submitted archive and the final extracted app, and guard against duplicate notarization uploads.
- Add app copyright metadata. Audio behavior is unchanged.

## 0.7.0 — First public preview

- Native per-app volume and mute, menu bar controls and default output selection.
- Login launch, startup audio behavior, appearance, Dock visibility and menu settings.
- Japanese and English in the app, permission descriptions and both integrations.
- Reused mixer rows, cached icons and paused hidden-window rendering to fix sustained UI memory growth.
- Reused windows when changing languages.
- Prisma Tabs 0.3.0: automatic tab detection, independent tab volume/mute and local native messaging.
- Stream Deck plugin 0.4.1.0: playing-app dials, fixed targets, volume/mute keys, localized settings and setup link. The first public plugin ID is `io.github.kory-.prisma`.
- Portable checkout-local build/test scripts, installation docs, privacy notes and release checksums.

The macOS app is ad-hoc signed and not notarized. This is an early test release, not a claim of complete hardware or streaming-service compatibility.
