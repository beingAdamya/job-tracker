class AppInfo {
  static const String appName = 'Job Tracker';
  static const String developer = 'ADAMYA';

  // From your repository address: github.com/OWNER/REPO (must be PUBLIC)
  static const String githubOwner = 'beingAdamya';
  static const String githubRepo = 'job-tracker';

  // Where bug reports are emailed. Leave '' to hide the email option.
  static const String bugEmail = '';

  // false until you replace the placeholder above
  static bool get hasRepo =>
      githubOwner.isNotEmpty && githubOwner != 'beingAdamya';
}