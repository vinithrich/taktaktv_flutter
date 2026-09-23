import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:taktaktv/presentation/navigation/main_navigation.dart';
import 'package:taktaktv/presentation/subscriptions/screens/subcription_paywall_screen.dart';
import 'package:taktaktv/presentation/watchlater/screens/watch_later_manager.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../../core/constants/app_constant.dart';

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

class PlayerScreen extends StatefulWidget {
  final String streamUrl;
  final String title;
  final String dramaId;
  final int initialEpisode;
  final Duration? initialPosition;

  const PlayerScreen({
    super.key,
    required this.streamUrl,
    required this.title,
    this.dramaId = '',
    this.initialEpisode = 1,
    this.initialPosition,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  int totalEpisodes = 50;
  String dramaLanguage = 'English';
  bool isLoadingDetails = true;
  bool hasActiveSubscription = false;
  bool isCheckingSubscription = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _checkUserSubscriptionStatus().then((_) {
      if (!hasActiveSubscription && widget.initialEpisode > 5) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigateToPaywall();
        });
        return;
      }
    });

    if (widget.dramaId.isNotEmpty) {
      fetchDramaDetails();
    } else {
      setState(() => isLoadingDetails = false);
    }
  }

  Future<String> _getValidToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? prefs.getString('auth_token') ?? '';
  }

  Future<void> _checkUserSubscriptionStatus() async {
    try {
      final token = await _getValidToken();
      final res = await http.get(
        Uri.parse('${AppConstants.baseUrl}/subscriptions/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final jsonResponse = json.decode(res.body);
        final data = jsonResponse['data'];
        bool active = false;

        if (data is Map) {
          active = data['isPremium'] ??
              data['hasActiveSubscription'] ??
              data['isVip'] ??
              data['isSubscriber'] ??
              data['isActive'] ??
              (data['status'] == 'active') ??
              false;
        } else if (jsonResponse['success'] == true) {
          active = true;
        }

        setState(() {
          hasActiveSubscription = active;
          isCheckingSubscription = false;
        });
      } else {
        setState(() => isCheckingSubscription = false);
      }
    } catch (e) {
      debugPrint("Error checking subscription status: $e");
      setState(() => isCheckingSubscription = false);
    }
  }

  Future<void> fetchDramaDetails() async {
    try {
      final token = await _getValidToken();
      final res = await http.get(
        Uri.parse('${AppConstants.baseUrl}/dramas/${widget.dramaId}'),
        headers: token.isNotEmpty ? {'Authorization': 'Bearer $token'} : {},
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['data'] != null) {
          setState(() {
            totalEpisodes = data['data']['totalEpisodes'] ?? 50;
            dramaLanguage = data['data']['language'] ?? 'English';
            isLoadingDetails = false;
          });
        } else {
          setState(() => isLoadingDetails = false);
        }
      } else {
        setState(() => isLoadingDetails = false);
      }
    } catch (e) {
      debugPrint("Error fetching drama details: $e");
      setState(() => isLoadingDetails = false);
    }
  }

  Future<void> _navigateToPaywall() async {
    final token = await _getValidToken();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SubscriptionPaywallScreen(token: token),
      ),
    );
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingDetails || isCheckingSubscription) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Color(0xFFE6007A))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: totalEpisodes,
        controller: PageController(initialPage: widget.initialEpisode - 1),
        onPageChanged: (index) {
          int currentEp = index + 1;
          if (!hasActiveSubscription && currentEp > 5) {
            _navigateToPaywall();
          }
        },
        itemBuilder: (context, index) {
          int episodeNumber = index + 1;
          return VerticalEpisodePlayerPage(
            dramaId: widget.dramaId,
            dramaTitle: widget.title,
            episodeNumber: episodeNumber,
            totalEpisodes: totalEpisodes,
            fallbackStreamUrl: episodeNumber == widget.initialEpisode ? widget.streamUrl : '',
            initialPosition: episodeNumber == widget.initialEpisode ? widget.initialPosition : null,
            hasActiveSubscription: hasActiveSubscription,
            onPaywallRequired: _navigateToPaywall,
            dramaLanguage: dramaLanguage,
          );
        },
      ),
    );
  }
}

class SubtitleItem {
  final Duration start;
  final Duration end;
  final String text;

  SubtitleItem({required this.start, required this.end, required this.text});
}

