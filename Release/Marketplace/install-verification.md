# Plugin installation verification

## Corrected UUID — 2026-10-15

Elgato reported on October 14 (UTC) that changing `io.github.kory-.prisma` to `io.github.kory.prisma` allowed installation on their test machines, and requested a new Maker Console product with that ID. Version 0.4.3.0 implements the change across the manifest, action IDs, localization catalogs, packaging and optional profile. The old failure has not been reproduced locally; the diagnosis comes from Elgato's review team.

- Test machine: Apple Silicon, macOS 27.0.1 (26A434), Stream Deck 7.4.2 (22730).
- Packed CLI archive: `io.github.kory.prisma.streamDeckPlugin`, 428,888 bytes.
- SHA-256: `73351e95fe31941b328854a7f0c4104cd61f03c0204b253948ae58afa095ae77`.
- Official CLI 1.9.0 validation and packaging passed.
- `./test.command` passed, including Stream Deck logic and both language catalogs.
- `Tests/PackedPluginTests.py` passed with extraction into a temporary directory outside the checkout, unmodified executable permissions, signature verification, WebSocket registration and key/dial feedback. It also checks reverse-DNS labels, action/catalog IDs, listing metadata and the generated profile.
- Finder opened the exact packed archive, and Stream Deck installed the previously absent new UUID normally. The UI confirmed installation; the log recorded `AllOk` at 07:48:48.731 JST and `Plugin connected` at 07:48:48.786 JST. The installed binary matches the archive and passes strict signature verification.
- Existing old-ID plugins and profiles were retained. Actions do not migrate automatically across UUIDs.

Maker Console recognized the uploaded UUID, version, SDK 3, macOS 14.4+, Stream Deck 6.9+ and both languages. New-product creation is currently blocked by a validation error on the existing name `Prisma`; Continue is disabled. The existing product's name is read-only. No new submission or Marketplace approval is claimed. The corrected Marketplace-processed download is not yet available for an installation test.

The advertised minimum OS/Stream Deck versions, Intel/Windows, clean macOS accounts, audio playback and physical dial operation were not tested in this installation run.

## Earlier installation evidence — 2026-09-24

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

The first installation completed at 15:46 JST; the revised package installation completed at 15:57 JST. Both use the same native executable payload.

The maintainer subsequently reported successful installation of both packed files on a second Mac. That Mac's chip, OS and Stream Deck versions, logs and playback results have not been provided.

The revised package identified above was resubmitted as version 0.4.2.0 on 2026-09-24. Maker Console confirmed the upload and displayed **Pending review**. The submitted release notes in `listing.json` describe the packaging change, the two-Mac installation results and the fact that the reviewer's failure remains unreproduced. This is not Marketplace approval. The newly Marketplace-processed revision has not yet been downloaded or installation-tested.

## Subsequent review status

The September 24 resubmission was rejected again with the same installation feedback. Technical details were requested by email on September 25 and September 30 (Japan time); as of October 5, only an automated acknowledgement had been received. On October 5, the same tested package was resubmitted with those follow-up details in the release notes. Maker Console confirmed **Pending review** for 0.4.2, dated October 5. No further binary changes or new compatibility results are claimed.

## What the permissions change establishes

The original CLI archive loses executable permissions. Extracting it with `ditto` and launching it directly fails with `Permission denied`. The revised package preserves permissions and passes `Tests/PackedPluginTests.py` without a post-extraction `chmod`.

However, Stream Deck 7.4.0 restored executable permissions when installing the original Marketplace download. The permission loss therefore does **not** establish the cause of the reviewer's installation failure. It is a packaging robustness improvement with an automated regression test.

## Remaining verification as of October 5 (superseded by the UUID diagnosis above)

- Obtain the reviewer's OS, CPU architecture, Stream Deck version and exact error, and distinguish an installation rejection from a plugin launch or app-connection problem.
- Reproduce the reported failure in the relevant supported environment before claiming it fixed.
- Download and verify the newly Marketplace-processed revision when available; the earlier DRM-processed original has already passed the first installation test above.

The advertised minimums remain macOS 14.4 on Apple Silicon and Stream Deck 6.9. This run does not verify those minimum versions, Intel or Windows support, a clean macOS user account, audio playback, or physical dial operation. Existing profiles were not edited during these installation tests.
