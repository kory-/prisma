# Marketplace submission materials

These are **submission materials**, not evidence of an approved/published listing.

`listing.json` contains the proposed free listing, description, release notes and support links. The public maker organization name must match the manifest author before submission. Use the final Developer ID-signed plugin package, not an earlier ad-hoc preview.

- App icon: 288 × 288 PNG.
- Thumbnail and three gallery images: 1920 × 960 PNG.
- Gallery images use Prisma's real `dial-layout.json` with labeled sample assignments. They do not show a user's browsing activity or impersonate photos of Elgato hardware.
- Regenerate with `Release/make-media.command` from an Apple Silicon Mac with Command Line Tools.

Before requesting review, verify the final app's notarization, installation and real playback with the signed plugin. In Maker Console: create a Stream Deck plugin, upload the signed package, set the listing to Free, add these images and links, and enable automatic publication after approval. Review feedback still needs to be addressed; submission alone does not complete publication.

Evidence of completion must include the Maker product/version ID, Approved or Published status, and a publicly accessible Marketplace product page for the submitted UUID/version. If a demonstration video is requested, record the actual working integration; do not substitute a simulated demo.

References: [submission requirements](https://docs.elgato.com/maker-console/submitting-products/) and [image guidelines](https://docs.elgato.com/guidelines/products/).
