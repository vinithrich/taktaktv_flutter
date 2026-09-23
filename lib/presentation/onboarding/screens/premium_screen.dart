import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:taktaktv/presentation/navigation/main_navigation.dart';
import 'package:taktaktv/presentation/subscriptions/screens/subcription_paywall_screen.dart';
import '../../../core/constants/app_constant.dart';

class PremiumScreen extends StatefulWidget {
  final String token;
  const PremiumScreen({super.key, required this.token});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  final ScrollController _scrollController1 = ScrollController();
  final ScrollController _scrollController2 = ScrollController();
  final ScrollController _scrollController3 = ScrollController();
  Timer? _timer;

  // API la irunthu varura image URLs-ah store panna list
  List<String> _bannerImages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDramasForBackground();
    _startAutoScroll();
  }

  // 1. API la irunthuramas coverUrls-ah fetch panra method
  Future<void> _fetchDramasForBackground() async {
    try {
      final response = await http.get(Uri.parse('${AppConstants.baseUrl}/dramas?limit=20'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List dramas = data['data'] ?? [];

        List<String> urls = [];
        for (var drama in dramas) {
          if (drama['coverUrl'] != null) {
            urls.add(drama['coverUrl']);
          }
        }

        if (urls.isNotEmpty && mounted) {
          setState(() {
            _bannerImages = urls;
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint("Error fetching background dramas: $e");
    }

    // Fallback images (API work aagalana error varamal iruka default images)
    if (mounted) {
      setState(() {
        _bannerImages = [
          'https://cdn.syln.dev/posters/reelshort_6a469b12.jpg',
          'https://cdn.syln.dev/posters/reelshort_6a8bafb4.jpg',
        ];
        _isLoading = false;
      });
    }
  }

  // 2. Smooth Auto Scroll Timer
  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (_scrollController1.hasClients) {
        double max1 = _scrollController1.position.maxScrollExtent;
        double curr1 = _scrollController1.offset;
        _scrollController1.jumpTo(curr1 >= max1 ? 0 : curr1 + 1.0);
      }
      if (_scrollController2.hasClients) {
        double max2 = _scrollController2.position.maxScrollExtent;
        double curr2 = _scrollController2.offset;
        _scrollController2.jumpTo(curr2 >= max2 ? 0 : curr2 + 1.0);
      }
      if (_scrollController3.hasClients) {
        double max3 = _scrollController3.position.maxScrollExtent;
        double curr3 = _scrollController3.offset;
        _scrollController3.jumpTo(curr3 >= max3 ? 0 : curr3 + 1.0);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController1.dispose();
    _scrollController2.dispose();
    _scrollController3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0710),
      body: Stack(
        children: [
          // Background Auto-Scrolling Images from API
          if (!_isLoading && _bannerImages.isNotEmpty)
            Opacity(
              opacity: 0.9,
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  // Row 1
                  SizedBox(
                    height: 170,
                    child: ListView.builder(
                      controller: _scrollController1,
                      scrollDirection: Axis.horizontal,
                      itemCount: 100,
                      itemBuilder: (context, index) {
                        final imgUrl = _bannerImages[index % _bannerImages.length];
                        return Container(
                          width: 120,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(
                              image: NetworkImage(imgUrl),
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 15),
                  // Row 2
                  SizedBox(
                    height: 170,
                    child: ListView.builder(
                      controller: _scrollController2,
                      scrollDirection: Axis.horizontal,
                      itemCount: 100,
                      itemBuilder: (context, index) {
                        final imgUrl = _bannerImages[(index + 2) % _bannerImages.length];
                        return Container(
                          width: 120,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(
                              image: NetworkImage(imgUrl),
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 15),
                  // Row 3
                  SizedBox(
                    height: 170,
                    child: ListView.builder(
                      controller: _scrollController3,
                      scrollDirection: Axis.horizontal,
                      itemCount: 100,
                      itemBuilder: (context, index) {
                        final imgUrl = _bannerImages[(index + 4) % _bannerImages.length];
                        return Container(
                          width: 120,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(
                              image: NetworkImage(imgUrl),
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          // Dark Gradient Overlay to make foreground clear
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0B0710).withOpacity(0.85),
                  const Color(0xFF0B0710).withOpacity(0.95),
                  const Color(0xFF0B0710),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Foreground UI Content & Buttons
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const MainNavigationShell(token: '')),
                          );
                        },
                        child: const Text('Skip', style: TextStyle(color: Colors.grey, fontSize: 16)),
                      )
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const Text(
                        'Enjoy TakTak TV for FREE',
                        style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '5 Crore+ people bought the trial offer till now!',
                        style: TextStyle(color: Colors.greenAccent, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE6007A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          ),
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const SubscriptionPaywallScreen(token: '')),
                            );
                          },
                          child: const Text('Start Trial ->', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {},
                        child: const Text('Restore Purchase', style: TextStyle(color: Colors.grey, decoration: TextDecoration.underline)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}