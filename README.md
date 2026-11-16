# Eintelix Expense Tracker

Offline-first Flutter expense manager for Eintelix Innovations Limited.

Current stack:
- Flutter UI with onboarding and splash flow
- Hive local persistence for categories, transactions, budgets, and settings
- Dashboard, analytics, budgets, category management, and transaction ledger

Cloud-ready phase:
- Optional Supabase auth + sync layer for shared multi-device access
- Hive remains the offline cache on each device
- Login, sign-up, sign-out, and manual sync status are wired into the app

## Supabase setup

1. Create a Supabase project.
2. Run the SQL in `supabase/schema.sql`.
3. In Supabase, enable Realtime/replication for:
   - `expense_categories`
   - `expense_entries`
   - `budget_plans`
   - `debt_records`
   - `user_settings`
4. Start the app with:

```bash
flutter run \
  --dart-define=SUPABASE_URL=YOUR_SUPABASE_URL \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_SUPABASE_PUBLISHABLE_KEY
```

If those `dart-define` values are omitted, the app stays in local-only Hive mode.

## Password reset

- The sign-in screen now sends Supabase password reset emails.
- Web requests return to the current origin with `?mode=recovery`. Mobile requests return to the installed app using `com.eintelix.expensetracker://login-callback?mode=recovery` and open only its password-reset screen.
- In Supabase Auth URL Configuration, allow `com.eintelix.expensetracker://login-callback?mode=recovery` and the web recovery URL for your deployment. Keep the Site URL set to the hosted app URL.
- Mobile recovery links require the app to be installed on the device where the email link is opened. Desktop browsers cannot open this mobile scheme without an installed handler.
- Recovery email requests use a separate implicit-flow client so opening the link in another browser or device does not require the requesting app's PKCE verifier. Google sign-in retains its existing flow.
- After changing the redirect configuration or rebuilding the app, request a fresh reset email; previously sent links retain their original redirect.

## Google sign-in

- The auth screen now supports Google OAuth through Supabase.
- This uses one Google flow for both sign-in and sign-up. If the Google account is new, Supabase creates the user on first login.

Setup:

1. In Google Cloud Console, create an OAuth client for `Web application`.
2. Add your app origins as Authorized JavaScript origins:
   - `http://localhost:3000` if you test locally on web
   - your Vercel production URL, for example `https://expense-manager-ei-team2.vercel.app`
3. In the same Google OAuth client, add the Supabase callback URL as an Authorized redirect URI:
   - `https://wurjhwzphfomuasdjunf.supabase.co/auth/v1/callback`
4. Copy the Google OAuth client ID and client secret.
5. In Supabase:
   - go to `Authentication -> Providers -> Google`
   - enable Google
   - paste the client ID into `Client IDs`
   - paste the client secret into `Client Secret (for OAuth)`
   - save
6. In `Authentication -> URL Configuration`, keep your frontend URL in:
   - `Site URL`
   - `Redirect URLs`

Notes:

- On Supabase, Google sign-up is the same flow as Google sign-in. There is no separate Google sign-up button required.
- On web, this app redirects back to the current site origin after Google auth.

## Deployment shape

- Flutter web frontend: Vercel
- Auth + database + sync: Supabase
- Mobile apps: same Flutter codebase, same Supabase project

## Vercel deployment

This repo now includes:

- [vercel.json](vercel.json)
- [scripts/vercel-build.sh](scripts/vercel-build.sh)

Vercel setup:

1. Import this repository into Vercel.
2. In Project Settings, leave the framework preset as `Other`.
3. Add these environment variables in Vercel:
   - `SUPABASE_URL`
   - `SUPABASE_PUBLISHABLE_KEY`
4. Deploy. Vercel will run the repo build script, install Flutter inside the build container, and publish `build/web`.

Note:
- This app stores category icons as dynamic code points, so the Vercel web build intentionally uses `--no-tree-shake-icons`.

Recommended values for this project right now:

- `SUPABASE_URL=https://wurjhwzphfomuasdjunf.supabase.co`
- `SUPABASE_PUBLISHABLE_KEY=sb_publishable_TO1v8l9Qa78NH4kQ3ZDXEw_C87Qy2zF`

If you use password reset on web, make sure Supabase Auth URL configuration includes your Vercel domain in both:

- `Site URL`
- `Redirect URLs`
# expense-manager

## Google Play release

The first Android release is `1.0.0+1` (`com.eintelix.expensetracker`), targeting API 36.
See [the release pack](store/google-play/README.md) for signing backup instructions,
store assets, listing copy, Data Safety notes and the device acceptance checklist.
Preview the [six screenshots and feature graphic](store/google-play/preview.html).
The upload keystore and its passwords are private local files excluded from Git.

Public policy pages live in `web/privacy/` and `web/delete-account/`; deploy them
with the web app before submitting their URLs to Play Console.
