import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../api/api_service.dart';
import '../app_state.dart';
import 'profile_screen.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});
  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  List<dynamic> reels = [];
  bool isLoading = true;
  int currentPage = 1;
  int totalPages = 1;
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _isGlobalMuted = true;


  @override
  void initState() {
    super.initState();
    _loadReels();
    activeTabNotifier.addListener(_onTabChange);
    _pageController.addListener(() {
      final idx = _pageController.page?.round() ?? 0;
      if (idx != _currentIndex) {
        setState(() => _currentIndex = idx);
      }
    });
  }

  void _onTabChange() {
    // When switching away from Reels tab (index 1), the current reel will auto-pause
    // because ReelPlayer checks isActive
    setState(() {});
  }

  @override
  void dispose() {
    activeTabNotifier.removeListener(_onTabChange);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadReels({int page = 1}) async {
    try {
      final data = await ApiService.get('/posts/reels?page=$page');
      setState(() {
        if (page == 1) reels.clear();
        reels.addAll(data['reels']);
        totalPages = data['pages'];
        currentPage = data['page'];
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _launchInstagram() async {
    final Uri url = Uri.parse("https://www.instagram.com/reels/");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Instagram Reels')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (reels.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text('No Reels yet', style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: reels.length + (currentPage < totalPages ? 1 : 0),
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              if (index >= reels.length - 2 && currentPage < totalPages) {
                _loadReels(page: currentPage + 1);
              }
            },
            itemBuilder: (context, index) {
              if (index >= reels.length) {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              }
              return ReelPlayer(
                key: ValueKey(reels[index]['_id']),
                reelData: reels[index],
                isActive: _currentIndex == index && activeTabNotifier.value == 2,
                isMuted: _isGlobalMuted,
                onLikeChanged: (postId, liked, count) {
                  setState(() {
                    reels[index]['likesCount'] = count;
                    reels[index]['isLiked'] = liked;
                  });
                },
              );
            },
          ),
          // Top header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Reels',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 8)])),
                  Row(
                    children: [
                      const SizedBox(width: 16),

                      IconButton(
                        icon: Icon(_isGlobalMuted ? Icons.volume_off : Icons.volume_up, color: Colors.white, size: 28),
                        onPressed: () {
                          setState(() => _isGlobalMuted = !_isGlobalMuted);
                          // This will notify all players via building
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.video_library, color: Colors.white, size: 28),

                        tooltip: 'Go to real Instagram Reels',
                        onPressed: _launchInstagram,
                      ),
                    ],
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

class ReelPlayer extends StatefulWidget {
  final Map<String, dynamic> reelData;
  final bool isActive;
  final bool isMuted;
  final Function(String postId, bool liked, int count) onLikeChanged;

  const ReelPlayer({
    super.key,
    required this.reelData,
    required this.isActive,
    required this.isMuted,
    required this.onLikeChanged,
  });


  @override
  State<ReelPlayer> createState() => _ReelPlayerState();
}

class _ReelPlayerState extends State<ReelPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _isMuted = true;
  bool _isLiked = false;
  int _likesCount = 0;
  int _commentsCount = 0;
  bool _showPlayPause = false;

  @override
  void initState() {
    super.initState();
    _likesCount = widget.reelData['likesCount'] ?? 0;
    _commentsCount = widget.reelData['commentsCount'] ?? 0;
    _isLiked = widget.reelData['isLiked'] ?? false;
    final videoUrl = ApiService.getFullUrl(widget.reelData['video']);
    _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _controller.setVolume(0); // muted by default
          _controller.setLooping(true);
          if (widget.isActive) _controller.play();
        }
      });
  }

  @override
  void didUpdateWidget(ReelPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.play();
      } else {
        _controller.pause();
      }
    }
    if (widget.isMuted != oldWidget.isMuted) {
      _controller.setVolume(widget.isMuted ? 0 : 1);
    }
  }


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _showPlayPause = true; // reusing this for the mute icon too
    });
    _controller.setVolume(_isMuted ? 0 : 1);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showPlayPause = false);
    });
  }


  void _togglePlayPause() {
    setState(() => _showPlayPause = true);
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showPlayPause = false);
    });
  }

  Future<void> _toggleLike() async {
    try {
      final data = await ApiService.post('/posts/${widget.reelData['_id']}/like');
      setState(() {
        _isLiked = data['liked'];
        _likesCount = data['likesCount'];
      });
      widget.onLikeChanged(widget.reelData['_id'], _isLiked, _likesCount);
    } catch (e) {
      debugPrint('Like error: $e');
    }
  }

  void _showComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1e1e1e),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => CommentsSheet(postId: widget.reelData['_id']),
    );
  }

  @override
  Widget build(BuildContext context) {
    final author = Map<String, dynamic>.from(widget.reelData['author'] ?? {});
    final avatarUrl = ApiService.getAvatar(author);
    final username = author['username'] ?? '';
    final caption = widget.reelData['caption'] ?? '';

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video
        GestureDetector(
          onTap: _toggleMute,
          onDoubleTap: _toggleLike,
          onLongPress: _togglePlayPause,
          child: _initialized

              ? SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller.value.size.width,
                      height: _controller.value.size.height,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                )
              : const Center(child: CircularProgressIndicator(color: Colors.white)),
        ),

        // Mute/Play/Pause overlay
        if (_showPlayPause)
          Center(
            child: AnimatedOpacity(
              opacity: _showPlayPause ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                child: Icon(
                  _controller.value.isPlaying 
                    ? (_isMuted ? Icons.volume_off : Icons.volume_up)
                    : Icons.pause,
                  color: Colors.white, size: 48,
                ),
              ),
            ),
          ),


        // Search bar or top header space
        // (Removed individual mute button)



        // Right side action buttons
        Positioned(
          right: 12, bottom: 100,
          child: Column(
            children: [
              // Like
              _ActionBtn(
                icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                color: _isLiked ? Colors.red : Colors.white,
                count: _likesCount,
                onTap: _toggleLike,
              ),
              const SizedBox(height: 20),
              // Comment
              _ActionBtn(
                icon: Icons.chat_bubble_outline,
                color: Colors.white,
                count: _commentsCount,
                onTap: () => _showComments(context),
              ),
              const SizedBox(height: 20),
              // Share
              _ActionBtn(icon: Icons.share_outlined, color: Colors.white, onTap: () {}),
            ],
          ),
        ),

        // Bottom overlay (user info)
        Positioned(
          left: 12, right: 80, bottom: 90,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  if (username.isNotEmpty) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(username: username)));
                  }
                },
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: CachedNetworkImageProvider(avatarUrl),
                    ),
                    const SizedBox(width: 8),
                    Text('@$username',
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold, fontSize: 15,
                            shadows: [Shadow(color: Colors.black54, blurRadius: 6)])),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white70),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Follow', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              if (caption.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(caption,
                    style: const TextStyle(color: Colors.white, fontSize: 13,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 6)]),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int? count;
  final VoidCallback onTap;

  const _ActionBtn({required this.icon, required this.color, this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 32,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 8)]),
          if (count != null) ...[
            const SizedBox(height: 2),
            Text('$count', style: const TextStyle(color: Colors.white, fontSize: 12,
                shadows: [Shadow(color: Colors.black54, blurRadius: 8)])),
          ],
        ],
      ),
    );
  }
}

