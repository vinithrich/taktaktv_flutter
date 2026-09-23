class VideoQualityManager {
  static String selectedQuality = 'Auto'; // Default
  static Map<String, String> availableQualities = {};

  static void setQuality(String quality, String url) {
    selectedQuality = quality;
  }
}