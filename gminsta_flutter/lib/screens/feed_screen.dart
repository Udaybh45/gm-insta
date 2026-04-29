import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../api/api_service.dart';
import '../app_state.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/post_card.dart';
import 'activity_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<dynamic> posts = [];
  int currentPage = 1;
  int totalPages = 1;
  bool isLoading = false;
  Map<String, dynamic>? currentUser;
  final ScrollController _scrollController = ScrollController();
  int unreadActivityCount = 0;

  @override
  void initState() {
    super.initState();
    _init();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 300) {
        if (!isLoading && currentPage < totalPages) {
          currentPage++;
          _loadFeed();
        }
      }
    });
    activeTabNotifier.addListener(_onTabChange);
  }

  void _onTabChange() {
    if (activeTabNotifier.value == 0) {
      _loadFeed();
    }
    setState(() {});
  }

  Future<void> _init() async {
    currentUser = await ApiService.getUser();
    await _loadCurrentUserDetails();
    await _loadActivityCount();
    await _loadFeed();
  }

  Future<void> _loadActivityCount() async {
    try {
      final data = await ApiService.get('/users/activity');
      final reqs = (data['requests'] as List?)?.length ?? 0;
      final likes = (data['likes'] as List?)?.length ?? 0;
      final total = reqs + likes;
      if (mounted) {
        setState(() {
          unreadActivityCount = total;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadCurrentUserDetails() async {
    if (currentUser?['username'] == null) return;
    try {
      final userResponse = await ApiService.get('/users/${currentUser!['username']}');
      setState(() {
        currentUser = userResponse;
      });
    } catch (_) {}
  }

  Future<void> _loadFeed() async {
    if (isLoading) return;
    setState(() => isLoading = true);
    try {
      final data = await ApiService.get('/posts/feed?page=$currentPage');
      setState(() {
        if (currentPage == 1) posts.clear();
        posts.addAll(data['posts']);
        totalPages = data['pages'];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
    setState(() => isLoading = false);
  }

  Future<void> _toggleLike(int index) async {
    final postId = posts[index]['_id'];
    try {
      final data = await ApiService.post('/posts/$postId/like');
      setState(() {
        posts[index]['likesCount'] = data['likesCount'];
        posts[index]['isLiked'] = data['liked'];
      });
    } catch (e) {
      debugPrint('Like error: $e');
    }
  }

  Future<void> _deletePost(int index) async {
    final postId = posts[index]['_id'];
    try {
      await ApiService.delete('/posts/$postId');
      setState(() => posts.removeAt(index));
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Post deleted')));
    } catch (e) {}
  }

  void _showCreatePost() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1e1e1e),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CreatePostSheet(
        onPostCreated: (post) {
          setState(() => posts.insert(0, post));
        },
      ),
    );
  }

  @override
  void dispose() {
    activeTabNotifier.removeListener(_onTabChange);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          'GMinsta',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.favorite_border),
                if (unreadActivityCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE1306C),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 8,
                        minHeight: 8,
                      ),
                    ),
                  )
              ],
            ),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivityScreen()));
              _loadActivityCount();
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            onPressed: _showCreatePost,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFFE1306C),
        onRefresh: () async {
          currentPage = 1;
          await _loadCurrentUserDetails();
          await _loadActivityCount();
          await _loadFeed();
        },
        child: posts.isEmpty && isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFE1306C)),
              )
            : posts.isEmpty
            ? const Center(
                child: Text(
                  'No posts yet.\nFollow people to see their posts!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              )
            : ListView.builder(
                controller: _scrollController,
                itemCount: posts.length + (isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == posts.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                          color: Color(0xFFE1306C),
                        ),
                      ),
                    );
                  }
                  return PostCard(
                    post: posts[index],
                    index: index,
                    currentUser: currentUser,
                    isActive: activeTabNotifier.value == 0,
                    onLike: () => _toggleLike(index),
                    onDelete: () => _deletePost(index),
                  );
                },
              ),
      ),
    );
  }
}

// Create Post sheet
class CreatePostSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onPostCreated;
  const CreatePostSheet({super.key, required this.onPostCreated});
  @override
  State<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<CreatePostSheet> {
  final _captionCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isReel = false;
  PlatformFile? _pickedFile;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'mp4', 'mov', 'avi'],
      withData: true,
    );
    if (result != null) {
      setState(() => _pickedFile = result.files.first);
    }
  }

  Future<void> _submit() async {
    if (_pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a photo or video before posting'),
        ),
      );
      return;
    }

    if (_isReel) {
      final ext = _pickedFile!.name.toLowerCase();
      if (!ext.endsWith('.mp4') && !ext.endsWith('.mov') && !ext.endsWith('.avi') && !ext.endsWith('.webm')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reels must be a video file (.mp4, .mov, etc)'),
            backgroundColor: Color(0xFFE1306C),
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final post = await ApiService.createPost(
        caption: _captionCtrl.text.trim(),
        location: _locationCtrl.text.isNotEmpty
            ? _locationCtrl.text.trim()
            : null,
        isReel: _isReel,
        mediaBytes: _pickedFile?.bytes,
        filename: _pickedFile?.name,
      );
      if (mounted) {
        widget.onPostCreated(post);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post shared!'),
            backgroundColor: Color(0xFFE1306C),
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Create Post',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              GestureDetector(
                onTap: _pickFile,
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2a2a2a),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _pickedFile != null
                          ? const Color(0xFFE1306C)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: _pickedFile == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 40,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Select Photo or Video',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        )
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            if (_pickedFile!.name.toLowerCase().endsWith(
                                  '.mp4',
                                ) ||
                                _pickedFile!.name.toLowerCase().endsWith(
                                  '.mov',
                                ))
                              const Center(
                                child: Icon(
                                  Icons.videocam,
                                  size: 40,
                                  color: Color(0xFFE1306C),
                                ),
                              )
                            else
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(
                                  _pickedFile!.bytes!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () => setState(() => _pickedFile = null),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _captionCtrl,
                maxLines: 2,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Write a caption...',
                  hintStyle: TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Color(0xFF2a2a2a),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _locationCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: '📍 Add location',
                  hintStyle: TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Color(0xFF2a2a2a),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              SwitchListTile(
                title: const Text(
                  'Post as Reel',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: const Text(
                  'Reels appear in the Reels tab',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
                value: _isReel,
                activeThumbColor: const Color(0xFFE1306C),
                onChanged: (v) => setState(() => _isReel = v),
                contentPadding: EdgeInsets.zero,
              ),

              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE1306C),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Share',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
