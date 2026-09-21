# Marketplace submission materials

These are **submission materials**, not evidence of an approved/published listing.

`listing.json` contains the proposed free listing, description, release notes and support links. The public maker organization name must match the manifest author before submission. Prisma's current distribution is an ad-hoc-signed GitHub preview without Apple notarization. The listing must disclose that status; Marketplace acceptance has not been established.

- Plugin 0.4.2.0 uses SDK 3 and requires Stream Deck 6.9 or later for Marketplace DRM processing. Its native executable does not read the manifest or modify bundled files. The GitHub 0.7.0 preview plugin remains unchanged.
- App icon: 288 × 288 PNG.
- Thumbnail and three gallery images: 1920 × 960 PNG.
- Gallery images use Prisma's real `dial-layout.json` with labeled sample assignments. They do not show a user's browsing activity or impersonate photos of Elgato hardware.
- Regenerate with `Release/make-media.command` from an Apple Silicon Mac with Command Line Tools.

Before requesting review, verify installation and real playback using the exact app and plugin package to be submitted, including the experience on a Mac where they have not previously been approved. In Maker Console: create a Stream Deck plugin, upload the tested package, set the listing to Free, add these images and links, and enable automatic publication after approval. Disclose the app's signing status and any required first-launch steps. If Elgato requires Developer ID signing or notarization during review, resolve that requirement before claiming the package is ready for Marketplace. Review feedback still needs to be addressed; submission alone does not complete publication.

Evidence of completion must include the Maker product/version ID, Approved or Published status, and a publicly accessible Marketplace product page for the submitted UUID/version. If a demonstration video is requested, record the actual working integration; do not substitute a simulated demo.

References: [submission requirements](https://docs.elgato.com/maker-console/submitting-products/) and [image guidelines](https://docs.elgato.com/guidelines/products/).
