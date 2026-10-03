STUDYFLOW CLOUD — SETUP

Goal:
Use the SAME StudyFlow account on iPhone and MacBook and see the SAME study records.

FILES TO PUT IN YOUR GITHUB PAGES REPOSITORY
- index.html
- config.js
- manifest.webmanifest
- sw.js
- icon-192.png
- icon-512.png

STEP 1 — Create a Supabase project
Create a free Supabase project.

STEP 2 — Create the database
In Supabase:
SQL Editor → New query
Open the included file: supabase_setup.sql
Copy everything → paste into SQL Editor → Run.

This creates:
- subjects table
- sessions table
- security rules (RLS)
- Start / Break / Resume / Stop database functions
- realtime support

STEP 3 — Put Supabase connection values in config.js
Find your:
- Project URL
- Publishable key (or legacy anon key)

Open config.js and replace:
PASTE_YOUR_SUPABASE_PROJECT_URL_HERE
PASTE_YOUR_SUPABASE_PUBLISHABLE_OR_ANON_KEY_HERE

IMPORTANT:
The Publishable/anon key is intended for browser apps when RLS is enabled.
NEVER put a secret key or service_role key in config.js or GitHub.

STEP 4 — Set the Auth redirect URL
In Supabase Authentication URL settings, set the Site URL / allowed redirect URL to your GitHub Pages StudyFlow URL.

STEP 5 — Upload to GitHub Pages
Replace your current StudyFlow website files with the files from this folder.
Commit/push them.
Open the same GitHub Pages URL on iPhone and MacBook.

FIRST USE
1. Create one StudyFlow account with email + password.
2. Sign in with the SAME account on iPhone and MacBook.
3. Your data now syncs through Supabase.

OLD PHONE DATA
If your updated website uses the SAME GitHub Pages domain/origin as the old version,
StudyFlow will detect the old localStorage data on that device.
On the iPhone, log in and tap:
"Import old data"
Do this once on the device that contains the old records.
Then the imported data will appear on your MacBook too.

IPHONE HOME SCREEN
Safari → open your GitHub Pages StudyFlow link → Share → Add to Home Screen.

HOW THE TIMER WORKS
- Start: cloud session begins.
- Break: study timer stops; break timer runs.
- Resume: study timer continues.
- Stop & Save: session becomes completed.
- Timing transitions are calculated in the Supabase database, so switching devices does not reset the session.
- Weekly goals are MINIMUM goals, not limits. If you study more, the extra time is still shown.

EMAIL CONFIRMATION
If Supabase requires email confirmation, confirm the first signup email once.
If you prefer instant signup, you can adjust email confirmation in Supabase Authentication settings.

SECURITY
Each account can only read/write its own records because Row Level Security (RLS) is enabled.
