# Job Fit

Paste a job description and get a clear answer: **apply or not**.

Job Fit compares a job ad with my CV, like an ATS check. It shows a match score, a verdict, the skills that match or are missing, tips to adapt my CV, and a ready-to-copy cover letter. It can also find open jobs that fit me, and it keeps a small application tracker.

**Live demo:** https://abir739.github.io/job-fit/

<p align="center">
  <img src="docs/screenshots/home.png" width="19%" alt="Paste a job description; history below">
  <img src="docs/screenshots/result.png" width="19%" alt="Match score and verdict">
  <img src="docs/screenshots/skills.png" width="19%" alt="CV tips and matched / partial skills">
  <img src="docs/screenshots/cover-letter.png" width="19%" alt="Generated cover letter with copy button">
  <img src="docs/screenshots/find-jobs.png" width="19%" alt="Find jobs: open ads to evaluate in one tap">
</p>

## Features

- **Match score and verdict:** a 0–100% score and APPLY / APPLY WITH CAUTION / SKIP, plus the reasons and any blockers (seniority, location, visa…).
- **Skills breakdown:** matched, partly matched and missing skills, each with the evidence from the CV.
- **CV tips:** concrete keywords and experience to highlight for this specific job.
- **Cover letter:** a short cover letter written from real CV facts only, with one-tap copy.
- **Find jobs:** searches open job ads (optionally by country or "remote"), keeps the ones that fit my rules, and explains why. One tap evaluates an ad with its full text.
- **History and tracker:** every evaluated job is saved, and synced between phone and computer. Mark each one Saved, Applied, Interview, Rejected or Offer, filter by status, or delete it. Evaluating the same job twice returns the saved result.

## How it works

```
Flutter web app ──► Supabase Edge Function ──► Gemini API
      ▲                     │      └─────────► JSearch API (job ads)
      │                     ▼
 score + verdict      Postgres (history)
 (pure Dart rules)
```

- **The AI only extracts facts.** It returns structured JSON (requirements, match level, blockers) that follows a strict schema.
- **The decision is plain code.** The score and verdict are computed in pure Dart with fixed rules, so the same facts always give the same answer, and the rules are unit tested.
- **Private data stays on the server.** The CV and the evaluation rules live in a locked database table that only the Edge Function can read. The AI key is a server secret, never shipped to the browser.
- **Resilient AI calls.** If a model fails, the next one is tried at once; if it is just slow, a second model is started in parallel and the first answer wins (a "hedged request").
- **Job search in two steps.** A job API returns real, open ads; the AI then ranks them against my rules. The AI never invents postings or links.

## Tech stack

| Part | Tech |
|---|---|
| App (web, works on phone) | Flutter 3, Dart, Riverpod 3 |
| Backend | Supabase Edge Function (Deno, TypeScript), Postgres with Row Level Security |
| AI | Google Gemini, structured JSON output, behind a provider interface |
| Job search | JSearch API (RapidAPI), ranked by Gemini |
| Tests | `flutter_test`, widget tests, `MockClient` for HTTP |
| CI/CD | GitHub Actions: analyze, test, build, deploy to GitHub Pages |

## Project structure

```
lib/
  scoring/        score and verdict rules (pure Dart)
  ai/             analyzer interface, Edge Function client, fake for tests
  evaluation/     Riverpod controller
  history/        saved jobs and application status
  cover_letter/   cover letter client
  search/         job search client
  ui/             pages and widgets
supabase/
  functions/analyze-job/   Edge Function
  setup.sql                tables and permissions
test/             unit and widget tests
```

## Run locally

```bash
flutter pub get
flutter test
flutter run -d chrome          # runs with fake sample data, no server needed
```

To use a real backend, pass `--dart-define=SUPABASE_URL=...` and `--dart-define=JOB_FUNCTION=...`.

## License

Copyright (c) 2026 Abir Cherif. All rights reserved. The code is public to view as part of my portfolio; it may not be copied, reused or presented as someone else's work without my permission. See [LICENSE](LICENSE).
