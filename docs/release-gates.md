# APP-011 release acceptance and evidence checklist

The repository is a substantial **source candidate**. Do not count as a final release until these gates pass. The `APP-011` reference is unique to this non-game savings application.

| Gate | Required proof | Current proof at source generation |
|---|---|---|
| Product function | Goal creation, deposits/withdrawals, goal deletion, household dashboard, recurring manual plans, 30-day habit checklist, offline academy, 20 feature entry points | Source implemented; requires automated & exploratory verification |
| Data integrity | write-first atomic changes, no negative savings on import, corrupt-data preservation, referential integrity, locale currency boundaries | Unit tests written; CI run pending |
| International | Turkish, English and Arabic, RTL and Arabic/Persian digit input | Source written; widget/device review pending |
| Privacy | encrypted storage, user export confirmation, backup restore, deletion, safe financial disclosures | Source written; device security review pending |
| Automated QA | `flutter analyze`, `flutter test`, Android APK | Workflow configured; run pending |
| Android release | signed AAB, SDK compatibility, app ID, store privacy/Data Safety, real device smoke | Not verified |
| iOS release | macOS/Xcode signed IPA, App Store Connect, device smoke, privacy labels | Not verified |
| Remote services | If planned: live API contracts, legal/consent, proper authentication, robust failure recovery | No remote services connected |
| Monetization | If planned: provider sandbox purchase flow, restore/cancel paths, actual ad SDK & consent | No actual paid IAP or ad provider connected |
| Store assets | production artwork, screenshots, legal policy URL, localization validation | Draft copy in `docs/store-listings.md`; approval pending |

**CI does not prove actual Android/iOS release readiness**. A job failure before any steps run typically indicates GitHub Actions runner/billing/permissions rather than a verified Dart compiler failure.

## Manual device acceptance scenarios

1. Install fresh app; confirm no network access needed; add TRY goal with Arabic/Persian formatted amount; force-close and reopen.
2. Deposit then withdraw; verify exact minor-unit balance, caps, stored history and no negative balances.
3. Create weekly/monthly plan; verify no movement until explicit confirmation; verify date advancement exactly once.
4. Create two different household-owner goals and 30-day challenge; complete and uncomplete tasks, restart and verify.
5. Export through native share after warning; restore verified backup; malformed and foreign-product backups must not overwrite data.
6. Delete all with confirmation; restart and verify no data. Simulate storage failure if possible.
7. Test RTL Arabic UI and large system text on narrow screen, keyboard navigation and screen reader labels.
8. Android release AAB and iOS IPA build/sign, test on actual devices, verify store policies and correct billing/consent setup if monetized.
