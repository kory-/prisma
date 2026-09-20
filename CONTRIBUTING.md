# Contributing

Bug reports and focused pull requests are welcome. Use English or Japanese.

For a bug, include macOS and Prisma versions, your output device, reproduction steps, and expected/actual behavior. Remove private tab titles, credentials and unrelated information from attachments.

For changes, explain the user-visible problem and run the relevant checks in [Development](docs/development.md). Audio changes need the native logic tests; Chrome changes need the JavaScript tests; UI/language changes need the localization checks. Describe hardware scenarios you could not test.

Keep the main app native and usable without optional integrations. Preserve Japanese and English strings, existing preferences and audio restoration behavior. Avoid unrelated formatting changes and do not commit build products or signing material.
