import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../api/api_service.dart';
import '../screens/reels_screen.dart' show CommentsSheet;
import 'feed_video_player.dart'; // We'll move this too

class PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final int index;
  final Map<String, dynamic>? currentUser;
  final bool isActive;
  final Function() onLike;
  final Function() onDelete;

  const PostCard({
    super.key,
    required this.post,
    required this.index,
    required this.currentUser,
    required this.isActive,
    required this.onLike,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final author = Map<String, dynamic>.from(post['author'] ?? {});
    final avatarUrl = ApiService.getAvatar(author);
    final isLiked = post['isLiked'] ?? false;
    final likesCount = post['likesCount'] ?? 0;
    final commentsCount = post['commentsCount'] ?? 0;
    final isOwner = author['_id'] == currentUser?['_id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      color: const Color(0xFF1a1a1a),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          ListTile(
            leading: CircleAvatar(backgroundImage: CachedNetworkImageProvider(avatarUrl)),
            title: Text(author['username'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: post['location'] != null && post['location'].toString().isNotEmpty
                ? Text('📍 ${post['location']}', style: const TextStyle(fontSize: 11))
                : null,
            trailing: isOwner
                ? IconButton(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: const Color(0xFF1e1e1e),
                        title: const Text('Delete post?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                          TextButton(onPressed: () { Navigator.pop(context); onDelete(); },
                              child: const Text('Delete', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    ),
                  )
                : null,
          ),

          // Media
          if (post['image'] != null && post['image'].toString().isNotEmpty)
            CachedNetworkImage(
              imageUrl: ApiService.getFullUrl(post['image']),
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(height: 300, color: const Color(0xFF262626)),
              errorWidget: (_, __, ___) => Container(height: 300, color: const Color(0xFF262626),
                  child: const Icon(Icons.broken_image, color: Colors.grey)),
            )
          else if (post['video'] != null && post['video'].toString().isNotEmpty)
            FeedVideoPlayer(
              url: ApiService.getFullUrl(post['video']),
              isActive: isActive,
            ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onLike,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.red : Colors.white,
                      size: 26,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => showModalBottomSheet(
                    context: context,
                    backgroundColor: const Color(0xFF1e1e1e),
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                    builder: (_) => CommentsSheet(postId: post['_id']),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.chat_bubble_outline, color: Colors.white, size: 26),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.send_outlined, color: Colors.white, size: 26),
                ),
                const Spacer(),
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.bookmark_border, color: Colors.white, size: 26),
                ),
              ],
            ),
          ),

          // Likes & Caption
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (likesCount > 0)
                  Text('$likesCount ${likesCount == 1 ? 'like' : 'likes'}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                if (post['caption'] != null && post['caption'].toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  RichText(text: TextSpan(children: [
                    TextSpan(text: '${author['username'] ?? ''} ',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    TextSpan(text: post['caption'] ?? '', style: const TextStyle(fontSize: 13)),
                  ])),
                ],
                if (commentsCount > 0) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => showModalBottomSheet(
                      context: context,
                      backgroundColor: const Color(0xFF1e1e1e),
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                      builder: (_) => CommentsSheet(postId: post['_id']),
                    ),
                    child: Text('View all $commentsCount comments',
                        style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
