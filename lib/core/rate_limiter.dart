import 'dart:collection';

class RateLimiter {
  final int maxRequests;
  final Duration window;
  final Queue<DateTime> _timestamps = Queue();

  RateLimiter({this.maxRequests = 3, Duration? window}) : window = window ?? const Duration(minutes: 1);

  bool get isLimited => _clean() >= maxRequests;

  int remainingSeconds() {
    _clean();
    if (_timestamps.length < maxRequests) return 0;
    final first = _timestamps.first;
    final next = first.add(window);
    final diff = next.difference(DateTime.now());
    return diff.inSeconds > 0 ? diff.inSeconds : 0;
  }

  bool tryConsume() {
    _clean();
    if (_timestamps.length >= maxRequests) return false;
    _timestamps.addLast(DateTime.now());
    return true;
  }

  int _clean() {
    final now = DateTime.now();
    while (_timestamps.isNotEmpty && now.difference(_timestamps.first) > window) {
      _timestamps.removeFirst();
    }
    return _timestamps.length;
  }
}