class VerticalEpisodePlayerPage extends StatefulWidget {
  final String dramaId;
  final String dramaTitle;
  final int episodeNumber;
  final int totalEpisodes;
  final String fallbackStreamUrl;
  final Duration? initialPosition;
  final bool hasActiveSubscription;
  final VoidCallback onPaywallRequired;
  final String dramaLanguage;

  const VerticalEpisodePlayerPage({
    super.key,
    required this.dramaId,
    required this.dramaTitle,
    required this.episodeNumber,
    required this.totalEpisodes,
    required this.fallbackStreamUrl,
    this.initialPosition,
    required this.hasActiveSubscription,
    required this.onPaywallRequired,
    required this.dramaLanguage,
  });

  @override
  State<VerticalEpisodePlayerPage> createState() => _VerticalEpisodePlayerPageState();
}

class _VerticalEpisodePlayerPageState extends State<VerticalEpisodePlayerPage>
    with WidgetsBindingObserver, RouteAware {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  String episodeTitle = '';
  bool _isLoadingEpisode = true;

  // Save / Bookmark state variables
  bool isSaved = false;
  bool isSavingAction = false;

  List<dynamic> qualities = [];
  List<dynamic> subtitles = [];
  List<dynamic> audioLanguages = [];
  String selectedQuality = "Auto";
  String selectedSubtitle = "Off";
  String selectedAudioLang = "";

  List<SubtitleItem> parsedSubtitles = [];
  String currentSubtitleText = "";

  bool _showControls = true;
  Timer? _hideTimer;
  Timer? _progressTimer;
  bool _hasSeekedInitial = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    episodeTitle = "${widget.dramaTitle} - Ep ${widget.episodeNumber}";

    audioLanguages = [widget.dramaLanguage.isNotEmpty ? widget.dramaLanguage : 'English'];
    selectedAudioLang = audioLanguages.first.toString();

    // Check if the drama is saved initially
    if (widget.dramaId.isNotEmpty) {
      _checkDramaSavedStatus();
    }

    if (!widget.hasActiveSubscription && widget.episodeNumber > 5) {
      return;
    }

    if (widget.dramaId.isNotEmpty) {
      fetchPlayDetailsAndInitialize(widget.episodeNumber);
    } else if (widget.fallbackStreamUrl.isNotEmpty) {
      initializePlayer(widget.fallbackStreamUrl);
    }
  }

  Future<String> _getValidToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? prefs.getString('auth_token') ?? '';
  }

  // Check if drama is saved using GET /api/v1/dramas/:dramaId
  Future<void> _checkDramaSavedStatus() async {
    try {
      final token = await _getValidToken();
      final res = await http.get(
        Uri.parse('${AppConstants.baseUrl}/dramas/${widget.dramaId}'),
        headers: token.isNotEmpty ? {'Authorization': 'Bearer $token'} : {},
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['data'] != null && mounted) {
          setState(() {
            isSaved = data['data']['isFollowing'] ?? data['data']['isSaved'] ?? false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error checking saved status: $e");
    }
  }

  // Toggle Save / Unsave Drama using POST / DELETE /api/v1/dramas/:dramaId/follow
  // _toggleSaveDrama method inside _VerticalEpisodePlayerPageState (PlayerScreen)
  // Toggle Save / Unsave Drama using POST / DELETE /api/v1/dramas/:dramaId/follow
  Future<void> _toggleSaveDrama() async {
    if (isSavingAction || widget.dramaId.isEmpty) return;
    setState(() => isSavingAction = true);

    try {
      final token = await _getValidToken();
      final headers = token.isNotEmpty ? {'Authorization': 'Bearer $token'} : <String, String>{};
      final url = Uri.parse('${AppConstants.baseUrl}/dramas/${widget.dramaId}/follow');

      // Server-ku thevaiyana request anupputhal (Delete if already saved, Post if not)
      final response = isSaved
          ? await http.delete(url, headers: headers)
          : await http.post(url, headers: headers);

      debugPrint("📥 [Player Save Debug] Toggle Response Code: ${response.statusCode}");
      debugPrint("📥 [Player Save Debug] Toggle Response Body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final resData = json.decode(response.body);
        final responseData = resData['data'];

        setState(() {
          if (responseData is Map) {
            // Server response-la irukku boolean values-ai moolamaaga eduthu set seiyum
            isSaved = responseData['isFollowing'] ??
                responseData['isSaved'] ??
                responseData['isBookmarked'] ??
                !isSaved;
          } else {
            // Response map-aaga illavittal manual-ah toggle pannum
            isSaved = !isSaved;
          }
        });

        // --- INSTANT SYNC NOTIFIER ---
        WatchLaterManager().updateStatus(widget.dramaId, isSaved);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isSaved ? "Added to Watch Later" : "Removed from Watch Later"),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else {
        debugPrint("❌ [Player Save Debug] Failed to toggle save. Status: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ [Player Save Debug] Error toggling save drama: $e");
    } finally {
      if (mounted) {
        setState(() => isSavingAction = false);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final modalRoute = ModalRoute.of(context);
    if (modalRoute is PageRoute) {
      routeObserver.subscribe(this, modalRoute);
    }
  }

  @override
  void dispose() {
    _sendWatchProgress(isExit: true);
    _hideTimer?.cancel();
    _progressTimer?.cancel();
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_controller != null) {
      if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
        _controller!.pause();
        _sendWatchProgress(isExit: true);
      }
    }
  }

  @override
  void didPushNext() {
    if (_controller != null && _controller!.value.isPlaying) {
      _controller!.pause();
      _sendWatchProgress(isExit: true);
    }
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 7), (timer) {
      _sendWatchProgress(isExit: false);
    });
  }

  Future<void> _sendWatchProgress({bool isExit = false}) async {
    if (_controller == null || !_controller!.value.isInitialized || widget.dramaId.isEmpty) return;
    try {
      final token = await _getValidToken();
      if (token.isEmpty) return;

      final positionSeconds = _controller!.value.position.inSeconds;
      final durationSeconds = _controller!.value.duration.inSeconds;

      if (durationSeconds <= 0) return;

      await http.post(
        Uri.parse('${AppConstants.baseUrl}/playback/progress'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          "dramaId": widget.dramaId,
          "episodeNumber": widget.episodeNumber,
          "positionSeconds": positionSeconds,
          "durationSeconds": durationSeconds,
        }),
      );
    } catch (e) {
      debugPrint("Error sending watch progress: $e");
    }
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

  void _togglePlayPause() {
    setState(() {
      if (_controller != null && _controller!.value.isInitialized) {
        if (_controller!.value.isPlaying) {
          _controller!.pause();
          _sendWatchProgress(isExit: true);
        } else {
          _controller!.play();
        }
      }
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

  Future<void> fetchPlayDetailsAndInitialize(int episodeNumber) async {
    try {
      final playUrl = '${AppConstants.baseUrl}/dramas/${widget.dramaId}/episodes/$episodeNumber/play';
      final token = await _getValidToken();

      final res = await http.get(
        Uri.parse(playUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final playData = data['data'] ?? data;

        if (playData != null) {
          if (playData['title'] != null) {
            setState(() {
              episodeTitle = "${widget.dramaTitle} - ${playData['title']}";
            });
          }
          qualities = playData['qualities'] ?? [];
          subtitles = playData['subtitles'] ?? [];

          loadStreamWithQuality(playData);
        } else if (widget.fallbackStreamUrl.isNotEmpty) {
          initializePlayer(widget.fallbackStreamUrl);
        } else {
          setState(() => _isLoadingEpisode = false);
        }
      } else if (res.statusCode == 403) {
        widget.onPaywallRequired();
      } else if (widget.fallbackStreamUrl.isNotEmpty) {
        initializePlayer(widget.fallbackStreamUrl);
      } else {
        setState(() => _isLoadingEpisode = false);
      }
    } catch (e) {
      debugPrint("Error fetching play details: $e");
      if (widget.fallbackStreamUrl.isNotEmpty) {
        initializePlayer(widget.fallbackStreamUrl);
      } else {
        setState(() => _isLoadingEpisode = false);
      }
    }
  }

  void loadStreamWithQuality(Map<String, dynamic> playApiResponseData) {
    String targetUrl = playApiResponseData['streamUrl'] ?? widget.fallbackStreamUrl;

    if (selectedQuality != 'Auto') {
      for (var q in qualities) {
        if (q['label'].toString().contains(selectedQuality)) {
          targetUrl = q['url'] ?? targetUrl;
          break;
        }
      }
    }

    if (targetUrl.isNotEmpty) {
      initializePlayer(targetUrl);
    } else {
      setState(() => _isLoadingEpisode = false);
    }
  }

  void _changeQuality(String qualityLabel, String url) {
    setState(() {
      selectedQuality = qualityLabel;
    });
    final position = _controller?.value.position ?? Duration.zero;
    _controller?.pause();
    initializePlayer(url);
    Future.delayed(const Duration(milliseconds: 500), () {
      _controller?.seekTo(position);
    });
  }

  Future<void> _loadSubtitleFile(String srtUrl) async {
    try {
      final response = await http.get(Uri.parse(srtUrl));
      if (response.statusCode == 200) {
        final srtString = utf8.decode(response.bodyBytes);
        setState(() {
          parsedSubtitles = parseSrt(srtString);
        });
      }
    } catch (e) {
      debugPrint("Error loading subtitle file: $e");
    }
  }

  List<SubtitleItem> parseSrt(String srtContent) {
    final List<SubtitleItem> subs = [];
    final normContent = srtContent.replaceAll('\r\n', '\n');
    final blocks = normContent.split('\n\n');

    for (var block in blocks) {
      final lines = block.split('\n');
      if (lines.length >= 3) {
        final timeLine = lines[1];
        final timeParts = timeLine.split('-->');
        if (timeParts.length == 2) {
          final start = _parseSrtDuration(timeParts[0].trim());
          final end = _parseSrtDuration(timeParts[1].trim());
          final text = lines.sublist(2).join('\n');
          subs.add(SubtitleItem(start: start, end: end, text: text));
        }
      }
    }
    return subs;
  }

  Duration _parseSrtDuration(String timeStr) {
    final parts = timeStr.replaceAll(',', '.').split(':');
    if (parts.length == 3) {
      final hours = int.tryParse(parts[0]) ?? 0;
      final minutes = int.tryParse(parts[1]) ?? 0;
      final secParts = parts[2].split('.');
      final seconds = int.tryParse(secParts[0]) ?? 0;
      final milliseconds = secParts.length > 1 ? int.tryParse(secParts[1].padRight(3, '0').substring(0, 3)) ?? 0 : 0;
      return Duration(hours: hours, minutes: minutes, seconds: seconds, milliseconds: milliseconds);
    }
    return Duration.zero;
  }

  void initializePlayer(String url) {
    _controller?.dispose();
    _controller = VideoPlayerController.networkUrl(Uri.parse(url))
      ..addListener(_videoListener)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
            _isLoadingEpisode = false;
          });

          if (!_hasSeekedInitial && widget.initialPosition != null && widget.initialPosition! > Duration.zero) {
            _controller?.seekTo(widget.initialPosition!);
            _hasSeekedInitial = true;
          }

          _controller?.play();
          _controller?.setLooping(true);
          _startHideTimer();
          _startProgressTimer();
        }
      }).catchError((error) {
        debugPrint("Player error: $error");
        if (mounted) setState(() => _isLoadingEpisode = false);
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
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.85,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      const Text("Video Settings", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),

                      const Text("Quality", style: TextStyle(color: Color(0xFFE6007A), fontWeight: FontWeight.bold)),
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
                      const SizedBox(height: 16),

                      const Text("Audio Language", style: TextStyle(color: Color(0xFFE6007A), fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: audioLanguages.map((lang) {
                          final langName = lang.toString();
                          final isSel = selectedAudioLang == langName;
                          return ChoiceChip(
                            label: Text(langName),
                            selected: isSel,
                            selectedColor: const Color(0xFFE6007A),
                            backgroundColor: const Color(0xFF1E172B),
                            labelStyle: TextStyle(color: isSel ? Colors.white : Colors.grey),
                            onSelected: (val) {
                              setModalState(() => selectedAudioLang = langName);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      const Text("Subtitles (Captions)", style: TextStyle(color: Color(0xFFE6007A), fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      subtitles.isEmpty
                          ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          "No subtitles for this video",
                          style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic),
                        ),
                      )
                          : Wrap(
                        spacing: 8,
                        children: subtitles.map((s) {
                          final label = s['label'] ?? '';
                          final srtUrl = s['url'] ?? '';
                          final isSel = selectedSubtitle == label;
                          return ChoiceChip(
                            label: Text(label),
                            selected: isSel,
                            selectedColor: const Color(0xFFE6007A),
                            backgroundColor: const Color(0xFF1E172B),
                            labelStyle: TextStyle(color: isSel ? Colors.white : Colors.grey),
                            onSelected: (val) {
                              setModalState(() => selectedSubtitle = label);
                              setState(() {
                                selectedSubtitle = label;
                              });
                              if (label.toLowerCase() == 'off' || srtUrl.isEmpty) {
                                setState(() {
                                  parsedSubtitles = [];
                                  currentSubtitleText = "";
                                });
                              } else {
                                _loadSubtitleFile(srtUrl);
                              }
                              Navigator.pop(context);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    ).then((_) {
      if (_controller != null && _controller!.value.isPlaying) _startHideTimer();
    });
  }

  void _showEpisodesBottomSheet(BuildContext context) {
    _hideTimer?.cancel();
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
          dramaTitle: widget.dramaTitle,
          totalEpisodes: widget.totalEpisodes,
          hasActiveSubscription: widget.hasActiveSubscription,
          onEpisodeSelected: (episodeNumber, newTitle) {
            _sendWatchProgress(isExit: true);
            if (!widget.hasActiveSubscription && episodeNumber > 5) {
              Navigator.pop(context);
              widget.onPaywallRequired();
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => PlayerScreen(
                    streamUrl: widget.fallbackStreamUrl,
                    title: widget.dramaTitle,
                    dramaId: widget.dramaId,
                    initialEpisode: episodeNumber,
                  ),
                ),
              );
            }
          },
        );
      },
    ).then((_) {
      if (_controller != null && _controller!.value.isPlaying) {
        _startHideTimer();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.hasActiveSubscription && widget.episodeNumber > 5) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_rounded, color: Color(0xFFE6007A), size: 60),
              const SizedBox(height: 16),
              const Text(
                "Unlock Premium Episodes",
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Subscribe to watch episode 6 and beyond.",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE6007A),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: widget.onPaywallRequired,
                child: const Text("Subscribe Now", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    final position = _controller != null && _controller!.value.isInitialized ? _controller!.value.position : Duration.zero;
    final duration = _controller != null && _controller!.value.isInitialized ? _controller!.value.duration : Duration.zero;

    return Stack(
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
              : const CircularProgressIndicator(color: Color(0xFFE6007A)),
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
                onTap: _togglePlayPause,
                onDoubleTap: _seekBackward,
                child: const SizedBox.expand(),
              ),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _togglePlayPause,
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
                      colors: [Colors.black54, Colors.transparent, Colors.black.withOpacity(0.8)],
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
                        onPressed: _togglePlayPause,
                      ),
                      const SizedBox(width: 20),
                      IconButton(
                        icon: const Icon(Icons.forward_10, color: Colors.white70, size: 36),
                        onPressed: _seekForward,
                      ),
                    ],
                  ),
                ),

                Positioned(
                  top: 40,
                  left: 16,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    onPressed: () async{
                      _sendWatchProgress(isExit: true);
                      _controller?.pause();
                      final token = await _getValidToken();
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MainNavigationShell(token:token )));
                    },
                  ),
                ),

                // Right Action Sidebar (Settings, Save, Episodes)
                Positioned(
                  right: 16,
                  bottom: 80,
                  child: Column(
                    children: [
                      // Settings Icon
                      IconButton(
                        icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 28),
                        onPressed: () => _showOptionsBottomSheet(context),
                      ),
                      const Text('Settings', style: TextStyle(color: Colors.white, fontSize: 10)),
                      const SizedBox(height: 16),

                      // Save / Bookmark Icon (Added right below Settings)
                      if (widget.dramaId.isNotEmpty) ...[
                        IconButton(
                          icon: Icon(
                            isSaved ? Icons.bookmark : Icons.bookmark_border,
                            color: isSaved ? const Color(0xFFE6007A) : Colors.white,
                            size: 28,
                          ),
                          onPressed: isSavingAction ? null : _toggleSaveDrama,
                        ),
                        Text(
                          isSaved ? 'Saved' : 'Save',
                          style: TextStyle(
                            color: isSaved ? const Color(0xFFE6007A) : Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Episodes Icon
                      if (widget.dramaId.isNotEmpty)
                        Column(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.list_alt_rounded, color: Colors.white, size: 28),
                              onPressed: () => _showEpisodesBottomSheet(context),
                            ),
                            const Text('Episodes', style: TextStyle(color: Colors.white, fontSize: 10)),
                          ],
                        ),
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
                        episodeTitle,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.swap_vert, color: Color(0xFFE6007A), size: 14),
                          const SizedBox(width: 4),
                          const Text('Swipe up for next episode', style: TextStyle(color: Colors.grey, fontSize: 11)),
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
    );
  }
}

class EpisodesBottomSheet extends StatefulWidget {
  final String dramaId;
  final String dramaTitle;
  final int totalEpisodes;
  final bool hasActiveSubscription;
  final Function(int episodeNumber, String title) onEpisodeSelected;

  const EpisodesBottomSheet({
    super.key,
    required this.dramaId,
    required this.dramaTitle,
    required this.totalEpisodes,
    required this.hasActiveSubscription,
    required this.onEpisodeSelected,
  });

  @override
  State<EpisodesBottomSheet> createState() => _EpisodesBottomSheetState();
}

class _EpisodesBottomSheetState extends State<EpisodesBottomSheet> {
  int selectedTabRange = 0;
  List<dynamic> episodesData = [];
  bool isLoadingEpisodes = true;
  int? selectedEpisodeIndex;

  @override
  void initState() {
    super.initState();
    _fetchEpisodesList();
  }

  Future<void> _fetchEpisodesList() async {
    try {
      final res = await http.get(Uri.parse('${AppConstants.baseUrl}/dramas/${widget.dramaId}/episodes'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (mounted) {
          setState(() {
            episodesData = data['data'] ?? [];
            isLoadingEpisodes = false;
          });
        }
      } else {
        if (mounted) setState(() => isLoadingEpisodes = false);
      }
    } catch (e) {
      debugPrint("Error fetching episodes: $e");
      if (mounted) setState(() => isLoadingEpisodes = false);
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
      height: MediaQuery.of(context).size.height * 0.6,
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
            child: isLoadingEpisodes
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE6007A)))
                : ListView.builder(
              itemCount: countInCurrentRange,
              itemBuilder: (context, index) {
                final epNum = startIdx + index + 1;
                final bool isThisClicked = selectedEpisodeIndex == epNum;
                final bool isLocked = !widget.hasActiveSubscription && epNum > 5;

                Map<String, dynamic>? matchedEp;
                for (var ep in episodesData) {
                  if (ep['episodeNumber'] == epNum || ep['number'] == epNum) {
                    matchedEp = ep;
                    break;
                  }
                }

                String epTitle = matchedEp?['title'] ?? 'Episode $epNum';
                String thumbnailUrl = matchedEp?['thumbnail'] ?? matchedEp?['poster'] ?? '';
                String description = matchedEp?['description'] ?? 'Watch full episode $epNum of ${widget.dramaTitle}.';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: InkWell(
                    onTap: isThisClicked
                        ? null
                        : () {
                      setState(() {
                        selectedEpisodeIndex = epNum;
                      });
                      widget.onEpisodeSelected(epNum, "${widget.dramaTitle} - Ep $epNum");
                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: thumbnailUrl.isNotEmpty
                                  ? Image.network(
                                thumbnailUrl,
                                width: 110,
                                height: 65,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 110,
                                  height: 65,
                                  color: const Color(0xFF1E172B),
                                  child: const Icon(Icons.movie, color: Colors.grey),
                                ),
                              )
                                  : Container(
                                width: 110,
                                height: 65,
                                color: const Color(0xFF1E172B),
                                alignment: Alignment.center,
                                child: Text('$epNum', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            if (isLocked)
                              Container(
                                width: 110,
                                height: 65,
                                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                                child: const Center(child: Icon(Icons.lock, color: Color(0xFFE6007A), size: 24)),
                              )
                            else if (isThisClicked)
                              Container(
                                width: 110,
                                height: 65,
                                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                                child: const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(color: Color(0xFFE6007A), strokeWidth: 2.5),
                                  ),
                                ),
                              )
                            else
                              const Icon(Icons.play_circle_fill, color: Colors.white70, size: 28),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      "$epNum. $epTitle",
                                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isLocked) const Icon(Icons.lock, color: Color(0xFFE6007A), size: 14),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.grey, fontSize: 11),
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
        ],
      ),
    );
  }
}