import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:file_picker/file_picker.dart';
import '../api/api_service.dart';

import '../app_state.dart';
import 'login_screen.dart';
import 'reels_screen.dart' show CommentsSheet;
import '../widgets/feed_video_player.dart';

class ProfileScreen extends StatefulWidget {
  final String? username;
  const ProfileScreen({super.key, this.username});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? profileData;
  Map<String, dynamic>? currentUser;
  List<dynamic> allPosts = [];
  bool isLoading = true;
  bool isFollowing = false;
  bool isRequested = false;
  bool isOwnProfile = false;
  late TabController _tabController;
  String _currentTab = 'posts'; // 'posts' or 'reels'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          if (_tabController.index == 0) {
            _currentTab = 'posts';
          } else if (_tabController.index == 1)
            _currentTab = 'reels';
          else
            _currentTab = 'liked';
        });
      }
    });

    activeTabNotifier.addListener(_onTabChange);
    _load();
  }

  void _onTabChange() {
    // If we just switched to this tab (index 4), reload profile
    if (activeTabNotifier.value == 4 && widget.username == null) {
      _load();
    }
  }

  @override
  void dispose() {
    activeTabNotifier.removeListener(_onTabChange);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      isLoading = true;
    });
    currentUser = await ApiService.getUser();
    final username = widget.username ?? currentUser?['username'];
    if (username == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final userFuture = ApiService.get('/users/$username');
      final postsFuture = ApiService.get('/users/$username/posts');
      final results = await Future.wait([userFuture, postsFuture]);
      final user = results[0];
      final posts = results[1];

      setState(() {
        profileData = Map<String, dynamic>.from(user);
        allPosts = posts is List ? posts : [];
        isOwnProfile = user['_id'] == currentUser?['_id'];
        isFollowing =
            (user['followers'] as List?)?.any(
              (f) => (f['_id'] ?? f) == currentUser?['_id'],
            ) ??
            false;
        isRequested = 
            (user['followRequests'] as List?)?.any(
              (f) => (f['_id'] ?? f) == currentUser?['_id'],
            ) ??
            false;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (profileData == null) return;
    try {
      final data = await ApiService.post(
        '/users/${profileData!['_id']}/follow',
      );
      setState(() {
        isFollowing = data['following'];
        if (data.containsKey('requested')) {
          isRequested = data['requested'];
        }
      });
      _load(); // refresh follower count
    } catch (e) {}
  }

  void _showFollowersList(String type) {
    final list = type == 'Followers'
        ? profileData!['followers']
        : profileData!['following'];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1e1e1e),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _UserListSheet(title: type, users: List.from(list ?? [])),
    );
  }

  void _openEditProfile() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1e1e1e),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditProfileSheet(
        currentProfile: profileData!,
        onSaved: (updated) {
          setState(() => profileData = updated);
          _load();
        },
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1e1e1e),
        title: const Text('Log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ApiService.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  void _openPostDetail(Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1e1e1e),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PostDetailSheet(post: post, currentUser: currentUser),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFE1306C)),
        ),
      );
    }

    if (profileData == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(
          child: Text(
            'Profile not found',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final avatarUrl = ApiService.getAvatar(profileData!);
    final followers = (profileData!['followers'] as List?)?.length ?? 0;
    final following = (profileData!['following'] as List?)?.length ?? 0;
    final postsCount = profileData!['postsCount'] ?? 0;
    final isPrivate = profileData!['isPrivate'] == true;
    final isPrivateHidden = isPrivate && !isOwnProfile && !isFollowing;

    final postsTab = allPosts
        .where(
          (p) =>
              (p['video'] == null || p['video'].toString().isEmpty) &&
              p['isReel'] != true,
        )
        .toList();
    final reelsTab = allPosts
        .where(
          (p) =>
              (p['video'] != null && p['video'].toString().isNotEmpty) ||
              p['isReel'] == true,
        )
        .toList();
    final likedTab = allPosts.where((p) => p['isLiked'] == true).toList();

    final displayPosts = _currentTab == 'posts'
        ? postsTab
        : (_currentTab == 'reels' ? reelsTab : likedTab);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              profileData!['username'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 6),
            Icon(
              isPrivate ? Icons.lock : Icons.public,
              size: 14,
              color: Colors.grey,
            ),
          ],
        ),
        actions: [
          if (isOwnProfile) ...[
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => showModalBottomSheet(
                context: context,
                backgroundColor: const Color(0xFF1e1e1e),
                builder: (_) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.red),
                      title: const Text(
                        'Log out',
                        style: TextStyle(color: Colors.red),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _logout();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE1306C), Color(0xFFF77737)],
                          ),
                        ),
                        child: CircleAvatar(
                          key: ValueKey(
                            avatarUrl,
                          ), // Force re-render if URL changes
                          radius: 44,
                          backgroundColor: const Color(0xFF262626),
                          backgroundImage: CachedNetworkImageProvider(
                            isOwnProfile
                                ? '$avatarUrl?v=${profileData!['updatedAt'] ?? DateTime.now().millisecondsSinceEpoch}'
                                : avatarUrl,
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Stats
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _StatCol(
                              count: postsCount,
                              label: 'Posts',
                              onTap: null,
                            ),
                            _StatCol(
                              count: followers,
                              label: 'Followers',
                              onTap: !isPrivateHidden
                                  ? () => _showFollowersList('Followers')
                                  : null,
                            ),
                            _StatCol(
                              count: following,
                              label: 'Following',
                              onTap: !isPrivateHidden
                                  ? () => _showFollowersList('Following')
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Name
                  if ((profileData!['fullName'] ?? '').toString().isNotEmpty)
                    Text(
                      profileData!['fullName'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  // Bio
                  if ((profileData!['bio'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      profileData!['bio'],
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                  // Website
                  if ((profileData!['website'] ?? '')
                      .toString()
                      .isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      profileData!['website'],
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF4EA8E8),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),

                  // Action buttons
                  if (isOwnProfile)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _openEditProfile,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF444444)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Edit Profile',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _toggleFollow,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isFollowing
                                  ? const Color(0xFF262626)
                                  : isRequested
                                      ? const Color(0xFF262626)
                                      : const Color(0xFF007AFF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              isFollowing
                                  ? 'Following'
                                  : isRequested
                                      ? 'Requested'
                                      : 'Follow',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF444444)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Message',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                  // Private account banner
                  if (isPrivateHidden) ...[
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1e1e1e),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                        children: [
                          Text('🔒', style: TextStyle(fontSize: 32)),
                          SizedBox(height: 8),
                          Text(
                            'This Account is Private',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Follow to see their posts and reels.',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Tabs (only show if not private hidden)
          if (!isPrivateHidden)
            SliverPersistentHeader(
              delegate: _TabBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.white,
                  indicatorWeight: 1.5,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                  tabs: const [
                    Tab(icon: Icon(Icons.grid_on, size: 22), text: 'POSTS'),
                    Tab(
                      icon: Icon(Icons.video_library_outlined, size: 22),
                      text: 'REELS',
                    ),
                    Tab(
                      icon: Icon(Icons.favorite_border, size: 22),
                      text: 'LIKED',
                    ),
                  ],
                ),
              ),
              pinned: true,
            ),
        ],

        body: isPrivateHidden
            ? const SizedBox()
            : displayPosts.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _currentTab == 'posts'
                          ? Icons.photo_camera_outlined
                          : Icons.video_library_outlined,
                      size: 60,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No ${_currentTab == 'posts' ? 'Posts' : 'Reels'} Yet',
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              )
            : GridView.builder(
                padding: EdgeInsets.zero,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                ),
                itemCount: displayPosts.length,
                itemBuilder: (context, i) {
                  final post = Map<String, dynamic>.from(displayPosts[i]);
                  final isVideo =
                      post['video'] != null &&
                      post['video'].toString().isNotEmpty;

                  // For a premium look, if it's a video, use the image thumbnail if available, or a placeholder
                  final String? mediaPath = isVideo
                      ? post['image']
                      : (post['image'] ?? post['video']);
                  final String mediaUrl = ApiService.getFullUrl(mediaPath);

                  return GestureDetector(
                    onTap: () {
                      if (isVideo) {
                        // If it's a reel, navigate to reels screen or a detail view with video
                        _openPostDetail(post);
                      } else {
                        _openPostDetail(post);
                      }
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (mediaUrl.isNotEmpty &&
                            (!isVideo || (isVideo && post['image'] != null)))
                          CachedNetworkImage(
                            imageUrl: mediaUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: const Color(0xFF262626)),
                            errorWidget: (_, __, ___) => Container(
                              color: const Color(0xFF262626),
                              child: const Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                                size: 20,
                              ),
                            ),
                          )
                        else
                          Container(
                            color: const Color(0xFF262626),
                            child: isVideo
                                ? const Center(
                                    child: Icon(
                                      Icons.play_circle_outline,
                                      color: Colors.white24,
                                      size: 36,
                                    ),
                                  )
                                : null,
                          ),

                        // Video indicator icon on top right
                        if (isVideo)
                          const Positioned(
                            top: 6,
                            right: 6,
                            child: Icon(
                              Icons.play_circle_fill,
                              color: Colors.white70,
                              size: 18,
                            ),
                          ),

                        // Ink overlay for hover/hit effect
                        Positioned.fill(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _openPostDetail(post),
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

// Sticky tab bar delegate
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);
  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  Widget build(context, shrinkOffset, overlapsContent) =>
      Container(color: const Color(0xFF121212), child: tabBar);
  @override
  bool shouldRebuild(_) => false;
}

// Stat column widget
class _StatCol extends StatelessWidget {
  final int count;
  final String label;
  final VoidCallback? onTap;
  const _StatCol({required this.count, required this.label, this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            '$count',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}

// ===== User List (Followers/Following) Bottom Sheet =====
class _UserListSheet extends StatelessWidget {
  final String title;
  final List users;
  const _UserListSheet({required this.title, required this.users});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const Divider(color: Color(0xFF333333)),
          Expanded(
            child: users.isEmpty
                ? const Center(
                    child: Text(
                      'No one here yet.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    controller: ctrl,
                    itemCount: users.length,
                    itemBuilder: (_, i) {
                      final u = Map<String, dynamic>.from(users[i]);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: CachedNetworkImageProvider(
                            ApiService.getAvatar(u),
                          ),
                        ),
                        title: Text(
                          u['username'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          u['fullName'] ?? '',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        trailing: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ProfileScreen(username: u['username']),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF444444)),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: const Text(
                            'View',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ===== Edit Profile Bottom Sheet =====
class _EditProfileSheet extends StatefulWidget {
  final Map<String, dynamic> currentProfile;
  final Function(Map<String, dynamic>) onSaved;
  const _EditProfileSheet({
    required this.currentProfile,
    required this.onSaved,
  });
  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _fullNameCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _websiteCtrl;
  bool _isPrivate = false;
  bool _isLoading = false;
  PlatformFile? _pickedAvatar;

  @override
  void initState() {
    super.initState();
    _fullNameCtrl = TextEditingController(
      text: widget.currentProfile['fullName'] ?? '',
    );
    _bioCtrl = TextEditingController(text: widget.currentProfile['bio'] ?? '');
    _websiteCtrl = TextEditingController(
      text: widget.currentProfile['website'] ?? '',
    );
    _isPrivate = widget.currentProfile['isPrivate'] == true;
  }

  Future<void> _pickAndCropAvatar() async {
    try {
      // Step 1: Pick Image (don't load bytes into memory yet to avoid OOM)
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: false, // Don't load bytes into memory!
      );

      if (result == null || result.files.isEmpty) return;
      final pickedFile = result.files.first;

      if (pickedFile.path == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not get image path. Please try again.'),
            ),
          );
        }
        return;
      }

      // Step 2: Crop Image
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path!,
        aspectRatio: const CropAspectRatio(
          ratioX: 1,
          ratioY: 1,
        ), // Square crop for profile
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Picture',
            toolbarColor: const Color(0xFF1a1a1a),
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: const Color(0xFFE1306C),
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Profile Picture',
            aspectRatioLockEnabled: true,
          ),
        ],
      );

      if (croppedFile != null) {
        // Step 3: Read bytes only of the cropped image
        final bytes = await croppedFile.readAsBytes();
        setState(() {
          _pickedAvatar = PlatformFile(
            name: 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
            size: bytes.length,
            bytes: bytes,
            path: croppedFile.path,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.updateProfile(
        fullName: _fullNameCtrl.text.trim(),
        bio: _bioCtrl.text.trim(),
        website: _websiteCtrl.text.trim(),
        isPrivate: _isPrivate,
        avatarBytes: _pickedAvatar?.bytes,
        avatarFilename: _pickedAvatar?.name,
      );
      if (mounted) {
        widget.onSaved(Map<String, dynamic>.from(data['user']));
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Profile updated!'),
            backgroundColor: Color(0xFFE1306C),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Edit Profile',
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

            // Avatar selection (centered)
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFF262626),
                    backgroundImage: _pickedAvatar != null
                        ? MemoryImage(_pickedAvatar!.bytes!)
                        : CachedNetworkImageProvider(
                                ApiService.getAvatar(widget.currentProfile),
                              )
                              as ImageProvider,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickAndCropAvatar,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE1306C),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF1e1e1e),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Center(
              child: TextButton(
                onPressed: _pickAndCropAvatar,
                child: const Text(
                  'Change Profile Photo',
                  style: TextStyle(
                    color: Color(0xFF4EA8E8),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            _buildField('Full Name', _fullNameCtrl, Icons.person_outline),
            const SizedBox(height: 12),
            _buildField('Bio', _bioCtrl, Icons.edit_outlined, maxLines: 3),
            const SizedBox(height: 12),
            _buildField(
              'Website',
              _websiteCtrl,
              Icons.link,
              type: TextInputType.url,
            ),
            const SizedBox(height: 16),

            // Private toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF262626),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, color: Colors.grey, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Private Account',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  Switch(
                    value: _isPrivate,
                    activeThumbColor: const Color(0xFFE1306C),
                    onChanged: (v) => setState(() => _isPrivate = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
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
                        'Save Changes',
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
    );
  }

  Widget _buildField(
    String label,
    TextEditingController ctrl,
    IconData icon, {
    int maxLines = 1,
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: type,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.grey, size: 20),
        filled: true,
        fillColor: const Color(0xFF262626),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE1306C)),
        ),
      ),
    );
  }
}

// ===== Post Detail Bottom Sheet =====
class _PostDetailSheet extends StatefulWidget {
  final Map<String, dynamic> post;
  final Map<String, dynamic>? currentUser;
  const _PostDetailSheet({required this.post, required this.currentUser});
  @override
  State<_PostDetailSheet> createState() => _PostDetailSheetState();
}

class _PostDetailSheetState extends State<_PostDetailSheet> {
  bool isLiked = false;
  int likesCount = 0;

  @override
  void initState() {
    super.initState();
    likesCount = widget.post['likesCount'] ?? 0;
    isLiked = widget.post['isLiked'] ?? false;
  }

  Future<void> _toggleLike() async {
    try {
      final data = await ApiService.post('/posts/${widget.post['_id']}/like');
      setState(() {
        isLiked = data['liked'];
        likesCount = data['likesCount'];
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final author = Map<String, dynamic>.from(post['author'] ?? {});
    final isVideo =
        post['video'] != null && post['video'].toString().isNotEmpty;
    final mediaUrl = ApiService.getFullUrl(
      isVideo ? post['video'] : post['image'],
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundImage: CachedNetworkImageProvider(
                    ApiService.getAvatar(author),
                  ),
                  radius: 18,
                ),
                const SizedBox(width: 10),
                Text(
                  author['username'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Media
          if (mediaUrl.isNotEmpty)
            isVideo
                ? FeedVideoPlayer(url: mediaUrl, isActive: true)
                : CachedNetworkImage(
                    imageUrl: mediaUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(height: 250, color: const Color(0xFF262626)),
                    errorWidget: (_, __, ___) => Container(
                      height: 200,
                      color: const Color(0xFF262626),
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.white,
                  ),
                  onPressed: _toggleLike,
                ),
                Text(
                  '$likesCount',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),
                const Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 4),
                Text('${post['commentsCount'] ?? 0}'),
              ],
            ),
          ),
          if ((post['caption'] ?? '').toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${author['username'] ?? ''} ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: post['caption'] ?? ''),
                    ],
                  ),
                ),
              ),
            ),
          const Divider(color: Color(0xFF333333)),
          // Comments
          Expanded(child: CommentsSheet(postId: post['_id'])),
        ],
      ),
    );
  }
}
