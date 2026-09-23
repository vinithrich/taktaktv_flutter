import 'package:flutter/foundation.dart';

class WatchLaterManager {
  static final WatchLaterManager _instance = WatchLaterManager._internal();
  factory WatchLaterManager() => _instance;
  WatchLaterManager._internal();

  // Global refresh notifier to sync Watch Later screen instantly
  final ValueNotifier<bool> globalRefreshNotifier = ValueNotifier<bool>(false);

  void updateStatus(String dramaId, bool isSaved) {
    globalRefreshNotifier.value = !globalRefreshNotifier.value;
  }
}