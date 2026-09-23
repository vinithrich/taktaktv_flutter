import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/constants/app_constant.dart';
import 'premium_screen.dart';

class LanguageSelectionScreen extends StatefulWidget {
  final String token;
  const LanguageSelectionScreen({super.key, required this.token});

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  List languages = [];
  bool isLoading = true;
  String selectedLangCode = 'hi';

  @override
  void initState() {
    super.initState();
    fetchLanguages();
  }

  Future<void> fetchLanguages() async {
    try {
      final res = await http.get(Uri.parse(AppConstants.contentLanguages));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          languages = data['data'];
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> savePreferences() async {
    try {
      await http.put(
        Uri.parse(AppConstants.updatePreferences),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode({
          "languages": [selectedLangCode]
        }),
      );
    } catch (e) {
      // Handle error if needed
    }

    // Navigate to Premium Page
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => PremiumScreen(token: widget.token)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0710),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFE6007A)))
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose content language',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'See dramas in this language',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: languages.length,
                itemBuilder: (context, index) {
                  final lang = languages[index];
                  final isSelected = selectedLangCode == lang['code'];
                  return GestureDetector(
                    onTap: () => setState(() => selectedLangCode = lang['code']),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF140F1D),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFE6007A) : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${lang['name']} Shows",
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const Icon(Icons.movie, color: Colors.grey),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE6007A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                onPressed: savePreferences,
                child: const Text('Continue', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => PremiumScreen(token: widget.token)),
                  );
                },
                child: const Text('Skip', style: TextStyle(color: Colors.grey, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}