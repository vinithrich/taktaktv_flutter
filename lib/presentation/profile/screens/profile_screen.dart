import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taktaktv/presentation/auth/screens/login_screen.dart';
import 'package:taktaktv/presentation/subscriptions/screens/subcription_paywall_screen.dart';
import 'video_player_settings_screen.dart';
import '../../../core/constants/app_constant.dart';
import '../../player/screens/player_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
// ==========================================
// 1. STATIC CONTENT SCREEN (Fetches from GET /config)
// ==========================================
class StaticContentScreen extends StatefulWidget {
  final String title;
  final String contentType; // 'privacy' or 'terms' or 'about'

  const StaticContentScreen({
    super.key,
    required this.title,
    required this.contentType,
  });

  @override
  State<StaticContentScreen> createState() => _StaticContentScreenState();
}

class _StaticContentScreenState extends State<StaticContentScreen> {
  bool isLoading = true;
  String content = "";

  @override
  void initState() {
    super.initState();
    fetchConfigContent();
  }

  Future<void> fetchConfigContent() async {
    try {
      final res = await http.get(Uri.parse('${AppConstants.baseUrl}/config'));
      if (res.statusCode == 200) {
        final resData = json.decode(res.body);
        final data = resData['data'] ?? {};

        setState(() {
          if (widget.contentType == 'privacy') {
            content = data['privacyPolicyContent'] ?? "No privacy policy available.";
          } else if (widget.contentType == 'terms') {
            content = data['termsContent'] ?? "No terms and conditions available.";
          } else if (widget.contentType == 'about') {
            content = data['aboutUs'] ?? "No information available.";
          } else {
            content = "No content available.";
          }
          isLoading = false;
        });
      } else {
        setState(() {
          content = "Failed to load content from the server.";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        content = "Error: $e";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0710),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(
        child: CircularProgressIndicator(color: Color(0xFFE6007A)),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          content,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 2. PROFILE SCREEN
// ==========================================
class ProfileScreen extends StatefulWidget {
  final String token;
  const ProfileScreen({super.key, required this.token});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List recommendedDramas = [];
  bool isLoading = true;
  bool isUploadingImage = false;
  bool isSavingUsername = false;
  bool isEditingUsername = false; // Username edit mode state

  String userId = "147357155";
  String? profileImageUrl;

  // Username Controller for editing
  final TextEditingController _usernameController = TextEditingController();

  // VIP Subscription Status Variables
  bool hasActiveSubscription = false;
  bool isCheckingSubscription = true;

  @override
  void initState() {
    super.initState();
    fetchRecommendedDramas();
    fetchUserProfile();
    _checkUserSubscriptionStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkUserSubscriptionStatus();
  }

  // Get valid Token Helper (Widget token or SharedPreferences fallback)
  Future<String> _getValidToken() async {
    if (widget.token.isNotEmpty) return widget.token;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? prefs.getString('auth_token') ?? '';
  }

  // Check VIP Subscription Status API
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
          active = data['isPremium'] ?? // Added isPremium check here!
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

        debugPrint("DEBUG FIXED ACTIVE SUBSCRIPTION: $active");
      } else {
        setState(() => isCheckingSubscription = false);
      }
    } catch (e) {
      debugPrint("Error checking subscription status: $e");
      setState(() => isCheckingSubscription = false);
    }
  }

  // Parse Image URL (Handles Base64 strings, Http links, and Relative paths correctly)
  String? _parseImageUrl(dynamic rawUrl) {
    if (rawUrl == null || rawUrl.toString().trim().isEmpty) return null;
    String url = rawUrl.toString().trim();

    if (url.startsWith('data:image')) {
      return url;
    }

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    Uri uri = Uri.parse(AppConstants.baseUrl);
    String domain = "${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}";

    if (url.startsWith('/')) {
      return "$domain$url";
    } else {
      return "$domain/$url";
    }
  }

  // Convert Base64 string to Uint8List for MemoryImage
  Uint8List? _getMemoryImage(String? urlOrBase64) {
    if (urlOrBase64 == null || urlOrBase64.isEmpty) return null;
    if (urlOrBase64.startsWith('data:image')) {
      try {
        final base64String = urlOrBase64.split(',').last;
        return base64Decode(base64String);
      } catch (e) {
        debugPrint("Base64 decode error: $e");
        return null;
      }
    }
    return null;
  }

  Future<void> fetchUserProfile() async {
    try {
      final token = await _getValidToken();
      final res = await http.get(
        Uri.parse('${AppConstants.baseUrl}/users/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final decodedRes = json.decode(res.body);
        final user = decodedRes['data']['user'] ?? decodedRes['data'] ?? {};

        var rawImg = user['profileImage'] ??
            user['avatar'] ??
            user['profile_image'] ??
            user['imageUrl'];

        String? formattedUrl = _parseImageUrl(rawImg);

        setState(() {
          userId = user['_id']?.toString() ?? user['id']?.toString() ?? "147357155";
          profileImageUrl = formattedUrl;
          _usernameController.text = user['name'] ?? user['username'] ?? '';
        });

        debugPrint("FINAL FORMATTED PROFILE IMAGE URL: $profileImageUrl");
      }
    } catch (e) {
      debugPrint("Profile error: $e");
    }
  }

  // Update Username API Method
  Future<void> _updateUsername() async {
    final newUsername = _usernameController.text.trim();
    if (newUsername.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username cannot be empty')),
      );
      return;
    }

    setState(() => isSavingUsername = true);

    try {
      final token = await _getValidToken();

      final res = await http.put(
        Uri.parse('${AppConstants.baseUrl}/users/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          "name": newUsername,
        }),
      );

      setState(() {
        isSavingUsername = false;
        isEditingUsername = false;
      });

      if (res.statusCode == 200 || res.statusCode == 201) {
        final responseData = json.decode(res.body);
        final updatedUser = responseData['data'];
        if (updatedUser != null && updatedUser['name'] != null) {
          setState(() {
            _usernameController.text = updatedUser['name'];
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Username updated successfully!')),
          );
        }
      } else {
        final errorData = json.decode(res.body);
        String msg = errorData['message'] ?? 'Failed to update username';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
      }
    } catch (e) {
      setState(() {
        isSavingUsername = false;
        isEditingUsername = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // Image Picker and Upload Method
  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (image == null) return;

    setState(() {
      isUploadingImage = true;
    });

    try {
      final token = await _getValidToken();
      if (token.isEmpty) {
        setState(() => isUploadingImage = false);
        return;
      }

      final bytes = await image.readAsBytes();
      String base64Image = "data:image/jpeg;base64,${base64Encode(bytes)}";

      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/users/profile-image'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          "profileImage": base64Image,
        }),
      );

      setState(() => isUploadingImage = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);

        var rawUrl = data['profileImage'] ??
            data['url'] ??
            data['data']?['profileImage'] ??
            data['data']?['avatar'] ??
            data['data']?['url'] ??
            data['data']?['user']?['profileImage'] ??
            data['data']?['user']?['avatar'];

        String? newUrl = _parseImageUrl(rawUrl) ?? base64Image;

        if (newUrl.isNotEmpty) {
          setState(() {
            profileImageUrl = newUrl;
          });
        }

        await fetchUserProfile();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile image updated successfully!')),
          );
        }
      } else {
        final errorData = json.decode(response.body);
        String errorMessage = errorData['message'] ?? 'Failed to upload image';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      }
    } catch (e) {
      setState(() => isUploadingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> fetchRecommendedDramas() async {
    try {
      final res = await http.get(Uri.parse('${AppConstants.baseUrl}/dramas/recommended'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          recommendedDramas = data['data'] ?? [];
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  // --- POST /contact-us Dialog Form ---
  void _showContactUsModal() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final messageController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF140F1D),
          title: const Text('Contact Support', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Name', labelStyle: TextStyle(color: Colors.grey)),
                ),
                TextField(
                  controller: emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Email', labelStyle: TextStyle(color: Colors.grey)),
                ),
                TextField(
                  controller: phoneController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone', labelStyle: TextStyle(color: Colors.grey)),
                ),
                TextField(
                  controller: messageController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Message', labelStyle: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE6007A)),
              onPressed: isSubmitting
                  ? null
                  : () async {
                setDialogState(() => isSubmitting = true);
                try {
                  final res = await http.post(
                    Uri.parse('${AppConstants.baseUrl}/contact-us'),
                    headers: {'Content-Type': 'application/json'},
                    body: json.encode({
                      "name": nameController.text.trim(),
                      "email": emailController.text.trim(),
                      "phone": phoneController.text.trim(),
                      "message": messageController.text.trim(),
                    }),
                  );

                  if (res.statusCode == 200) {
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Your message has been submitted to customer support.')),
                      );
                    }
                  } else {
                    setDialogState(() => isSubmitting = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to submit message. Try again.')),
                      );
                    }
                  }
                } catch (e) {
                  setDialogState(() => isSubmitting = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Submit', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // --- Logout Method ---
  // --- Logout Method with FCM Token Clearing ---
  Future<void> _handleLogout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF140F1D),
        title: const Text('Logout', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to logout?', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                // 1. Clear Firebase Cloud Messaging (FCM) token
                await FirebaseMessaging.instance.deleteToken();
                debugPrint("FCM Token cleared successfully.");
              } catch (e) {
                debugPrint("Error clearing FCM token: $e");
              }

              // 2. Clear local session/preferences
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();

              // 3. Navigate back to Login Screen
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => LoginScreen()),
                      (route) => false,
                );
              }
            },
            child: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  // --- Delete Account Method ---
  Future<void> _processAccountDeletion(BuildContext context) async {
    try {
      final activeToken = await _getValidToken();

      if (activeToken.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session expired. Please login again.')),
          );
        }
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFE6007A)),
        ),
      );

      final deleteUrl = '${AppConstants.baseUrl}/users/me';

      final response = await http.delete(
        Uri.parse(deleteUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $activeToken',
        },
      );

      if (context.mounted) Navigator.pop(context);

      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204 || response.statusCode == 403) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        if (context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => LoginScreen()),
                (route) => false,
          );
        }
      } else {
        final errorData = json.decode(response.body);
        String message = errorData['message'] ?? 'Failed to delete account.';

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0710),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: isUploadingImage ? null : _pickAndUploadImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.grey.shade800,
                        backgroundImage: (profileImageUrl != null && profileImageUrl!.isNotEmpty)
                            ? (profileImageUrl!.startsWith('data:image')
                            ? MemoryImage(_getMemoryImage(profileImageUrl!)!) as ImageProvider
                            : NetworkImage(profileImageUrl!))
                            : const AssetImage('assets/default_profile.png'),
                      ),
                      if (isUploadingImage)
                        const Positioned.fill(
                          child: CircularProgressIndicator(color: Color(0xFFE6007A), strokeWidth: 1),
                        ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE6007A),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Username Edit Field & VIP Badge Row ---
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 38,
                              child: TextField(
                                controller: _usernameController,
                                enabled: isEditingUsername,
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  hintText: 'Enter Username',
                                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                  filled: true,
                                  fillColor: const Color(0xFF140F1D),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                                  ),
                                  disabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.1)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFFE6007A)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),

                          // --- VIP BADGE DISPLAY ---
                          if (!isCheckingSubscription && hasActiveSubscription) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFE6007A), Colors.purpleAccent],
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.workspace_premium, color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    "VIP",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],

                          // Edit/Save Button Toggle
                          isEditingUsername
                              ? SizedBox(
                            height: 38,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE6007A),
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: isSavingUsername ? null : _updateUsername,
                              child: isSavingUsername
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('Save', style: TextStyle(color: Colors.white, fontSize: 12)),
                            ),
                          )
                              : InkWell(
                            onTap: () {
                              setState(() {
                                isEditingUsername = true;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF140F1D),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.withOpacity(0.3)),
                              ),
                              child: const Icon(Icons.edit, color: Color(0xFFE6007A), size: 16),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _buildSettingItem(Icons.settings, "Video player settings", () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const VideoPlayerSettingsScreen()));
            }),
            _buildSettingItem(Icons.share, "Share the App", () {
              Share.share("Check out TakTak TV app for amazing short dramas!");
            }),
            _buildSettingItem(Icons.privacy_tip_outlined, "Privacy Policy", () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const StaticContentScreen(
                    title: "Privacy Policy",
                    contentType: "privacy",
                  ),
                ),
              );
            }),
            _buildSettingItem(Icons.description_outlined, "Terms & Conditions", () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const StaticContentScreen(
                    title: "Terms & Conditions",
                    contentType: "terms",
                  ),
                ),
              );
            }),
            _buildSettingItem(Icons.mail_outline, "Contact Us", () {
              _showContactUsModal();
            }),
            _buildSettingItem(Icons.restore, "Restore Purchase", () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=>const SubscriptionPaywallScreen(token: '')));
            }),
            _buildSettingItem(Icons.logout, "Logout", _handleLogout),
            _buildSettingItem(Icons.delete_outline, "Delete Account", () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    backgroundColor: Colors.grey[900],
                    title: const Text(
                      "Delete Account",
                      style: TextStyle(color: Colors.white),
                    ),
                    content: const Text(
                      "Are you sure you want to delete your account? All your data will be permanently lost.",
                      style: TextStyle(color: Colors.grey),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel", style: TextStyle(color: Colors.white)),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _processAccountDeletion(context);
                        },
                        child: const Text("Delete", style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  );
                },
              );
            }),
            _buildSettingItem(Icons.info_outline, "About Us", () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const StaticContentScreen(
                    title: "About Us",
                    contentType: "about",
                  ),
                ),
              );
            }, trailing: const Text("V1.2.8", style: TextStyle(color: Color(0xFFE6007A), fontSize: 13))),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem(IconData icon, String title, VoidCallback onTap, {Widget? trailing}) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: Colors.white, size: 22),
          title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
          trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: onTap,
        ),
        const Divider(color: Color(0xFF1E172B), height: 1),
      ],
    );
  }
}