# Release candidate status — 16 November 2026

## Completed

- `1.0.0+1`, package `com.eintelix.expensetracker`, target/compile API 36, minimum API 24.
- Private RSA upload key generated, Git-ignored, permissions 0600; signed AAB verified.
- Bundletool validation, APK signature and 16 KB ZIP alignment passed. All eight 64-bit libraries passed ELF LOAD-segment alignment checks. Bundle config is `PAGE_ALIGNMENT_16K`.
- Final merged permissions: INTERNET and the app-specific non-exported-receiver permission. No SMS, contacts, advertising-ID or notification permission.
- Flutter analysis: no issues. Five focused recovery tests passed. Six-screen capture test passed without widget exceptions. Web build passed; both public HTML files are included and match their sources.
- Seven 1080×1920 RGB phone screenshots (bank-SMS import first), 512×512 icon, 1024×500 feature graphic, listing text and release notes generated and visually reviewed. Listing lengths: 24 / 67 / 1570 characters for name / short / full descriptions.
- An earlier signed candidate installed and cold-launched on Android 16. A token-less recovery deep link opened the native invalid-link screen and returned to sign in. The final adaptive-icon sizing change was rebuilt and artifact-verified; reinstall timed out on the slow emulator. No warm-link or live recovery claim is made.

## Tablet assets

- Added seven 7-inch tablet viewport captures (1080×1920 portrait) and seven 10-inch tablet viewport captures (1920×1080 landscape), bank-SMS import first in each folder.
- Both tablet widget-capture runs passed without widget exceptions. Each PNG is RGB and below 8 MB. Screenshots were visually inspected; physical-tablet/runtime acceptance remains pending.

## Before Play review

- Back up `android/key.properties` AND `android/keystore/upload-keystore.jks` privately. Neither is in the distributable ZIP.
- Deploy and verify the privacy and deletion pages on the existing web domain. They are prepared locally; not published by this task.
- Validate production Supabase auth, RLS, sync and account-deletion RPC using disposable accounts. Confirm service-provider retention and the privacy/Data Safety wording.
- Provide dedicated reviewer credentials in Play Console App access, finish declarations and content rating, and upload the AAB to internal testing with Play App Signing enabled.
- Run the physical-device matrix in README.md, including real emailed reset links on closed/open app, Google sign-in, offline sync and deletion. Inspect the Play pre-launch report and device compatibility.
- Complete any account-specific closed-test and developer-verification requirements. Nothing has been uploaded or published to Google Play.
