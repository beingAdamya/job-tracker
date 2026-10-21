class AppInfo {
  static const String appName = 'Job Tracker';
  static const String developer = 'ADAMYA';

  // Your GitHub repository. It must be PUBLIC for the update check to work.
  static const String githubOwner = 'YOUR-GITHUB-USERNAME';
  static const String githubRepo = 'job-tracker';

  // Where bug reports are emailed. Leave '' to hide the email option.
  static const String bugEmail = 'beingadamya@gmail.com';

  // false until you replace the placeholder above
  static bool get hasRepo =>
      githubOwner.isNotEmpty && githubOwner != 'beingAdamya';
}