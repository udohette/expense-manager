# Google Play release pack — Eintelix Expense Tracker

Prepared 16 November 2026. Package: `com.eintelix.expensetracker`. First release: `1.0.0` (version code `1`). Support: `etteinnovations@gmail.com`.

## Assets to upload

- `graphics/app-icon-512.png`: 512 × 512 RGB PNG.
- `graphics/feature-graphic-1024x500.png`: 1024 × 500 RGB PNG.
- `screenshots/00-bank-alert-import.png` first, followed by `01-overview.png` through `06-wallets.png`: seven 1080 × 1920 RGB phone screenshots, in numbered order.
- `listing/en-US.txt`: app name, short/full descriptions and contact details.
- `listing/release-notes-en-US.txt`: initial release notes.
- `preview.html` and `preview-grid.jpg`: local review gallery; not store-upload assets.
- `raw/`: underlying 1080 × 1920 app renders, without promotional framing. Screens use actual Android-themed Flutter widgets, real fonts and isolated fictional records. These are test-render captures, not photos of a physical phone or proof of device behavior. No real account data is included.
- `upload-certificate.pem`: PUBLIC upload-key certificate. It is safe to archive with this pack; it is not the private keystore.

Tablet assets are in separate upload folders:

- `tablet-7-inch/`: seven portrait PNGs, 1080 × 1920, rendered at a tablet layout width of 720 logical pixels.
- `tablet-10-inch/`: seven landscape PNGs, 1920 × 1080, rendered at a tablet layout width of 1280 logical pixels.
- In each folder, upload `00-bank-alert-import.png` first, followed by `01`–`06`. Only the numbered PNGs are upload assets; preview JPG/HTML files are for local review.

These are actual Flutter layout captures at tablet viewports, with fictional data; they are not resized phone screenshots. Widget capture checks do not establish physical-tablet behavior or Play's large-screen quality approval. TV, Wear OS and Chromebook-specific screenshots are not supplied. Preview assets follow [Google's asset specifications](https://support.google.com/googleplay/android-developer/answer/9866151).

## Signing and build

Private signing files were generated locally for this first release:

- `android/keystore/upload-keystore.jks`
- `android/key.properties`

Both are Git-ignored and mode 0600. Back up BOTH in encrypted storage or a password manager before uploading. Losing the properties loses the generated password. Never commit, email, or upload these files as store assets. The private key is an **upload key**; enable **Play App Signing** and let Play manage the distribution signing key. Do not run key generation again for updates.

Build: `flutter build appbundle --release`

To reproduce the artifact audit and internal test APK, download Google's [bundletool](https://github.com/google/bundletool/releases) and run:

```sh
python3 scripts/release/verify_bundle.py --bundletool /path/to/bundletool-all.jar
```

This verifies the bundle signature, package/version/SDK/permissions, ELF segment alignment, generated APK signature and 16 KB ZIP alignment. It writes an audit report and a universal test APK to `build/play-store/`. These are artifact checks; they do not replace testing on 16 KB-page-size devices. [Android page-size guidance](https://developer.android.com/guide/practices/page-sizes).

Bundle: `build/app/outputs/bundle/release/app-release.aab`

For updates increment `version`'s build number in `pubspec.yaml`. Keep the package ID and upload key. Target/compile SDK are 36; the release includes Internet access, blocks cleartext network traffic, and opts out of Android backup of local financial records. [Current target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878).

## Before submission

1. Create the Play Console app under the correct verified developer account. Choose the intended countries, pricing and distribution. The current app has no purchase or ad SDK.
2. Review the in-app policy and publish `web/privacy/index.html` and `web/delete-account/index.html` with your existing Vercel deployment. Flutter copies these static files during web builds. Verify these URLs publicly return the intended pages:
   - `https://expense-manager-ei-team2.vercel.app/privacy/`
   - `https://expense-manager-ei-team2.vercel.app/delete-account/`
3. Configure Supabase allowed redirects for mobile reset: `com.eintelix.expensetracker://login-callback?mode=recovery`; also keep the ordinary Google callback and web origins allowed. Test newly requested reset links on a phone with this release installed.
4. Verify the production schema, RLS isolation, realtime sync and `delete_my_account()` function in `supabase/schema.sql` are actually deployed. The local source and mock tests do not prove production setup.
5. Complete the Data Safety/app access/ads/audience/content-rating/financial-features forms. Start with `DATA_SAFETY_DRAFT.md`, confirm it against the backend, and provide dedicated working review credentials through Play Console's App access page. No credentials belong in this pack.
6. Upload the signed AAB to **Internal testing** first. Run the physical-device matrix below and inspect Play's pre-launch report, native-library/page-size compatibility, warnings and supported-device list.
7. If this is a personal developer account created after 13 November 2023, Google currently requires a closed test with at least 12 continuously opted-in testers for 14 days before applying for production access. Organization accounts follow their applicable console process. [Testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465).
8. Submit for production review only after live checks, store forms and URLs are complete. This preparation does not publish the app or establish Google approval.

## Physical-device acceptance matrix

- Fresh install, launch, navigation, large text/display sizes and Android back button.
- Email sign-up/confirmation, sign-in/sign-out and Google sign-in.
- New reset email → app closed → reset form → confirmation; repeat with app already open on Overview. Expired links stay out of the dashboard. Desktop cannot open a mobile-only custom URL scheme.
- Create/edit/delete income/expense; paste a fictional bank alert and confirm parsed details before saving; duplicate handling.
- Budget totals, savings contributions, debt repayments, bill dates, wallet balances and transfers.
- Offline data entry, reconnect and sync to a second signed-in device; ensure another user's data stays isolated.
- Settings privacy page, public privacy/deletion links; delete data and permanently delete a disposable account; verify cloud removal and local cleanup.
- Uninstall/reinstall and update via Play internal testing; inspect crash/ANR and pre-launch reports. A release build does not prove these outcomes.

## Reproduce assets

Install Pillow in your chosen Python environment, then run:

```sh
python3 scripts/release/generate_store_assets.py
python3 scripts/release/generate_legal_pages.py
python3 scripts/release/generate_tablet_assets.py
```

The first screenshot highlights pasted bank-SMS import with a fictional alert and its parsed preview; it does not imply automatic SMS-inbox access.

The screenshot capture creates and removes a temporary Hive database. It never signs in or modifies a user's data. Promotional framing and icon exports use the existing Eintelix mark. Validate screenshots visually after UI changes.
