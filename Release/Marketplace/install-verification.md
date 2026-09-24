# Plugin installation verification — 2026-09-24

The Marketplace reviewer reported that Prisma 0.4.2 could not be installed. The exact error, operating system, CPU architecture and Stream Deck version used by the reviewer have not been provided. The failure has **not been reproduced** on the test Mac below.

## Test environment

- Apple Silicon (arm64), macOS 27.0, build 26A428.
- Stream Deck 7.4.0 (22712), with a Stream Deck + connected.
- Public plugin UUID: `io.github.kory-.prisma`, version 0.4.2.0.
- No public-UUID plugin was installed before the first test. The older private development plugin uses a different UUID and was retained.
- Packages were opened in Finder and installed by Stream Deck, rather than linked or copied from the development directory.

## Results

| Package | SHA-256 | Result |
| --- | --- | --- |
| Original submission, downloaded after Marketplace processing | `c85ef4a1ffd75adec758f167e35c08c733113cbcdfdb84e9a2c8d59579a6aa3d` | Fresh installation succeeded. Stream Deck displayed its installation confirmation and logged `AllOk` followed by `Plugin connected`. |
| Revised local CLI package with preserved Unix permissions | `a08af4edbd5dbebc4f3b39f9cb901e1f9f0b85d829388596d1c8b887967e3b9b` | After uninstalling the first test installation, fresh installation succeeded with the same confirmation and connection events. The installed binary matched the archive and passed `codesign --verify --strict`. |

The first installation completed at 15:46 JST; the revised package installation completed at 15:57 JST. Both use the same native executable payload. The revised package has not been uploaded for Marketplace processing or re-review.

## What the permissions change establishes

The original CLI archive loses executable permissions. Extracting it with `ditto` and launching it directly fails with `Permission denied`. The revised package preserves permissions and passes `Tests/PackedPluginTests.py` without a post-extraction `chmod`.

However, Stream Deck 7.4.0 restored executable permissions when installing the original Marketplace download. The permission loss therefore does **not** establish the cause of the reviewer's installation failure. It is a packaging robustness improvement with an automated regression test.

## Remaining verification

- Obtain the reviewer's OS, CPU architecture, Stream Deck version and exact error, and distinguish an installation rejection from a plugin launch or app-connection problem.
- Reproduce the reported failure in the relevant supported environment before claiming it fixed.
- Verify any subsequently revised Marketplace-processed download before re-review.

The advertised minimums remain macOS 14.4 on Apple Silicon and Stream Deck 6.9. This run does not verify those minimum versions, Intel or Windows support, a clean macOS user account, audio playback, or physical dial operation. Existing profiles were not edited during these installation tests.
