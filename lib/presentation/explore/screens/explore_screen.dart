import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:taktaktv/presentation/explore/widgets/video_reel_player_widget.dart';
import '../../../core/constants/app_constant.dart';

class ExploreScreen extends StatefulWidget {
  final ValueNotifier<bool> isExploreActive;
  const ExploreScreen({super.key, required this.isExploreActive});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  List dramas = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchExploreDramas();
  }

  Future<void> fetchExploreDramas() async {
    try {
      final apiUrl = '${AppConstants.baseUrl}/dramas?page=1&limit=20';
      final res = await http.get(Uri.parse(apiUrl));

      if (res.statusCode == 250 || res.statusCode == 200) {
        final data = json.decode(res.body);

        List fetchedList = [];
        if (data is List) {
          fetchedList = data;
        } else if (data['data'] is List) {
          fetchedList = data['data'];
        } else if (data['dramas'] is List) {
          fetchedList = data['dramas'];
        }

        setState(() {
          dramas = fetchedList;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("ExploreScreen Exception: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE6007A)))
          : dramas.isEmpty
          ? const Center(child: Text('No videos found', style: TextStyle(color: Colors.grey)))
          : PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: dramas.length,
        itemBuilder: (context, index) {
          final drama = dramas[index];
          final dramaId = drama['_id'] ?? '';
          final title = drama['title'] ?? '';

          return VideoReelPlayerWidget(
            dramaId: dramaId,
            title: title,
            isExploreActive: widget.isExploreActive,
          );
        },
      ),
    );
  }
}