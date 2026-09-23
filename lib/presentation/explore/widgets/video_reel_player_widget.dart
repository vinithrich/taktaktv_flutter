import 'package:flutter/material.dart';
import 'package:taktaktv/presentation/subscriptions/screens/subcription_paywall_screen.dart';
import 'package:taktaktv/presentation/watchlater/screens/watch_later_manager.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constant.dart';
import '../../player/screens/player_screen.dart';
import 'package:visibility_detector/visibility_detector.dart';

// Subtitle Item Model for Parsing SRT
class SubtitleItem {
  final Duration start;
  final Duration end;
  final String text;

  SubtitleItem({required this.start, required this.end, required this.text});
}

class VideoReelPlayerWidget extends StatefulWidget {
  final String dramaId;
  final String title;
  final ValueNotifier<bool> isExploreActive;
  final ValueChanged<bool>? onSaveStatusChanged; // Added to sync with Watch Later page instantly

  const VideoReelPlayerWidget({
    super.key,
    required this.dramaId,
    required this.title,
    required this.isExploreActive,
    this.onSaveStatusChanged,
  });

  @override
  State<VideoReelPlayerWidget> createState() => _VideoReelPlayerWidgetState();
}

class _VideoReelPlayerWidgetState extends State<VideoReelPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  String streamUrl = "";
  int totalEpisodes = 50;

  // Save / Bookmark variables
  bool isSaved = false;
  bool isCheckingSaveStatus = true;
  bool isSavingAction = false;

  // Dynamic play details from backend
  List<dynamic> qualities = [];
  List<dynamic> subtitles = [];
  List<dynamic> audioLanguages = [];
  String selectedQuality = "Auto";
  String selectedAudioLang = "";
  String selectedSubtitleLabel = "No Subtitles";

  // Subtitle Parsing & Display Variables
  List<SubtitleItem> parsedSubtitles = [];
  String currentSubtitleText = "";

  // Controls visibility toggle & timer for 2 seconds auto-hide
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    debugPrint("🎬 [VideoReelPlayerWidget] initState called for dramaId: ${widget.dramaId}, title: ${widget.title}");
    widget.isExploreActive.addListener(_onExploreActiveChanged);
    fetchStreamAndDetails();
    _checkIfDramaIsSaved();
  }

  @override
  void dispose() {
    debugPrint("🛑 [VideoReelPlayerWidget] dispose called for dramaId: ${widget.dramaId}");
    _hideTimer?.cancel();
    widget.isExploreActive.removeListener(_onExploreActiveChanged);
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
  }

  // Check if drama is already saved using GET /api/v1/dramas/:dramaId
  Future<void> _checkIfDramaIsSaved() async {
    debugPrint("🔍 [WatchLater Debug] Checking save status for dramaId: ${widget.dramaId}");
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? prefs.getString('auth_token') ?? '';
      debugPrint("🔑 [WatchLater Debug] Token found for check status: ${token.isNotEmpty ? "YES (Length: ${token.length})" : "NO TOKEN FOUND"}");

      final headers = token.isNotEmpty
          ? {'Authorization': 'Bearer $token'}
          : <String, String>{};

      final targetUrl = '${AppConstants.baseUrl}/dramas/${widget.dramaId}';
      debugPrint("🌐 [WatchLater Debug] GET Endpoint: $targetUrl");

      final res = await http.get(
        Uri.parse(targetUrl),
        headers: headers,
      );

      debugPrint("📥 [WatchLater Debug] Check Status Response Code: ${res.statusCode}");
      debugPrint("📥 [WatchLater Debug] Check Status Body: ${res.body}");

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final dramaData = data['data'];
        if (dramaData != null && mounted) {
          final serverIsFollowing = dramaData['isFollowing'] ?? dramaData['isSaved'] ?? dramaData['isBookmarked'] ?? false;
          debugPrint("✅ [WatchLater Debug] Parsed isSaved/isFollowing from server: $serverIsFollowing");
          setState(() {
            isSaved = serverIsFollowing;
            isCheckingSaveStatus = false;
          });
        }
      } else {
        debugPrint("⚠️ [WatchLater Debug] Failed to check save status. Status code != 200");
        if (mounted) setState(() => isCheckingSaveStatus = false);
      }
    } catch (e) {
      debugPrint("❌ [WatchLater Debug] Error checking save status: $e");
      if (mounted) setState(() => isCheckingSaveStatus = false);
    }
  }

  // Toggle Save / Unsave (Watch Later)
  Future<void> _toggleSaveDrama() async {
    debugPrint("🔄 [WatchLater Debug] _toggleSaveDrama triggered. Current isSaved state: $isSaved");
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? prefs.getString('auth_token') ?? '';

      if (token.isEmpty) {
        debugPrint("❌ [WatchLater Debug] Toggle failed: User token is empty (Not logged in)");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please login to save dramas to Watch Later')),
          );
        }
        return;
      }

      final headers = {'Authorization': 'Bearer $token'};
      final url = Uri.parse('${AppConstants.baseUrl}/dramas/${widget.dramaId}/follow');

      http.Response res;
      if (isSaved) {
        debugPrint("🗑️ [WatchLater Debug] Sending DELETE request to: $url");
        res = await http.delete(url, headers: headers);
      } else {
        debugPrint("➕ [WatchLater Debug] Sending POST request to: $url");
        res = await http.post(url, headers: headers);
      }

      debugPrint("📥 [WatchLater Debug] Toggle Response Code: ${res.statusCode}");
      debugPrint("📥 [WatchLater Debug] Toggle Response Body: ${res.body}");

      // Inside _toggleSaveDrama in VideoReelPlayerWidget
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = json.decode(res.body);
        final responseData = data['data'];

        setState(() {
          if (responseData is Map) {
            isSaved = responseData['isFollowing'] ??
                responseData['isSaved'] ??
                responseData['isBookmarked'] ??
                !isSaved;
          } else {
            isSaved = !isSaved;
          }
        });

        // --- INSTANT SYNC NOTIFIER ADDED HERE ---
        WatchLaterManager().updateStatus(widget.dramaId, isSaved);

        if (widget.onSaveStatusChanged != null) {
          widget.onSaveStatusChanged!(isSaved);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isSaved ? 'Added to Watch Later' : 'Removed from Watch Later'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else {
        debugPrint("❌ [WatchLater Debug] Failed to toggle save/follow. Server returned status: ${res.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ [WatchLater Debug] Toggle save exception: $e");
    }
  }

  void _onExploreActiveChanged() {
    debugPrint("👁️ [VideoReelPlayer] exploreActive changed: ${widget.isExploreActive.value}");
    if (!widget.isExploreActive.value) {
      if (_controller != null && _controller!.value.isInitialized) {
        if (_controller!.value.isPlaying) {
          _controller!.pause();
          if (mounted) setState(() {});
        }
      }
    }
  }

  void _videoListener() {
    if (mounted) {
      setState(() {
        if (_controller != null && _controller!.value.isInitialized) {
          final currentPosition = _controller!.value.position;
          currentSubtitleText = _getSubtitleForPosition(currentPosition);
        }
      });
    }
  }

  String _getSubtitleForPosition(Duration position) {
    for (var sub in parsedSubtitles) {
      if (position >= sub.start && position <= sub.end) {
        return sub.text;
      }
    }
    return "";
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && _controller != null && _controller!.value.isPlaying) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _seekForward() {
    if (_controller != null && _controller!.value.isInitialized) {
      final currentPos = _controller!.value.position;
      final targetPos = currentPos + const Duration(seconds: 10);
      final duration = _controller!.value.duration;

      if (targetPos < duration) {
        _controller!.seekTo(targetPos);
      } else {
        _controller!.seekTo(duration);
      }
      _startHideTimer();
    }
  }

  void _seekBackward() {
    if (_controller != null && _controller!.value.isInitialized) {
      final currentPos = _controller!.value.position;
      final targetPos = currentPos - const Duration(seconds: 10);

      if (targetPos > Duration.zero) {
        _controller!.seekTo(targetPos);
      } else {
        _controller!.seekTo(Duration.zero);
      }
      _startHideTimer();
    }
  }

  Future<void> fetchStreamAndDetails() async {
    debugPrint("📥 [Stream API] Fetching stream and details for dramaId: ${widget.dramaId}");
    try {
      final dramaRes = await http.get(Uri.parse('${AppConstants.baseUrl}/dramas/${widget.dramaId}'));
      debugPrint("📥 [Stream API] Drama details status: ${dramaRes.statusCode}");
      if (dramaRes.statusCode == 200) {
        final dramaData = json.decode(dramaRes.body);
        final dataNode = dramaData['data'];
        if (dataNode != null) {
          setState(() {
            totalEpisodes = dataNode['totalEpisodes'] ?? 50;
            String singleLang = dataNode['language'] ?? 'English';
            audioLanguages = dataNode['languages'] ?? [singleLang];
            if (audioLanguages.isNotEmpty && selectedAudioLang.isEmpty) {
              selectedAudioLang = singleLang;
            }
          });
        }
      }

      final playApi = '${AppConstants.baseUrl}/dramas/${widget.dramaId}/episodes/1/play';
      debugPrint("📥 [Stream API] Play Endpoint: $playApi");
      final res = await http.get(Uri.parse(playApi));
      debugPrint("📥 [Stream API] Play Response status: ${res.statusCode}");
      debugPrint("📥 [Stream API] Play Response body: ${res.body}");

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final playData = data['data'];
        if (playData != null) {
          streamUrl = playData['streamUrl'] ?? '';
          qualities = playData['qualities'] ?? [];
          subtitles = playData['subtitles'] ?? [];

          debugPrint("🎬 [Stream API] Parsed streamUrl: $streamUrl");

          if (streamUrl.isNotEmpty) {
            _initializePlayer(streamUrl);
          }
        }
      }
    } catch (e) {
      debugPrint("❌ [Stream API] Reel play/details error: $e");
    }
  }

  void _initializePlayer(String url) {
    debugPrint("▶️ [VideoPlayer] Initializing video controller with URL: $url");
    _controller?.dispose();
    _controller = VideoPlayerController.networkUrl(Uri.parse(url))
      ..addListener(_videoListener)
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _isInitialized = true);
          debugPrint("✅ [VideoPlayer] Video initialized successfully");
          if (widget.isExploreActive.value) {
            _controller?.play();
          }
          _controller?.setLooping(true);
          _startHideTimer();
        }
      }).catchError((error) {
        debugPrint("❌ [VideoPlayer] Error initializing video controller: $error");
      });
  }

  void _changeQuality(String qualityLabel, String url) {
    debugPrint("⚙️ [Quality] Changing quality to $qualityLabel with url: $url");
    setState(() {
      selectedQuality = qualityLabel;
    });
    final position = _controller?.value.position ?? Duration.zero;
    _controller?.pause();
    _initializePlayer(url);
    Future.delayed(const Duration(milliseconds: 500), () {
      _controller?.seekTo(position);
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "${duration.inHours > 0 ? '${twoDigits(duration.inHours)}:' : ''}$minutes:$seconds";
  }

  void _showOptionsBottomSheet(BuildContext context) {
    _hideTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF140F1D),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(16),
              height: MediaQuery.of(context).size.height * 0.55,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Video Settings & Subtitles", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(color: Colors.grey),
                    const SizedBox(height: 8),
                    const Text("Quality", style: TextStyle(color: Color(0xFFE6007A), fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: qualities.map((q) {
                        final label = q['label'] ?? '';
                        final isSel = selectedQuality == label;
                        return ChoiceChip(
                          label: Text(label),
                          selected: isSel,
                          selectedColor: const Color(0xFFE6007A),
                          backgroundColor: const Color(0xFF1E172B),
                          labelStyle: TextStyle(color: isSel ? Colors.white : Colors.grey),
                          onSelected: (val) {
                            setModalState(() => selectedQuality = label);
                            _changeQuality(label, q['url']);
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      if (_controller != null && _controller!.value.isPlaying) _startHideTimer();
    });
  }

  void _showEpisodesBottomSheet(BuildContext context) {
    debugPrint("📱 [BottomSheet] Opening Episodes Bottom Sheet for dramaId: ${widget.dramaId}");
    _hideTimer?.cancel();
    _controller?.pause();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF140F1D),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return EpisodesBottomSheet(
          dramaId: widget.dramaId,
          dramaTitle: widget.title,
          totalEpisodes: totalEpisodes,
        );
      },
    ).then((_) {
      debugPrint("📱 [BottomSheet] Closed Episodes Bottom Sheet");
      if (mounted && widget.isExploreActive.value) {
        _controller?.play();
        _startHideTimer();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final position = _controller != null && _controller!.value.isInitialized ? _controller!.value.position : Duration.zero;
    final duration = _controller != null && _controller!.value.isInitialized ? _controller!.value.duration : Duration.zero;

    return VisibilityDetector(
      key: Key(widget.dramaId),
      onVisibilityChanged: (visibilityInfo) {
        if (!widget.isExploreActive.value) return;

        var visiblePercentage = visibilityInfo.visibleFraction * 100;
        if (_controller != null && _controller!.value.isInitialized) {
          if (visiblePercentage < 50) {
            if (_controller!.value.isPlaying) {
              _controller!.pause();
              setState(() {});
            }
          } else {
            if (!_controller!.value.isPlaying) {
              _controller!.play();
              setState(() {});
            }
          }
        }
      },
      child: Stack(
        children: [
          Center(
            child: _isInitialized && _controller != null
                ? SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              ),
            )
                : Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFFE6007A)),
              ),
            ),
          ),

          if (currentSubtitleText.isNotEmpty)
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    currentSubtitleText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _toggleControls,
                  onDoubleTap: _seekBackward,
                  child: const SizedBox.expand(),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _toggleControls,
                  onDoubleTap: _seekForward,
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),

          AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: IgnorePointer(
              ignoring: !_showControls,
              child: Stack(
                children: [
                  if (_isInitialized && _controller != null && !_controller!.value.isPlaying)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.play_arrow, color: Colors.white, size: 48),
                      ),
                    ),

                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),

                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.replay_10, color: Colors.white70, size: 36),
                          onPressed: _seekBackward,
                        ),
                        const SizedBox(width: 20),
                        IconButton(
                          icon: Icon(
                            _controller != null && _controller!.value.isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
                            color: Colors.white,
                            size: 48,
                          ),
                          onPressed: () {
                            setState(() {
                              if (_controller != null && _controller!.value.isInitialized) {
                                if (_controller!.value.isPlaying) {
                                  _controller!.pause();
                                } else {
                                  _controller!.play();
                                }
                              }
                            });
                            _startHideTimer();
                          },
                        ),
                        const SizedBox(width: 20),
                        IconButton(
                          icon: const Icon(Icons.forward_10, color: Colors.white70, size: 36),
                          onPressed: _seekForward,
                        ),
                      ],
                    ),
                  ),

                  // Right Side Actions Panel
                  Positioned(
                    right: 16,
                    bottom: 80,
                    child: Column(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 28),
                          onPressed: () => _showOptionsBottomSheet(context),
                        ),
                        const Text('Settings', style: TextStyle(color: Colors.white, fontSize: 10)),
                        const SizedBox(height: 16),

                        IconButton(
                          icon: Icon(
                            isSaved ? Icons.bookmark : Icons.bookmark_border,
                            color: isSaved ? const Color(0xFFE6007A) : Colors.white,
                            size: 28,
                          ),
                          onPressed: _toggleSaveDrama,
                        ),
                        Text(isSaved ? 'Saved' : 'Save', style: const TextStyle(color: Colors.white, fontSize: 10)),
                        const SizedBox(height: 16),

                        IconButton(
                          icon: const Icon(Icons.list_alt_rounded, color: Colors.white, size: 28),
                          onPressed: () => _showEpisodesBottomSheet(context),
                        ),
                        const Text('Episodes', style: TextStyle(color: Colors.white, fontSize: 10)),
                      ],
                    ),
                  ),

                  Positioned(
                    left: 16,
                    right: 80,
                    bottom: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => _showEpisodesBottomSheet(context),
                              child: const Row(
                                children: [
                                  Icon(Icons.play_circle_fill, color: Color(0xFFE6007A), size: 16),
                                  SizedBox(width: 4),
                                  Text('Watch Now ►', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Text(
                              "${_formatDuration(position)} / ${_formatDuration(duration)}",
                              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (_controller != null && _controller!.value.isInitialized)
                          VideoProgressIndicator(
                            _controller!,
                            allowScrubbing: true,
                            colors: const VideoProgressColors(
                              playedColor: Color(0xFFE6007A),
                              bufferedColor: Colors.white30,
                              backgroundColor: Colors.white12,
                            ),
                          ),
                      ],
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

// --- Episodes Bottom Sheet ---
class EpisodesBottomSheet extends StatefulWidget {
  final String dramaId;
  final String dramaTitle;
  final int totalEpisodes;

  const EpisodesBottomSheet({
    super.key,
    required this.dramaId,
    required this.dramaTitle,
    required this.totalEpisodes,
  });

  @override
  State<EpisodesBottomSheet> createState() => _EpisodesBottomSheetState();
}

class _EpisodesBottomSheetState extends State<EpisodesBottomSheet> {
  int selectedTabRange = 0;

  Future<void> playSelectedEpisode(int episodeNumber) async {
    debugPrint("🎬 [EpisodesBottomSheet] playSelectedEpisode called for Episode $episodeNumber (Drama ID: ${widget.dramaId})");

    if (episodeNumber > 5) {
      debugPrint("🔒 [EpisodesBottomSheet] Episode $episodeNumber is locked (> 5). Redirecting to SubscriptionPaywallScreen.");
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SubscriptionPaywallScreen(token: '')),
      );
      return;
    }

    try {
      final playUrl = '${AppConstants.baseUrl}/dramas/${widget.dramaId}/episodes/$episodeNumber/play';
      debugPrint("🌐 [EpisodesBottomSheet] Requesting Episode Play URL: $playUrl");

      final res = await http.get(Uri.parse(playUrl));
      debugPrint("📥 [EpisodesBottomSheet] Episode Play Response Status: ${res.statusCode}");
      debugPrint("📥 [EpisodesBottomSheet] Episode Play Response Body: ${res.body}");

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final streamUrl = data['data']['streamUrl'] ?? '';
        debugPrint("🎬 [EpisodesBottomSheet] Parsed Episode Stream URL: $streamUrl");

        if (streamUrl.isNotEmpty && mounted) {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlayerScreen(
                streamUrl: streamUrl,
                title: "${widget.dramaTitle} - Ep $episodeNumber",
                dramaId: widget.dramaId,
                initialEpisode: episodeNumber,
              ),
            ),
          );
        } else {
          debugPrint("⚠️ [EpisodesBottomSheet] Stream URL is empty or widget is unmounted.");
        }
      } else {
        debugPrint("❌ [EpisodesBottomSheet] Failed to load episode play link. Status: ${res.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ [EpisodesBottomSheet] Exception while playing episode: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalEpCount = widget.totalEpisodes > 0 ? widget.totalEpisodes : 50;
    List<String> ranges = [];
    for (int i = 1; i <= totalEpCount; i += 25) {
      int endRange = (i + 24 < totalEpCount) ? i + 24 : totalEpCount;
      ranges.add("$i-$endRange");
    }

    int startIdx = selectedTabRange * 25;
    int endIdx = (startIdx + 25 < totalEpCount) ? startIdx + 25 : totalEpCount;
    int countInCurrentRange = endIdx - startIdx;

    return Container(
      height: 450,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.dramaTitle,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (ranges.isNotEmpty)
            SizedBox(
              height: 35,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: ranges.length,
                itemBuilder: (context, index) {
                  final isSelected = selectedTabRange == index;
                  return GestureDetector(
                    onTap: () => setState(() => selectedTabRange = index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: isSelected ? const Color(0xFFE6007A) : Colors.transparent, width: 2)),
                      ),
                      child: Text(
                        ranges[index],
                        style: TextStyle(color: isSelected ? const Color(0xFFE6007A) : Colors.grey, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  );
                },
              ),
            ),
          const Divider(color: Colors.grey),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: countInCurrentRange > 0 ? countInCurrentRange : 0,
              itemBuilder: (context, index) {
                final epNum = startIdx + index + 1;
                final bool isLocked = epNum > 5;

                return GestureDetector(
                  onTap: () => playSelectedEpisode(epNum),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E172B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    alignment: Alignment.center,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text('$epNum', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        if (isLocked)
                          Container(
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                            child: const Center(child: Icon(Icons.lock, color: Color(0xFFE6007A), size: 16)),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}