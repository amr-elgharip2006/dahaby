/// Sliding-window rate limiter kept in memory, keyed by caller (IP address).
class RateLimiter {
  RateLimiter(
      {required this.limit, required this.window, DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final int limit;
  final Duration window;
  final DateTime Function() _now;
  final _hits = <String, List<DateTime>>{};

  /// Records a hit for [key]. Returns false when the caller is over the limit.
  bool allow(String key) {
    final now = _now();
    final cutoff = now.subtract(window);
    final hits = _hits.putIfAbsent(key, () => [])
      ..removeWhere((t) => t.isBefore(cutoff));
    if (hits.length >= limit) return false;
    hits.add(now);
    if (_hits.length > 10000) _hits.removeWhere((_, v) => v.isEmpty);
    return true;
  }
}
