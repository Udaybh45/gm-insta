import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../api/api_service.dart';
import '../widgets/post_card.dart';
import 'profile_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  List<dynamic> posts = [];
  List<dynamic> searchResults = [];
  bool isLoading = true;
  bool isSearching = false;
  int currentPage = 1;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (!isLoading && !isSearching) {
          currentPage++;
          _load();
        }
      }
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isEmpty) {
        setState(() {
          isSearching = false;
          searchResults.clear();
        });
      } else {
        _performSearch(query);
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => isSearching = true);
    try {
      final data = await ApiService.get('/users/search?q=$query');
      setState(() {
        searchResults = data;
      });
    } catch (e) {
      debugPrint('Search error: $e');
    }
  }

  Future<void> _load() async {
    setState(() => isLoading = true);
    try {
      final data = await ApiService.get('/posts/explore?page=$currentPage');
      setState(() {
        if (currentPage == 1) posts.clear();
        posts.addAll(data['posts']);
        isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _openPost(Map<String, dynamic> post) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Explore')),
        body: SingleChildScrollView(
          child: PostCard(
            post: post,
            index: 0,
            currentUser: null,
            isActive: true,
            onLike: () async {
              final d = await ApiService.post('/posts/${post['_id']}/like');
              setState(() {
                post['isLiked'] = d['liked'];
                post['likesCount'] = d['likesCount'];
              });
            },
            onDelete: () {},
          ),
        ),
      ),
    ));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Container(
          height: 40,
          decoration: BoxDecoration(color: const Color(0xFF262626), borderRadius: BorderRadius.circular(10)),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search Users',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 15),
              prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
              suffixIcon: isSearching ? IconButton(
                icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                onPressed: () {
                  _searchController.clear();
                  _onSearchChanged('');
                },
              ) : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.only(top: 8),
            ),
          ),
        ),
      ),
      body: isSearching
          ? ListView.builder(
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                final user = searchResults[index];
                final avatarUrl = ApiService.getAvatar(Map<String, dynamic>.from(user));
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: CachedNetworkImageProvider(avatarUrl),
                    radius: 20,
                  ),
                  title: Text(user['username'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  subtitle: Text(user['fullName'] ?? '', style: const TextStyle(color: Colors.grey)),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ProfileScreen(username: user['username']),
                    ));
                  },
                );
              },
            )
          : RefreshIndicator(
        onRefresh: () async { currentPage = 1; await _load(); },
        child: posts.isEmpty && isLoading
            ? const Center(child: CircularProgressIndicator())
            : GridView.builder(
                controller: _scrollController,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 1,
                  mainAxisSpacing: 1,
                ),
                itemCount: posts.length,
                itemBuilder: (context, i) {
                  final post = posts[i];
                  final isVideo = post['video'] != null && post['video'].toString().isNotEmpty;
                  
                  // Use image thumbnail if available, or a placeholder for videos.
                  final String? mediaPath = isVideo ? post['image'] : (post['image'] ?? post['video']);
                  final String mediaUrl = ApiService.getFullUrl(mediaPath);

                  return GestureDetector(
                    onTap: () => _openPost(post),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (mediaUrl.isNotEmpty && (!isVideo || (isVideo && post['image'] != null)))
                          CachedNetworkImage(
                            imageUrl: mediaUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: const Color(0xFF262626)),
                            errorWidget: (_, __, ___) => Container(
                                color: const Color(0xFF262626),
                                child: const Center(child: Icon(Icons.error_outline, color: Colors.grey, size: 20))),
                          )
                        else
                          Container(
                            color: const Color(0xFF262626),
                            child: isVideo 
                              ? const Center(child: Icon(Icons.play_arrow_rounded, color: Colors.white24, size: 36))
                              : null,
                          ),
                        
                        // Video indicator icon on top right
                        if (isVideo)
                          const Positioned(
                            top: 6, right: 6,
                            child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 16)
                          ),
                        
                        // Ink overlay for touch effect
                        Positioned.fill(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _openPost(post),
                              splashColor: Colors.white.withOpacity(0.1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
