import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taktaktv/presentation/auth/screens/login_screen.dart';
import 'package:taktaktv/presentation/navigation/main_navigation.dart';
import 'package:taktaktv/presentation/onboarding/screens/language_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // 3 Seconds Linear Progress Animation setup
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller)
      ..addListener(() {
        setState(() {});
      });

    _controller.forward();

    // 3 seconds mudinthathum existing/new user check panni navigate seyyum
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    try {
      // 3 seconds wait seyyuthu
      await Future.delayed(const Duration(seconds: 3));

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (!mounted) return;

      if (token != null && token.isNotEmpty) {
        // Existing User -> Homepage
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MainNavigationShell(token: token)),
        );
      } else {
        // New User -> Language / Login screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) =>const LoginScreen()),
        );
      }
    } catch (e) {
      // Ethavathu error irunthal app freeze aagama login flow-ku redirect seyyalam
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) =>const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0710), // Dark background match
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Badges (STREAM ENGINE ACTIVE & ULTRA-4K)
              SizedBox(
                height: 100,
              ),

              // Center Logo & Branding (Matching Image Exact Look)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10)
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(40),
                      child: Image.asset("assets/images/taktak_tv_logo.png",height: 100,width: 100,),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // taktaktv Text Logo
                  const Text(
                    'taktakTV',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),

              // Bottom Linear Progress Indicator with Color Gradient look
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE6007A), Colors.amber, Colors.greenAccent],
                        ),
                      ),
                      child: LinearProgressIndicator(
                        value: _animation.value,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.transparent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}