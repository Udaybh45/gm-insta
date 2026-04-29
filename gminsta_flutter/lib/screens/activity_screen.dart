import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../api/api_service.dart';
import 'profile_screen.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  bool isLoading = true;
  List<dynamic> followRequests = [];
  List<dynamic> likes = [];

  @override
  void initState() {
    super.initState();
    _loadActivity();
  }

  Future<void> _loadActivity() async {
    try {
      final data = await ApiService.get('/users/activity');
      setState(() {
        followRequests = data['requests'] ?? [];
        likes = data['likes'] ?? [];
        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load activity')),
        );
      }
    }
  }

  Future<void> _handleRequest(String userId, String action) async {
    try {
      await ApiService.post('/users/requests/$userId/$action');
      setState(() {
        followRequests.removeWhere((u) => u['_id'] == userId);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF121212),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE1306C)))
          : (followRequests.isEmpty && likes.isEmpty)
              ? const Center(
                  child: Text('No new notifications', style: TextStyle(color: Colors.grey)),
                )
              : ListView(
                  children: [
                    if (followRequests.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(
                          'Follow Requests',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      ...followRequests.map((reqUser) => _buildRequestItem(reqUser)).toList(),
                      const Divider(color: Color(0xFF262626)),
                    ],
                    if (likes.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(
                          'Recent Activity',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      ...likes.map((like) => _buildLikeItem(like)).toList(),
                    ],
                  ],
                ),
    );
  }

  Widget _buildRequestItem(dynamic reqUser) {
    return ListTile(
      leading: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(username: reqUser['username']))),
        child: Stack(
          children: [
            CircleAvatar(
              backgroundImage: CachedNetworkImageProvider(ApiService.getAvatar(reqUser)),
              radius: 22,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Color(0xFF007AFF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_add, color: Colors.white, size: 12),
              ),
            ),
          ],
        ),
      ),
      title: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(username: reqUser['username']))),
        child: Text(reqUser['username'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      subtitle: const Text('Requested to follow you', style: TextStyle(color: Colors.grey)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: () => _handleRequest(reqUser['_id'], 'accept'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              minimumSize: const Size(0, 32),
            ),
            child: const Text('Confirm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => _handleRequest(reqUser['_id'], 'reject'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF444444)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              minimumSize: const Size(0, 32),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildLikeItem(dynamic like) {
    final user = like['user'];
    final postImage = like['postImage'];
    final isVideo = postImage != null && (postImage.toString().endsWith('.mp4') || postImage.toString().endsWith('.mov') || postImage.toString().endsWith('.avi'));
    
    return ListTile(
      leading: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(username: user['username']))),
        child: Stack(
          children: [
            CircleAvatar(
              backgroundImage: CachedNetworkImageProvider(ApiService.getAvatar(user)),
              radius: 22,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Color(0xFFE1306C),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite, color: Colors.white, size: 12),
              ),
            ),
          ],
        ),
      ),
      title: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(username: user['username']))),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(text: '${user['username']} ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              const TextSpan(text: 'liked your post.', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
      trailing: postImage != null && postImage.toString().isNotEmpty
          ? Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(color: Color(0xFF262626)),
              child: isVideo
                  ? const Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(Icons.movie_outlined, color: Colors.white38, size: 28),
                        Icon(Icons.play_arrow, color: Colors.white, size: 20),
                      ],
                    )
                  : CachedNetworkImage(
                      imageUrl: ApiService.getFullUrl(postImage),
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: const Color(0xFF262626)),
                      errorWidget: (context, url, err) => const Icon(Icons.error, color: Colors.grey),
                    ),
            )
          : const SizedBox(),
    );
  }
}
