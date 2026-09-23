import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taktaktv/presentation/watchlater/screens/watch_later_manager.dart';
import '../../../core/constants/app_constant.dart';
import 'package:taktaktv/presentation/player/screens/player_screen.dart';

// WatchLaterManager placeholder/import reference (ungaloda project structure-ku etha maathiri irukkum)
// Neenga munbu create senja manager class inga work aagum.

class WatchLaterScreen extends StatefulWidget {
  final String token;
  const WatchLaterScreen({super.key, required this.token});

  @override
  State<WatchLaterScreen> createState() => _WatchLaterScreenState();
}

class _WatchLaterScreenState extends State<WatchLaterScreen> {
  List savedDramas = [];
  bool isLoading = true;
  late String activeToken; // Token storage variable

  @override
  void initState() {
    super.initState();
    activeToken = widget.token;
    _initializeAndFetch();

    // Listen to global changes instantly without changing UI layout
    WatchLaterManager().globalRefreshNotifier.addListener(_onWatchLaterChanged);
  }

  @override
  void dispose() {
    WatchLaterManager().globalRefreshNotifier.removeListener(_onWatchLaterChanged);
    super.dispose();
  }

  void _onWatchLaterChanged() {
    // Instantly re-fetch or refresh saved list when a series is saved/unsaved anywhere
    fetchSavedDramas();
  }

  // Token empty-ah iruntha local storage-la irunthu edukkum
  Future<void> _initializeAndFetch() async {
    if (activeToken.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      activeToken = prefs.getString('token') ?? prefs.getString('auth_token') ?? '';
    }
    fetchSavedDramas();
  }

  Future<void> fetchSavedDramas() async {
    try {
      final headers = activeToken.isNotEmpty
          ? {'Authorization': 'Bearer $activeToken'}
          : <String, String>{};

      // Correct Endpoint from your list
      final res = await http.get(
        Uri.parse('${AppConstants.baseUrl}/users/me/following'),
        headers: headers,
      );

      debugPrint("Watch Later Response Status: ${res.statusCode}");
      debugPrint("Watch Later Response Body: ${res.body}");

      if (res.statusCode == 200) {
        final decodedData = json.decode(res.body);

        // Backend response data structure-ai direct-ah handle panrathu
        if (mounted) {
          setState(() {

            if (decodedData is Map && decodedData.containsKey('data')) {
              savedDramas = decodedData['data'] ?? [];
            } else if (decodedData is List) {
              savedDramas = decodedData;
            } else {
              savedDramas = [];
            }
            isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching watch later: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> playDrama(String dramaId, String title) async {
    try {
      final headers = activeToken.isNotEmpty
          ? {'Authorization': 'Bearer $activeToken'}
          : <String, String>{};

      final res = await http.get(
        Uri.parse('${AppConstants.baseUrl}/dramas/$dramaId/episodes/1/play'),
        headers: headers,
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final streamUrl = data['data']['streamUrl'] ?? '';

        if (streamUrl.isNotEmpty && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlayerScreen(
                streamUrl: streamUrl,
                title: title,
                dramaId: dramaId,
                initialEpisode: 1,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Play error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0710),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Watch Later',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: isLoading
          ? const Center(
        child: CircularProgressIndicator(color: Color(0xFFE6007A)),
      )
          : savedDramas.isEmpty
          ? const Center(
        child: Text(
          'No saved dramas found!',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: savedDramas.length,
        itemBuilder: (context, index) {
          final drama = savedDramas[index];
          final dramaId = drama['_id'] ?? drama['id'] ?? '';
          final title = drama['title'] ?? '';
          final coverUrl = drama['coverUrl'] ?? '';
          final totalEpisodes = drama['totalEpisodes'] ?? 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(8),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  coverUrl,
                  width: 50,
                  height: 70,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 50,
                    height: 70,
                    color: Colors.grey,
                    child: const Icon(Icons.movie, color: Colors.white),
                  ),
                ),
              ),
              title: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  "Total Episodes: $totalEpisodes",
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
              trailing: const Icon(
                Icons.play_circle_fill,
                color: Color(0xFFE6007A),
                size: 36,
              ),
              onTap: () => playDrama(dramaId, title),
            ),
          );
        },
      ),
    );
  }
}