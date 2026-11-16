# Data Safety and app-content draft

Prepared from this checkout on 16 November 2026. The account owner must verify deployed Supabase practices, provider retention, and any changes before submitting. This is a declaration worksheet, not a completed Play Console submission.

| Question | Proposed answer and evidence |
| --- | --- |
| Does the app collect user data? | Yes. Signed-in records are sent to Supabase. Do not select “no data collected.” |
| Personal information | Email address and user ID for authentication/account management. Google sign-in may supply name/profile information. Debt records optionally contain counterpart names and phone numbers. |
| Financial information | Other financial info: income, expenses, budgets, debt/repayment records, wallet labels, savings goals, bills, amounts, and related notes/account hints. No card-payment processor or bank credentials are implemented. |
| Messages | SMS or MMS: users can voluntarily paste bank-alert messages; `raw_message` is stored and synced with transactions. No READ_SMS permission or automatic inbox access. Confirm the exact classification in the current console; include message text rather than omit it because it was pasted. |
| Other user-generated content | User notes, tags, category names and transaction descriptions are synced. |
| Contacts | No automatic address-book access. Manually entered third-party names/phone numbers can appear in debt records. Declare them under the applicable personal-information/contact category offered by the form. |
| Device identifiers / diagnostics / location | No dedicated analytics, advertising, crash reporting, device-ID collection, or location permission found in app code. Confirm Supabase/Google infrastructure logs and current SDK disclosures before answering definitively. |
| Purposes | App functionality and account management. No advertising or marketing SDK found. |
| Required vs optional | Email/user ID are required for the configured cloud account. Creating financial records, supplying counterpart details, pasting alerts, and Google sign-in are user choices. Keep answers consistent with the release's actual sign-in gate and UI. |
| Ephemeral processing | No for account and stored synced records. |
| Sharing | Supabase acts as the configured authentication/database service provider; Google handles optional Google sign-in. Apply Google's service-provider/user-initiated-transfer exceptions only after verifying contractual roles. Do not confuse “not shared” with “not collected.” |
| Encryption in transit | The app uses HTTPS/WSS Supabase endpoints and disallows Android cleartext traffic. Verify deployed endpoints and SDK behavior. Do not claim app-level encryption of local Hive files. |
| Deletion | In-app Settings → Delete all account data / Delete account permanently. Public deletion request page: `/delete-account/` with support email. Verify the live `delete_my_account` RPC and cloud-row cascade, support ownership checks, backups and retention before submission. |
| Ads | No ads SDK or ads UI in this release. |
| App access | Sign-in is required in the configured cloud build. Supply a dedicated working reviewer email/password in Play Console's protected App access form, not in this repository. Reviewers must be able to access all features without your personal account or time-limited email links. |
| Target audience | Proposed: adults (18+); this is not a children's finance app. Owner must confirm audience selections and complete the IARC content questionnaire truthfully. |
| Financial features | Complete the required declaration. This app provides budgeting and financial record management. Select the applicable personal-finance/budgeting/other category shown in the console. Do not select lending, money transfer, banking, investment execution, or cryptocurrency. Tracking a debt does not offer a loan. |
| Health / news / government / advertising ID | No such functionality or AD_ID permission found; verify the final merged manifest before submission. |

## Sources

- [Data Safety form](https://support.google.com/googleplay/android-developer/answer/10787469)
- [Account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111)
- [Financial features declaration](https://support.google.com/googleplay/android-developer/answer/13849271)

## Live evidence still required

- Deploy the public privacy and deletion pages and check anonymous access without signing in.
- Verify deletion using a disposable account, including auth removal, finance-row cascades, and local data cleanup; never use a real user's account.
- Test email sign-up/sign-in, Google OAuth, password recovery cold/warm app links, sync between devices and offline reconnection on a Play-installed release.
- Confirm production database row-level access rules isolate users and that backups/retention and support handling match the policy.
