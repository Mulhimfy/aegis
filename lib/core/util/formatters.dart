/// Human phrasings used across the app. Kept in one place so "3 days ago"
/// never appears next to "3d" on another screen.
abstract final class Say {
  /// A relative time that reads like speech: "just now", "2 hours ago".
  static String ago(DateTime then, DateTime now) {
    final delta = now.difference(then);
    if (delta.inSeconds < 90) return 'just now';
    if (delta.inMinutes < 60) {
      return '${delta.inMinutes} ${_p(delta.inMinutes, "minute")} ago';
    }
    if (delta.inHours < 24) {
      return '${delta.inHours} ${_p(delta.inHours, "hour")} ago';
    }
    if (delta.inDays == 1) return 'yesterday';
    if (delta.inDays < 30) return '${delta.inDays} days ago';
    final months = (delta.inDays / 30).floor();
    if (months < 12) return '$months ${_p(months, "month")} ago';
    final years = (delta.inDays / 365).floor();
    return '$years ${_p(years, "year")} ago';
  }

  /// How to name a moment in a list. Recent entries get a relative phrase,
  /// because several checks run on the same afternoon are otherwise four rows
  /// that all say the same date.
  static String when(DateTime then, DateTime now) =>
      now.difference(then).inDays < 7 ? ago(then, now) : date(then);

  /// A calendar date: "12 Aug 2026".
  static String date(DateTime when) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${when.day} ${months[when.month - 1]} ${when.year}';
  }

  static String count(int n, String noun, [String? plural]) =>
      '$n ${n == 1 ? noun : (plural ?? "${noun}s")}';

  /// A span of time in the largest unit that still reads naturally.
  ///
  /// Screen timeouts in particular are stored in milliseconds and "never" is
  /// stored as a value near the 32-bit maximum, which is why this returns null
  /// past a day rather than reporting nine hundred hours.
  static String? span(Duration duration) {
    if (duration.inSeconds < 60) return '${duration.inSeconds} seconds';
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes} ${_p(duration.inMinutes, "minute")}';
    }
    if (duration.inHours < 24) {
      return '${duration.inHours} ${_p(duration.inHours, "hour")}';
    }
    return null;
  }

  static String _p(int n, String noun) => n == 1 ? noun : '${noun}s';
}
