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
- For Flutter web, the app uses the current site origin as the recovery redirect.
- In Supabase Auth settings, set your Site URL and allowed redirect URLs to the URL where this app runs, so the recovery link can return to the app and open the password reset screen.

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
