import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/constants/app_constant.dart';
import 'package:taktaktv/presentation/home/screens/search_screen.dart';
import 'package:taktaktv/presentation/player/screens/player_screen.dart';
import 'package:visibility_detector/visibility_detector.dart';

class DramaModel {
  final String id;
  final String title;
  final String coverUrl;
  final int? episodeNumber;
  final int? positionSeconds;
  final int? durationSeconds;
  final double? progressPercentage;

  DramaModel({
    required this.id,
    required this.title,
    required this.coverUrl,
    this.episodeNumber,
    this.positionSeconds,
    this.durationSeconds,
    this.progressPercentage,
  });

  factory DramaModel.fromJson(Map<String, dynamic> json) {
    // Backend continue watching response-il 'drama' nested-aaga varugirathu
    final Map<String, dynamic> dramaData = json['drama'] is Map<String, dynamic>
        ? json['drama']
        : (json['dramaId'] is Map<String, dynamic> ? json['dramaId'] : json);

    return DramaModel(
      id: (dramaData['id'] ?? dramaData['_id'] ?? json['dramaId'] ?? '').toString(),
      title: dramaData['title'] ?? json['title'] ?? '',
      coverUrl: dramaData['coverUrl'] ?? dramaData['posterUrl'] ?? dramaData['imageUrl'] ?? '',
      episodeNumber: json['episodeNumber'] ?? json['currentEpisode'] ?? dramaData['episodeNumber'],
      positionSeconds: json['positionSeconds'] ?? json['position'] ?? dramaData['positionSeconds'],
      durationSeconds: json['durationSeconds'] ?? json['duration'] ?? dramaData['durationSeconds'],
      progressPercentage: json['progressPercentage'] != null
          ? (json['progressPercentage'] as num).toDouble()
          : (dramaData['progressPercentage'] != null ? (dramaData['progressPercentage'] as num).toDouble() : null),
    );
  }
}

class BannerModel {
  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String targetDramaId;
  final String ctaText;

  BannerModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.targetDramaId,
    required this.ctaText,
  });

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    return BannerModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      imageUrl: json['imageUrl'] ?? json['coverUrl'] ?? '',
      targetDramaId: json['targetDramaId'] ?? json['actionTarget'] ?? '',
      ctaText: json['ctaText'] ?? 'Watch Now',
    );
  }
}

class HomeScreen extends StatefulWidget {
  final String token;
  const HomeScreen({super.key, required this.token});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<BannerModel> banners = [];
  List sections = [];
  bool isLoading = true;
  bool _isFetching = false;
  int _currentBannerIndex = 0;
  String? selectedDramaId;

  @override
  void initState() {
    super.initState();
    debugPrint("DEBUG_TOKEN: HomeScreen initialized with token -> ${widget.token.isNotEmpty ? 'Available (${widget.token.substring(0, 10)}...' : 'EMPTY/MISSING'}");
    fetchHomeFeedWithHistory();
  }

