import 'package:flutter/foundation.dart';

class WatchLaterManager {
  static final WatchLaterManager _instance = WatchLaterManager._internal();
  factory WatchLaterManager() => _instance;
  WatchLaterManager._internal();

  // Listeners map for specific dramaId status changes
  final ValueNotifier<bool> globalRefreshNotifier = ValueNotifier<bool>(false);

  // DramaId-ku thaniyaana state tracking
  final Map<String, ValueNotifier<bool>> _dramaNotifiers = {};

  ValueNotifier<bool> getNotifier(String dramaId, bool initialValue) {
    if (!_dramaNotifiers.containsKey(dramaId)) {
      _dramaNotifiers[dramaId] = ValueNotifier<bool>(initialValue);
    } else {
      _dramaNotifiers[dramaId]!.value = initialValue;
    }
    return _dramaNotifiers[dramaId]!;
  }

  void updateStatus(String dramaId, bool isSaved) {
    if (_dramaNotifiers.containsKey(dramaId)) {
      _dramaNotifiers[dramaId]!.value = isSaved;
    }
    globalRefreshNotifier.value = !globalRefreshNotifier.value;
  }
}