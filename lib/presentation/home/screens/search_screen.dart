import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/constants/app_constant.dart';
import 'package:taktaktv/presentation/player/screens/player_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  List searchResults = [];
  List recommendedDramas = [];
  List categoriesList = [];

  bool isSearching = false;
  bool isLoadingRecommended = true;
  bool isLoadingCategories = true;
  bool isCategoryLoading = false;

  String? selectedCategorySlug;
  String selectedCategoryTitle = 'Recommended For You';

  // Pagination variables
  int currentPage = 1;
  int itemsPerPage = 15; // Oruthavana oru page-ku 15 series mattum
  int totalCategoryItems = 0;
  int totalPages = 1;

  @override
  void initState() {
    super.initState();
    fetchRecommendedDramas();
    fetchCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 1. Fetch Categories from Backend API
  Future<void> fetchCategories() async {
    try {
      final res = await http.get(Uri.parse('${AppConstants.baseUrl}/categories'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (mounted) {
          setState(() {
            categoriesList = data['data'] ?? [];
            isLoadingCategories = false;
          });
        }
      } else {
        if (mounted) setState(() => isLoadingCategories = false);
      }
    } catch (e) {
      debugPrint("Categories fetch error: $e");
      if (mounted) setState(() => isLoadingCategories = false);
    }
  }

  // 2. Fetch Dramas by Category Slug with specific page & limit=15
  Future<void> fetchDramasByCategory(String slug, String categoryName, int page) async {
    setState(() {
      isCategoryLoading = true;
      selectedCategorySlug = slug;
      selectedCategoryTitle = categoryName;
      currentPage = page;
      _searchController.clear();
    });

    try {
      final res = await http.get(Uri.parse('${AppConstants.baseUrl}/categories/$slug/dramas?page=$page&limit=$itemsPerPage'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final dramaData = data['data'];

        List fetchedDramas = [];
        int totalCount = 0;
        int backendTotalPages = 1;

        if (dramaData is Map) {
          fetchedDramas = dramaData['dramas'] ?? [];
        } else if (dramaData is List) {
          fetchedDramas = dramaData;
        }

        // Pagination metadata handling
        if (data['pagination'] != null) {
          totalCount = data['pagination']['total'] ?? fetchedDramas.length;
          backendTotalPages = data['pagination']['totalPages'] ?? ((totalCount / itemsPerPage).ceil());
        } else {
          totalCount = fetchedDramas.length;
          backendTotalPages = (totalCount / itemsPerPage).ceil();
        }

        if (mounted) {
          setState(() {
            searchResults = fetchedDramas;
            totalCategoryItems = totalCount;
            totalPages = backendTotalPages > 0 ? backendTotalPages : 1;
            selectedCategoryTitle = "$categoryName ($totalCount)";
            isCategoryLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => isCategoryLoading = false);
      }
    } catch (e) {
      debugPrint("Category dramas fetch error: $e");
      if (mounted) setState(() => isCategoryLoading = false);
    }
  }

  Future<void> fetchRecommendedDramas() async {
    try {
      final res = await http.get(Uri.parse('${AppConstants.baseUrl}/dramas/recommended'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (mounted) {
          setState(() {
            recommendedDramas = data['data'] ?? [];
            isLoadingRecommended = false;
          });
        }
      } else {
        if (mounted) setState(() => isLoadingRecommended = false);
      }
    } catch (e) {
      if (mounted) setState(() => isLoadingRecommended = false);
    }
  }

  Future<void> performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        searchResults = [];
        isSearching = false;
        selectedCategorySlug = null;
        selectedCategoryTitle = 'Recommended For You';
      });
      return;
    }

    setState(() {
      isSearching = true;
      selectedCategorySlug = null;
      selectedCategoryTitle = 'Search Results';
    });

    try {
      final res = await http.get(Uri.parse('${AppConstants.baseUrl}/search?q=$query'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (mounted) {
          setState(() {
            searchResults = data['data'] ?? [];
            isSearching = false;
          });
        }
      } else {
        if (mounted) setState(() => isSearching = false);
      }
    } catch (e) {
      debugPrint("Search error: $e");
      if (mounted) setState(() => isSearching = false);
    }
  }

  Future<void> playDrama(String dramaId, String title) async {
    try {
      final playUrl = '${AppConstants.baseUrl}/dramas/$dramaId/episodes/1/play';
      final res = await http.get(Uri.parse(playUrl));
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
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Play error: $e");
    }
  }

  // Widget to build Pagination Bar (1, 2, 3...)
  Widget _buildPaginationControls() {
    if (selectedCategorySlug == null || totalPages <= 1) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: totalPages,
        itemBuilder: (context, index) {
          final pageNum = index + 1;
          final isSelected = currentPage == pageNum;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () {
                if (!isCategoryLoading) {
                  fetchDramasByCategory(selectedCategorySlug!, selectedCategoryTitle.split(' (').first, pageNum);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFE6007A) : const Color(0xFF140F1D),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFE6007A) : Colors.grey.withOpacity(0.3),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$pageNum',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isTypingOrFiltered = _searchController.text.trim().isNotEmpty || selectedCategorySlug != null;
    final displayList = isTypingOrFiltered ? searchResults : recommendedDramas;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0710),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Container(

          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF140F1D),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: TextField(
            controller: _searchController,
            autofocus: false,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Search on Story TV',
              hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
              prefixIcon: Icon(Icons.search, color: Colors.grey, size: 20),

              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
            onChanged: (val) => performSearch(val),

          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trending Categories',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            isLoadingCategories
                ? const SizedBox(
              height: 40,
              child: Center(child: CircularProgressIndicator(color: Color(0xFFE6007A), strokeWidth: 2)),
            )
                : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categoriesList.map((category) {
                final name = category['name'] ?? '';
                final slug = category['slug'] ?? '';
                final isSelected = selectedCategorySlug == slug;

                return ActionChip(
                  backgroundColor: isSelected ? const Color(0xFFE6007A) : const Color(0xFF140F1D),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFFE6007A) : Colors.grey.withOpacity(0.3),
                  ),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? Icons.check : Icons.local_fire_department_rounded,
                        color: isSelected ? Colors.white : Colors.grey,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        name,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  onPressed: () {
                    if (isSelected) {
                      setState(() {
                        selectedCategorySlug = null;
                        selectedCategoryTitle = 'Recommended For You';
                        searchResults = [];
                      });
                    } else {
                      fetchDramasByCategory(slug, name, 1); // Click pannum pothu page 1-ku load aagum
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    selectedCategoryTitle,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (selectedCategorySlug != null || _searchController.text.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        selectedCategorySlug = null;
                        selectedCategoryTitle = 'Recommended For You';
                        _searchController.clear();
                        searchResults = [];
                      });
                    },
                    child: const Text('Clear Filter', style: TextStyle(color: Color(0xFFE6007A), fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            isSearching || isLoadingRecommended || isCategoryLoading
                ? const Center(
              child: Padding(
                padding: EdgeInsets.all(40.0),
                child: CircularProgressIndicator(color: Color(0xFFE6007A)),
              ),
            )
                : displayList.isEmpty
                ? const Center(
              child: Padding(
                padding: EdgeInsets.all(40.0),
                child: Text('No dramas found in this category', style: TextStyle(color: Colors.grey)),
              ),
            )
                : Column(
              children: [
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: displayList.length,
                  itemBuilder: (context, index) {
                    final drama = displayList[index];
                    final id = drama['_id'] ?? drama['id'] ?? '';
                    final title = drama['title'] ?? '';
                    final coverUrl = drama['coverUrl'] ?? drama['imageUrl'] ?? '';

                    return GestureDetector(
                      onTap: () => playDrama(id, title),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                coverUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (_, __, ___) => Container(color: Colors.grey[900]),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                // Keezhe Page Numbers (1, 2, 3...) bar kaattum
                _buildPaginationControls(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}