  Future<void> fetchHomeFeedWithHistory() async {
    if (_isFetching) return;
    _isFetching = true;

    try {
      if (sections.isEmpty) {
        setState(() => isLoading = true);
      }

      final headers = widget.token.isNotEmpty
          ? {'Authorization': 'Bearer ${widget.token}', 'Content-Type': 'application/json'}
          : <String, String>{};

      debugPrint("DEBUG_API: Fetching home feed and history...");

      // 1. Home Feed Endpoint with individual catchError
      final homeFuture = http
          .get(Uri.parse(AppConstants.homeEndpoint), headers: headers)
          .timeout(const Duration(seconds: 15))
          .catchError((_) => http.Response('', 408)); // Timeout or error-ku empty response

      // 2. Continue Watching Endpoint with individual catchError
      final historyEndpoint = '${AppConstants.baseUrl}/playback/continue';
      final historyFuture = http
          .get(Uri.parse(historyEndpoint), headers: headers)
          .timeout(const Duration(seconds: 15))
          .catchError((_) => http.Response('', 408));

      // Ippo rendu futures-um parallel-a run aagum, ethu fail aanalum mattathu kidaikkum
      final responses = await Future.wait([homeFuture, historyFuture]);

      final homeRes = responses[0];
      final historyRes = responses[1];

      List rawSections = [];

      // Process Home Feed Response (Critical)
      if (homeRes.statusCode == 200) {
        try {
          final resJson = json.decode(homeRes.body);
          final data = resJson['data'];
          rawSections = (data != null && data['sections'] != null)
              ? List.from(data['sections'])
              : [];

          if (data != null && data['banners'] != null) {
            banners = (data['banners'] as List)
                .map((e) => BannerModel.fromJson(e))
                .toList();
          }
        } catch (e) {
          debugPrint("DEBUG_API: Home JSON parse error -> $e");
        }
      }

      // Process Continue Watching Response (Optional / Non-critical)
      if (historyRes.statusCode == 200) {
        try {
          final historyJson = json.decode(historyRes.body);
          dynamic historyData = historyJson['data'] ?? historyJson['history'] ?? historyJson;

          if (historyData is Map) {
            historyData = historyData['items'] ?? historyData['list'] ?? historyData['history'];
          }

          if (historyData is List && historyData.isNotEmpty) {
            final continueWatchingSection = {
              'title': 'Continue Watching',
              'items': historyData,
            };
            rawSections.insert(0, continueWatchingSection);
          }
        } catch (e) {
          debugPrint("DEBUG_API: History JSON parse error -> $e");
        }
      }

      if (mounted) {
        setState(() {
          sections = rawSections;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("DEBUG_API: Critical fetch error -> $e");
      if (mounted) setState(() => isLoading = false);
    } finally {
      _isFetching = false;
    }
  }

  Future<void> playDrama(
      String dramaId,
      String title, {
        int? episodeNumber,
        int? positionSeconds,
      }) async {
    if (dramaId.isEmpty || selectedDramaId != null) return;

    setState(() {
      selectedDramaId = dramaId;
    });

    int targetEp = episodeNumber ?? 1;

    try {
      final headers = widget.token.isNotEmpty
          ? {'Authorization': 'Bearer ${widget.token}'}
          : <String, String>{};

      final res = await http.get(
        Uri.parse('${AppConstants.baseUrl}/dramas/$dramaId/episodes/$targetEp/play'),
        headers: headers,
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final streamUrl = data['data']['streamUrl'] ?? '';

        if (streamUrl.isNotEmpty && mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlayerScreen(
                streamUrl: streamUrl,
                title: title,
                dramaId: dramaId,
                initialEpisode: targetEp,
                initialPosition: positionSeconds != null
                    ? Duration(seconds: positionSeconds)
                    : Duration.zero,
              ),
            ),
          );

          fetchHomeFeedWithHistory();
        }
      }
    } catch (e) {
      debugPrint("Home play error: $e");
    } finally {
      if (mounted) {
        setState(() {
          selectedDramaId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: const Key('home-screen-visibility'),
      onVisibilityChanged: (visibilityInfo) {
        if (visibilityInfo.visibleFraction > 0.8) {
          fetchHomeFeedWithHistory();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0710),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'TakTak TV',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white, size: 26),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                );
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: isLoading
            ? const Center(
          child: CircularProgressIndicator(color: Color(0xFFE6007A)),
        )
            : SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banners Section
              if (banners.isNotEmpty) ...[
                SizedBox(
                  height: 340,
                  child: PageView.builder(
                    itemCount: banners.length,
                    onPageChanged: (index) =>
                        setState(() => _currentBannerIndex = index),
                    itemBuilder: (context, index) {
                      final banner = banners[index];
                      final bool isThisBannerLoading =
                          selectedDramaId == banner.targetDramaId;

                      return GestureDetector(
                        onTap: isThisBannerLoading
                            ? null
                            : () => playDrama(
                          banner.targetDramaId,
                          banner.title,
                        ),
                        child: Container(
                          margin:
                          const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            image: DecorationImage(
                              image: NetworkImage(banner.imageUrl),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.9)
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                                padding: const EdgeInsets.all(16),
                                alignment: Alignment.bottomLeft,
                                child: Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment:
                                  CrossAxisAlignment.end,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            banner.title,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow:
                                            TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            banner.subtitle,
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                        const Color(0xFFE6007A),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(20),
                                        ),
                                      ),
                                      onPressed: isThisBannerLoading
                                          ? null
                                          : () => playDrama(
                                        banner.targetDramaId,
                                        banner.title,
                                      ),
                                      child: isThisBannerLoading
                                          ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                          : Text(
                                        banner.ctaText,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight:
                                          FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(banners.length, (index) {
                    return Container(
                      width: _currentBannerIndex == index ? 16 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: _currentBannerIndex == index
                            ? Colors.white
                            : Colors.grey,
                      ),
                    );
                  }),
                ),
              ],

              const SizedBox(height: 20),

              // Sections List Loop
              ...sections.map((section) {
                final itemList =
                    (section['items'] ?? section['dramas'] as List?) ?? [];
                final String sectionTitle = section['title'] ?? '';

                final bool isContinueWatching =
                    sectionTitle.toLowerCase().contains('continue') ||
                        sectionTitle.toLowerCase().contains('watch') ||
                        sectionTitle.toLowerCase().contains('history');

                if (itemList.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Text(
                        sectionTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: isContinueWatching ? 230 : 210,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: itemList.length,
                        itemBuilder: (context, index) {
                          final drama =
                          DramaModel.fromJson(itemList[index]);
                          final bool isThisDramaLoading =
                              selectedDramaId == drama.id;

                          return GestureDetector(
                            onTap: isThisDramaLoading
                                ? null
                                : () => playDrama(
                              drama.id,
                              drama.title,
                              episodeNumber: drama.episodeNumber,
                              positionSeconds:
                              drama.positionSeconds,
                            ),
                            child: Container(
                              width: 130,
                              margin: const EdgeInsets.only(right: 12),
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                          BorderRadius.circular(12),
                                          child: Image.network(
                                            drama.coverUrl,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                Container(
                                                  color: Colors.grey[800],
                                                  child: const Icon(
                                                    Icons.movie,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                          ),
                                        ),

                                        // Continue Watching overlay with Episode & Progress bar
                                        if (isContinueWatching &&
                                            drama.episodeNumber != null)
                                          Positioned(
                                            bottom: 0,
                                            left: 0,
                                            right: 0,
                                            child: Container(
                                              padding:
                                              const EdgeInsets.symmetric(
                                                vertical: 4,
                                                horizontal: 8,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.black
                                                    .withOpacity(0.8),
                                                borderRadius:
                                                const BorderRadius.vertical(
                                                  bottom:
                                                  Radius.circular(12),
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                                mainAxisSize:
                                                MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    "Ep ${drama.episodeNumber}",
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                      fontWeight:
                                                      FontWeight.bold,
                                                    ),
                                                  ),
                                                  if (drama.progressPercentage !=
                                                      null) ...[
                                                    const SizedBox(
                                                        height: 3),
                                                    LinearProgressIndicator(
                                                      value: (drama.progressPercentage! /
                                                          100)
                                                          .clamp(
                                                          0.0, 1.0),
                                                      backgroundColor:
                                                      Colors.white24,
                                                      valueColor:
                                                      const AlwaysStoppedAnimation<
                                                          Color>(
                                                        Color(0xFFE6007A),
                                                      ),
                                                      minHeight: 3,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),

                                        if (isThisDramaLoading)
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius:
                                              BorderRadius.circular(12),
                                            ),
                                            child: const Center(
                                              child: SizedBox(
                                                width: 28,
                                                height: 28,
                                                child:
                                                CircularProgressIndicator(
                                                  color: Color(0xFFE6007A),
                                                  strokeWidth: 2.5,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    drama.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}