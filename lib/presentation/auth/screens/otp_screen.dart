import 'dart:async'; // <-- 1. Timer-kku ithu thevai
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:taktaktv/presentation/home/screens/home_screen.dart';
import 'package:taktaktv/presentation/navigation/main_navigation.dart';
import 'package:taktaktv/presentation/onboarding/screens/language_screen.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constant.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  final String devOtp;

  const OtpScreen({super.key, required this.phoneNumber, required this.devOtp});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  bool _isLoading = false;

  // --- TIMER VARIABLES ---
  Timer? _timer;
  int _start = 18; // 18 Seconds timer
  bool _isResendActive = false;

  @override
  void initState() {
    super.initState();
    debugPrint("Development OTP is: ${widget.devOtp}");
    startTimer(); // Screen open aanathume timer-ai start seyyungal
  }

  // Timer-ai start panra method
  void startTimer() {
    setState(() {
      _start = 18;
      _isResendActive = false;
    });

    _timer?.cancel(); // Mukkiyamaana step: Munbulla timer irunthal athai cancel seyyungal
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_start == 0) {
        setState(() {
          _isResendActive = true;
          timer.cancel();
        });
      } else {
        setState(() {
          _start--;
        });
      }
    });
  }

  // Resend OTP API call method (Ungaloda backend route-based url)
  Future<void> _resendOtp() async {
    if (!_isResendActive) return;

    try {
      setState(() => _isLoading = true);


      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/auth/resend-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.phoneNumber}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP resent successfully! 📩')),
        );
        startTimer(); // Timer-18 seconds-ku restart
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Failed to resend OTP')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error while resending OTP.')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Helper method to register FCM Token to Backend after successful login
  Future<void> _registerFcmToken(String token) async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      String? fcmToken = await messaging.getToken();
      if (fcmToken != null) {
        await http.post(
          Uri.parse(AppConstants.fcmTokenEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'fcmToken': fcmToken}),
        );
      }

      FirebaseMessaging.instance.onTokenRefresh.listen((newFcmToken) async {
        await http.post(
          Uri.parse(AppConstants.fcmTokenEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'fcmToken': newFcmToken}),
        );
      });
    } catch (e) {
      debugPrint("Error registering FCM token: $e");
    }
  }

  Future<void> _verifyOtp() async {
    String otpCode = _controllers.map((c) => c.text).join();
    if (otpCode.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid 4-digit OTP')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse(AppConstants.verifyOtpEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': widget.phoneNumber,
          'otp': otpCode,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        String token = data['data']['token'];
        bool isNewUser = data['data']['isNewUser'] ?? false;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        await prefs.setBool('is_new_user', isNewUser);

        await _registerFcmToken(token);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication Successful! 🎉')),
        );

        if (isNewUser) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => LanguageSelectionScreen(token: token)),
                (route) => false,
          );
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => MainNavigationShell(token: token)),
                (route) => false,
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Invalid OTP')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error during verification.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel(); // Memory leak avoid seya timer-ai dispose seyyungal
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0710),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Enter verification code',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Code sent to +91 ${widget.phoneNumber}',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(4, (index) {
                return SizedBox(
                  width: 60,
                  height: 60,
                  child: TextField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    cursorColor: const Color(0xFFE6007A),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: const Color(0xFF140F1D),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE6007A), width: 2),
                      ),
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty && index < 3) {
                        _focusNodes[index + 1].requestFocus();
                      } else if (value.isEmpty && index > 0) {
                        _focusNodes[index - 1].requestFocus();
                      }
                      if (_controllers.every((c) => c.text.isNotEmpty)) {
                        _verifyOtp();
                      }
                    },
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // --- TIMER AND RESEND OTP WIDGET ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isResendActive ? "Didn't receive code? " : "Resend code in ",
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                _isResendActive
                    ? GestureDetector(
                  onTap: _resendOtp,
                  child: const Text(
                    "Resend OTP",
                    style: TextStyle(
                      color: Color(0xFFE6007A),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                )
                    : Text(
                  "00:${_start.toString().padLeft(2, '0')}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFFE6007A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: _isLoading ? null : _verifyOtp,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Verify OTP', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}