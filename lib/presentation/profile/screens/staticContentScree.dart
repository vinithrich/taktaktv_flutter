// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import '../../../../core/constants/app_constant.dart'; // Ungaloda app constant path-ah check pannikonga
//
// class StaticContentScreen extends StatefulWidget {
//   final String title;
//   final String endpoint; // e.g., 'settings/privacy-policy'
//
//   const StaticContentScreen({
//     super.key,
//     required this.title,
//     required this.endpoint,
//   });
//
//   @override
//   State<StaticContentScreen> createState() => _StaticContentScreenState();
// }
//
// class _StaticContentScreenState extends State<StaticContentScreen> {
//   bool isLoading = true;
//   String content = "";
//
//   @override
//   void initState() {
//     super.initState();
//     fetchContent();
//   }
//
//   Future<void> fetchContent() async {
//     try {
//       final res = await http.get(Uri.parse('${AppConstants.baseUrl}/${widget.endpoint}'));
//       if (res.statusCode == 200) {
//         final resData = json.decode(res.body);
//         // Backend response structures handle panra mari:
//         setState(() {
//           content = resData['data']?['content'] ??
//               resData['data']?['description'] ??
//               resData['content'] ??
//               resData['message'] ??
//               "No content available.";
//           isLoading = false;
//         });
//       } else {
//         setState(() {
//           content = "Failed to load content from the server.";
//           isLoading = false;
//         });
//       }
//     } catch (e) {
//       setState(() {
//         content = "Error: $e";
//         isLoading = false;
//       });
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFF0B0710),
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         title: Text(
//           widget.title,
//           style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
//         ),
//         iconTheme: const IconThemeData(color: Colors.white),
//       ),
//       body: isLoading
//           ? const Center(
//         child: CircularProgressIndicator(color: Color(0xFFE6007A)),
//       )
//           : SingleChildScrollView(
//         padding: const EdgeInsets.all(16.0),
//         child: Text(
//           content,
//           style: const TextStyle(
//             color: Colors.white70,
//             fontSize: 14,
//             height: 1.5,
//           ),
//         ),
//       ),
//     );
//   }
// }