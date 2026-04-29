import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:cached_network_image/cached_network_image.dart';
import '../api/api_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  IO.Socket? socket;
  List<dynamic> conversations = [];
  List<dynamic> messages = [];
  Map<String, dynamic>? currentChatUser;
  Map<String, dynamic>? currentUser;
  List<String> onlineUsers = [];
  bool loadingConvs = true;
  bool loadingMessages = false;
  bool isTyping = false;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> searchResults = [];
  bool showSearch = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    currentUser = await ApiService.getUser();
    await _loadConversations();
    _connectSocket();
  }

  void _connectSocket() async {
    final token = await ApiService.getToken();
    final host = ApiService.getServerHostSync();
    socket = IO.io(host, IO.OptionBuilder()
        .setTransports(['websocket'])
        .setAuth({'token': token})
        .build());
    socket!.on('connect', (_) => debugPrint('Socket connected'));
    socket!.on('online_users', (users) {
      setState(() => onlineUsers = List<String>.from(users));
    });
    socket!.on('receive_message', (msg) {
      if (currentChatUser != null && msg['sender'] != null) {
        final senderId = msg['sender']['_id'] ?? msg['sender'];
        if (senderId == currentChatUser!['_id']) {
          setState(() => messages.add(msg));
          _scrollToBottom();
        }
      }
      _loadConversations();
    });
    socket!.on('user_typing', (data) {
      if (currentChatUser != null && data['userId'] == currentChatUser!['_id']) {
        setState(() => isTyping = true);
      }
    });
    socket!.on('user_stop_typing', (data) {
      if (currentChatUser != null && data['userId'] == currentChatUser!['_id']) {
        setState(() => isTyping = false);
      }
    });
  }

  Future<void> _loadConversations() async {
    try {
      final data = await ApiService.get('/messages/conversations');
      setState(() { conversations = data; loadingConvs = false; });
    } catch (e) {
      setState(() => loadingConvs = false);
    }
  }

  Future<void> _openChat(Map<String, dynamic> user) async {
    setState(() {
      currentChatUser = user;
      messages = [];
      loadingMessages = true;
      isTyping = false;
    });
    try {
      final data = await ApiService.get('/messages/${user['_id']}');
      setState(() { messages = data; loadingMessages = false; });
      _scrollToBottom();
    } catch (e) {
      setState(() => loadingMessages = false);
    }
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty || currentChatUser == null || socket == null) return;
    socket!.emit('send_message', {'receiverId': currentChatUser!['_id'], 'content': content});
    socket!.once('message_sent', (msg) {
      setState(() => messages.add(msg));
      _loadConversations();
      _scrollToBottom();
    });
    _messageController.clear();
    socket!.emit('stop_typing', {'receiverId': currentChatUser!['_id']});
  }

  void _onTyping() {
    if (socket != null && currentChatUser != null) {
      socket!.emit('typing', {'receiverId': currentChatUser!['_id']});
      Future.delayed(const Duration(milliseconds: 1500), () {
        socket?.emit('stop_typing', {'receiverId': currentChatUser!['_id']});
      });
    }
  }

  Future<void> _searchUsers(String q) async {
    if (q.trim().isEmpty) { setState(() { searchResults = []; showSearch = false; }); return; }
    try {
      final data = await ApiService.get('/users/search?q=${Uri.encodeComponent(q)}');
      setState(() { searchResults = data; showSearch = true; });
    } catch (e) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    socket?.disconnect();
    _messageController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;

    if (isWide) {
      // Side-by-side layout for wider screens
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: Row(
          children: [
            SizedBox(width: 320, child: _buildConversationList()),
            const VerticalDivider(width: 1, color: Color(0xFF262626)),
            Expanded(child: _buildChatArea()),
          ],
        ),
      );
    } else {
      // Mobile: Show chat area if a user is selected, else show list
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: currentChatUser == null ? _buildConversationList() : _buildChatArea(),
      );
    }
  }

  Widget _buildConversationList() {
    return Column(
      children: [
        const SafeArea(child: SizedBox()),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text('Messages', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            onChanged: _searchUsers,
            decoration: const InputDecoration(
              hintText: 'Search people...',
              hintStyle: TextStyle(color: Colors.grey),
              prefixIcon: Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Color(0xFF262626),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide.none),
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        if (showSearch && searchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFF1e1e1e), borderRadius: BorderRadius.circular(8)),
            child: Column(
              children: searchResults.map((u) => ListTile(
                leading: CircleAvatar(
                  backgroundImage: CachedNetworkImageProvider(ApiService.getAvatar(Map<String, dynamic>.from(u))),
                ),
                title: Text(u['username'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(u['fullName'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                onTap: () {
                  _searchController.clear();
                  setState(() { showSearch = false; searchResults = []; });
                  _openChat(Map<String, dynamic>.from(u));
                },
              )).toList(),
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: loadingConvs
              ? const Center(child: CircularProgressIndicator())
              : conversations.isEmpty
                  ? const Center(child: Text('No conversations yet.\nSearch for someone to message!',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: conversations.length,
                      itemBuilder: (context, i) {
                        final conv = conversations[i];
                        final convUser = Map<String, dynamic>.from(conv['_id']);
                        final lastMsg = conv['lastMessage'];
                        final isOnline = onlineUsers.contains(convUser['_id']);
                        final avatarUrl = ApiService.getAvatar(convUser);
                        return ListTile(
                          leading: Stack(
                            children: [
                              CircleAvatar(backgroundImage: CachedNetworkImageProvider(avatarUrl)),
                              if (isOnline)
                                Positioned(
                                  right: 0, bottom: 0,
                                  child: Container(width: 10, height: 10,
                                      decoration: BoxDecoration(color: Colors.green,
                                          shape: BoxShape.circle, border: Border.all(color: const Color(0xFF121212), width: 2))),
                                ),
                            ],
                          ),
                          title: Text(convUser['username'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(lastMsg?['content'] ?? '',
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          selected: currentChatUser?['_id'] == convUser['_id'],
                          selectedTileColor: const Color(0xFF1e1e1e),
                          onTap: () => _openChat(convUser),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildChatArea() {
    if (currentChatUser == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('Select a conversation', style: TextStyle(color: Colors.grey, fontSize: 16)),
            Text('or search for someone to message', style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    }

    final isOnline = onlineUsers.contains(currentChatUser!['_id']);
    final avatarUrl = ApiService.getAvatar(currentChatUser);

    return Column(
      children: [
        const SafeArea(child: SizedBox()),
        // Chat header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF262626)))),
          child: Row(
            children: [
              if (MediaQuery.of(context).size.width <= 600)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() { currentChatUser = null; messages = []; }),
                ),
              CircleAvatar(backgroundImage: CachedNetworkImageProvider(avatarUrl), radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(currentChatUser!['username'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(isOnline ? 'Online' : 'Offline',
                        style: TextStyle(color: isOnline ? Colors.green : Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Messages
        Expanded(
          child: loadingMessages
              ? const Center(child: CircularProgressIndicator())
              : messages.isEmpty
                  ? const Center(child: Text("No messages yet. Say hi! 👋",
                      style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, i) {
                        final msg = messages[i];
                        final senderId = msg['sender']?['_id'] ?? msg['sender'];
                        final isMine = senderId == currentUser?['_id'];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!isMine) ...[
                                CircleAvatar(backgroundImage: CachedNetworkImageProvider(avatarUrl), radius: 14),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isMine ? const Color(0xFFE1306C) : const Color(0xFF262626),
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft: Radius.circular(isMine ? 16 : 4),
                                      bottomRight: Radius.circular(isMine ? 4 : 16),
                                    ),
                                  ),
                                  child: Text(msg['content'] ?? '',
                                      style: const TextStyle(color: Colors.white)),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),

        // Typing indicator
        if (isTyping)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: Row(
              children: [
                Text('${currentChatUser!['username']} is typing...',
                    style: const TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
              ],
            ),
          ),

        // Input bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF262626)))),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (_) => _onTyping(),
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: 'Write a message...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF262626),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  width: 44, height: 44,
                  decoration: const BoxDecoration(color: Color(0xFFE1306C), shape: BoxShape.circle),
                  child: const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
