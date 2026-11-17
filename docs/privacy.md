# APP-011 — Privacy & security

- **Data**: goal names, desired amounts, household name, savings movements, plans, habits/checklists and optional notes. User-entered names and financial amounts can be personal.
- **Storage**: `flutter_secure_storage`, Android encrypted shared preferences / operating system protected keychain on supported devices. The app does not create user accounts or transmit this data.
- **Export**: requires explicit in-app confirmation and invokes native sharing with a **plaintext JSON** document. The user should select a secure destination; exporting is not encrypted end-to-end by the app.
- **Import**: explicit confirmation before replacement; validates product tag, schema version, IDs, reference integrity and balance invariants. Malformed imports leave stored records unchanged.
- **Deletion**: confirmation, then secure storage key removal before clearing in-memory model. Deletion is subject to platform/device backups outside the app's control.
- **Crash/telemetry**: no analytics SDK, remote error reporting, location permissions or advertising identifiers in source.
- **Misleading behavior avoidance**: recurring plans never move money; financial coaching is deterministic and not investment advice. No actual user-to-user marketplace/chat/AI API is implemented.
- **Backup risk**: encrypted local storage is different from exported plaintext. Sharing a backup may expose personal financial data.
- **Store declarations**: require verification against final native builds and any future third-party SDKs. Review encryption, backup and Data Safety policies before publication.
