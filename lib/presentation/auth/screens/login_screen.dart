import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/constants/app_constant.dart'; // Import constants
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late VideoPlayerController _controller;
  final TextEditingController _phoneController = TextEditingController();
  bool _isPhoneNumberValid = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse('https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4'),
    )..initialize().then((_) {
      _controller.setLooping(true);
      _controller.setVolume(0.0);
      _controller.play();
      setState(() {});
    });

    _phoneController.addListener(() {
      setState(() {
        _isPhoneNumberValid = _phoneController.text.length == 10;
      });
    });
  }

  Future<void> _sendOtp() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse(AppConstants.sendOtpEndpoint), // Using AppConstants here
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': _phoneController.text}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        String receivedOtp = data['data']['otp'] ?? '1234';

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpScreen(
              phoneNumber: _phoneController.text,
              devOtp: receivedOtp,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Failed to send OTP')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error. Check server connection.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          if (_controller.value.isInitialized)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0B0710).withOpacity(0.85),
                  const Color(0xFF0B0710).withOpacity(0.95),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 80),
                  const Text(
                    'TAKTAK TV',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('1 minute short dramas', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 48),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Enter your mobile number', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white)),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF140F1D).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE6007A), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Text('+91', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            cursorColor: const Color(0xFFE6007A),
                            maxLength: 10,
                            style: const TextStyle(fontSize: 16, color: Colors.white),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              counterText: '',
                              hintText: 'Your 10-digit Mobile Number',
                              hintStyle: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_isPhoneNumberValid && !_isLoading) ? _sendOtp : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: _isPhoneNumberValid
                              ? const LinearGradient(colors: [Color(0xFFE6007A), Color(0xFF9C27B0)])
                              : null,
                          color: _isPhoneNumberValid ? null : const Color(0xFF2C2537),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: _isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text(
                            'Get OTP',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _isPhoneNumberValid ? Colors.white : Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}