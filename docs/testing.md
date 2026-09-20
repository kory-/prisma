# Testing and limitations

## Verified locally

- Native build and ad-hoc code-signature validation on Apple Silicon.
- C++/Objective-C audio logic, slot assignment, preferences and browser state tests with AddressSanitizer and UndefinedBehaviorSanitizer.
- Swift Stream Deck event handling, fixed/automatic targets, dial direction, mute, UI feedback and locale selection.
- Chrome HTML media/Web Audio control, lifecycle, worker sessions, page navigation, multiple tabs and restore behavior.
- Japanese/English catalogs, placeholders, menus, controls and accessibility labels.
- Repeated live language changes preserve audio settings and reuse the same windows; the window count stays at two across 12 switches in the isolated UI test.
- A 20,000-update isolated UI stress test reuses rows. Earlier 0.7.0 measurements showed about 0.17 MiB growth after graphics warm-up. This is a synthetic regression check, not a multi-day endurance result.
- Real playback detection and Chrome tab integration on a development Mac. The user reloaded Prisma Tabs 0.3.0 and a current Chrome tab was visible in Prisma afterward.

Live playback was checked on macOS 26.5.2 and 27.0. The build deployment target is macOS 14.4. A successful CI build on another macOS version does not verify audio capture or physical hardware on that version.

## Limits and pending coverage

- Only Apple Silicon is currently distributed. Windows and Intel builds are unsupported.
- Audio processing supports 32-bit Float stereo on the standard output. Multichannel output, some virtual devices and per-app custom output routing are outside the supported path.
- DRM-protected audio and unusual web audio implementations may not work. All streaming services have not been tested.
- Fresh installation on a separate physical Mac, physical dial listening tests, Bluetooth reconnect, sleep/wake and multi-day operation remain to be verified.
- Developer ID signing and Apple notarization are not configured. Initial macOS permission and Gatekeeper behavior varies by OS and distribution identity.
- Stream Deck minimum software version 6.6 and macOS minimum 14.4 have not both been exercised on hardware.
- Chrome internal pages and sites without extension permission cannot be controlled.

When reporting a problem, include macOS version, Prisma version, output device type and steps to reproduce. Remove personal tab titles and unrelated app names from screenshots or logs.
