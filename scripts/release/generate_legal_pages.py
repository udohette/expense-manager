#!/usr/bin/env python3
"""Export public legal pages from the in-app privacy text."""
import html
from pathlib import Path
import re
root = Path(__file__).resolve().parents[2]
source = (root/'lib/src/features/legal/privacy_screen.dart').read_text()
sections = re.findall(r"\(\s*'([^']+)',\s*'((?:\\.|[^'\\])*)',?\s*\)", source)
if len(sections) != 7:
    raise SystemExit('Privacy content format changed; inspect before regenerating.')
style = '''body{font:17px/1.7 system-ui,sans-serif;color:#182b43;background:#f3f6fb;margin:0}main{max-width:760px;margin:48px auto;padding:36px;background:white;border:1px solid #dce4ee;border-radius:24px}h1{font-size:34px;line-height:1.2;color:#233d61}h2{font-size:23px;margin-top:32px}a{color:#254d85;overflow-wrap:anywhere}.tag{font-size:13px;letter-spacing:.08em;color:#526984}nav{border-top:1px solid #dce4ee;padding-top:20px;margin-top:32px}.button{display:inline-block;background:#233d61;color:white;padding:12px 20px;border-radius:12px;text-decoration:none}@media(max-width:640px){main{margin:16px;padding:24px}}'''
def page(title, body):
    return f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="description" content="{html.escape(title)} for Eintelix Expense Tracker by Eintelix Innovations Limited"><title>{html.escape(title)} | Eintelix Expense Tracker</title><style>{style}</style></head><body><main><div class="tag">EINTELIX EXPENSE TRACKER</div><h1>{html.escape(title)}</h1>{body}<nav><a href="/privacy/">Privacy policy</a> · <a href="/delete-account/">Account deletion</a> · <a href="/">Open web app</a></nav></main></body></html>'''
body = ''.join(f'<section><h2>{html.escape(h)}</h2><p>{html.escape(t)}</p></section>' for h,t in sections)
body += '<p>Privacy questions: <a href="mailto:etteinnovations@gmail.com">etteinnovations@gmail.com</a></p>'
(root/'web/privacy/index.html').write_text(page('Privacy policy',body))
deletion = '''<p>You can request deletion of your Eintelix Expense Tracker account and its associated cloud data, even if you no longer have the app installed.</p>
<h2>Delete inside the app</h2><ol><li>Open Eintelix Expense Tracker and sign in.</li><li>Open <strong>Settings</strong>.</li><li>Choose <strong>Delete account permanently</strong> and confirm the permanent deletion.</li></ol>
<h2>Request deletion without the app</h2><p>Email <a href="mailto:etteinnovations@gmail.com?subject=Eintelix%20Expense%20Tracker%20account%20deletion">etteinnovations@gmail.com</a> from the email address associated with your account. Use the subject <strong>Eintelix Expense Tracker account deletion</strong>. Tell us that you want your account and associated data deleted.</p>
<p><a class="button" href="mailto:etteinnovations@gmail.com?subject=Eintelix%20Expense%20Tracker%20account%20deletion&amp;body=Please%20delete%20my%20Eintelix%20Expense%20Tracker%20account%20and%20its%20associated%20data.%20My%20account%20email%20is%3A%20">Email a deletion request</a></p>
<p>If the button does not open an email app, copy the address and send the request using your email provider. We may need to verify account ownership before acting. Never include a password, authentication token, or recovery link.</p>
<h2>What is deleted</h2><p>Deletion removes the authentication account and associated synced records, including transactions, budgets, bills, savings goals, wallets, debts, categories, and settings. Data deletion alone is also available in the app if you want to keep your account.</p>
<h2>Local records and retention</h2><p>Deleting the cloud account does not remotely erase files or cached records from other devices. Remove local records on those devices or uninstall the app. Provider backups and records required for legal or security purposes may be retained under provider retention policies and applicable obligations. Contact support for details about your request.</p>
<p>Provider: Eintelix Innovations Limited. Contact: <a href="mailto:etteinnovations@gmail.com">etteinnovations@gmail.com</a>.</p>'''
(root/'web/delete-account/index.html').write_text(page('Request account deletion',deletion))
print('Generated web/privacy/index.html and web/delete-account/index.html')
