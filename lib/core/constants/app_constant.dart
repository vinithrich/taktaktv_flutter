class AppConstants {
  static const String baseUrl = 'https://taktak-backend-jtm9.onrender.com/api/v1';

  // Auth Endpoints
  static const String sendOtpEndpoint = '$baseUrl/auth/send-otp';
  static const String verifyOtpEndpoint = '$baseUrl/auth/verify-otp';
  static const String contentLanguages = '$baseUrl/content-languages';
  static const String updatePreferences = '$baseUrl/users/me/preferences';
  static const String subscriptionPlans = '$baseUrl/subscriptions/plans';
  static const String homeEndpoint = '$baseUrl/home';
  static const String searchEndpoint = '$baseUrl/search';
  static const String fcmTokenEndpoint = '$baseUrl/users/fcm-token';
  static const String resendOtpEndpoint = '$baseUrl/auth/resend-otp';
}