# Job Tracker

A Flutter (Android) app that tracks job listings from company career pages
and notifies you about new jobs.

## Download
Get the latest APK from the
[Releases page](https://github.com/beingAdamya/job-tracker/releases/latest).

## Features
- Email sign-in with verification; data kept separately for each account
- Add companies by career-page link; edit, mute or remove them
- Job cards with search, sorting, favourites, swipe actions and pull to refresh
- Reads Greenhouse, Lever, Ashby, Workday, SmartRecruiters, Workable, job feeds,
  Phenom pages and generic career pages
- Background checks with notifications and keyword alerts
- Profile and CV with copy-to-clipboard fields
- Light, dark, system and custom themes; landscape support
- Marks jobs as no longer available; update check; bug report

## Limits
- Pages that load jobs only with JavaScript, need a login, or block apps cannot be read
- LinkedIn and Google Jobs are not used (their terms forbid scraping)
- Workday support uses an unofficial endpoint
- Data is stored on the phone only (no cloud backup)
- Background timing is controlled by Android and may be delayed by phone makers
- Phone or WhatsApp verification is not included

## Run it
    flutter pub get
    flutter run

## Built with
Flutter, Firebase Authentication, http, html, xml, shared_preferences,
url_launcher, workmanager, flutter_local_notifications, permission_handler,
file_picker, open_filex