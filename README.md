# Job Tracker

A Flutter (Android) app that tracks job listings from company career pages
and notifies you about new jobs.

## Features
- Add companies by career-page link; edit, mute or remove them
- Job cards with search, sorting, favourites and swipe actions
- Reads Greenhouse, Lever, Ashby, Workday, Phenom pages and generic pages
- Background checks with notifications and keyword alerts
- Settings: sync frequency, notification frequency, keywords, reset

## Run it
    flutter pub get
    flutter run

## Limits
- Pages that load jobs only with JavaScript cannot be read
- LinkedIn and Google Jobs are not used (their terms forbid scraping)
- Workday support uses an unofficial endpoint

## Built with
Flutter, http, html, shared_preferences, url_launcher, workmanager,
flutter_local_notifications, permission_handler