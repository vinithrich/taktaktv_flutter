import 'package:flutter/material.dart';
import 'package:taktaktv/presentation/explore/screens/explore_screen.dart';
import 'package:taktaktv/presentation/subscriptions/screens/subcription_paywall_screen.dart';
import 'package:taktaktv/presentation/watchlater/screens/watchLater.dart';
import '../../presentation/home/screens/home_screen.dart';
import '../../presentation/profile/screens/profile_screen.dart';

class MainNavigationShell extends StatefulWidget {
  final String token;
  const MainNavigationShell({super.key, required this.token});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  // Explore tab active-la irukkaa illaa nu track panna notifier
  late final ValueNotifier<bool> _isExploreActiveNotifier;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _isExploreActiveNotifier = ValueNotifier<bool>(_currentIndex == 1);

    _screens = [
      HomeScreen(token: widget.token),
      ExploreScreen(isExploreActive: _isExploreActiveNotifier),
      SubscriptionPaywallScreen(token: widget.token),
      WatchLaterScreen(token: widget.token),
      ProfileScreen(token: widget.token),

    ];
  }

  @override
  void dispose() {
    _isExploreActiveNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0710),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        backgroundColor: const Color(0xFF0B0710),
        selectedItemColor: const Color(0xFFE6007A),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            // Explore tab (index 1) irunthu vera ethukku ponalum false aagum
            _isExploreActiveNotifier.value = (_currentIndex == 1);
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explore'),
          BottomNavigationBarItem(icon: Icon(Icons.star), label: 'Trial Offer'),
          BottomNavigationBarItem(icon: Icon(Icons.save_alt),label: 'WatchLater'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),

        ],
      ),
    );
  }
}