// Comments bottom sheet
class CommentsSheet extends StatefulWidget {
  final String postId;
  const CommentsSheet({super.key, required this.postId});
  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  List<dynamic> comments = [];
  bool loading = true;
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.get('/comments/${widget.postId}');
      setState(() { comments = data; loading = false; });
    } catch (e) {
      setState(() => loading = false);
    }
  }

  Future<void> _postComment() async {
    final content = _ctrl.text.trim();
    if (content.isEmpty) return;
    try {
      final c = await ApiService.post('/comments/${widget.postId}', body: {'content': content});
      setState(() { comments.add(c); });
      _ctrl.clear();
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2))),
          const Text('Comments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(color: Color(0xFF333333)),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : comments.isEmpty
                    ? const Center(child: Text('No comments yet', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: comments.length,
                        itemBuilder: (_, i) {
                          final c = comments[i];
                          final author = c['author'] ?? {};
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: NetworkImage(ApiService.getAvatar(Map<String, dynamic>.from(author))),
                              radius: 16,
                            ),
                            title: RichText(text: TextSpan(children: [
                              TextSpan(text: '${author['username'] ?? ''} ', style: const TextStyle(fontWeight: FontWeight.bold)),
                              TextSpan(text: c['content'] ?? ''),
                            ])),
                            contentPadding: EdgeInsets.zero,
                          );
                        },
                      ),
          ),
          Padding(
            padding: EdgeInsets.only(left: 12, right: 12, bottom: MediaQuery.of(context).viewInsets.bottom + 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle: TextStyle(color: Colors.grey),
                      filled: true, fillColor: Color(0xFF2a2a2a),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24)), borderSide: BorderSide.none),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _postComment,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(color: Color(0xFFE1306C), shape: BoxShape.circle),
                    child: const Icon(Icons.send, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
