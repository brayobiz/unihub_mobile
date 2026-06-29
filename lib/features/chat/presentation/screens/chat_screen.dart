import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../auth/shared/providers.dart';
import '../../domain/models/conversation.dart';
import '../../domain/models/message.dart';
import '../../domain/models/chat_context.dart';
import '../../shared/providers.dart';
import '../../../shared/storage_repository.dart';
import 'package:unihub_mobile/core/widgets/optimized_image.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String otherUserName;
  final ChatContext? chatContext;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    this.chatContext,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isUploading = false;
  Timer? _typingTimer;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    // Mark as read when opening
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authStateProvider).valueOrNull;
      if (user != null) {
        ref.read(chatRepositoryProvider).markAsRead(widget.conversationId, user.uid);
      }
    });
    
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    if (!_isTyping && _messageController.text.isNotEmpty) {
      _isTyping = true;
      ref.read(chatRepositoryProvider).updateTypingStatus(widget.conversationId, user.uid, true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      if (_isTyping) {
        _isTyping = false;
        ref.read(chatRepositoryProvider).updateTypingStatus(widget.conversationId, user.uid, false);
      }
    });
  }

  void _sendMessage([String? quickContent, MessageType type = MessageType.text]) {
    final content = quickContent ?? _messageController.text.trim();
    if (content.isEmpty) return;

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    final message = Message(
      id: const Uuid().v4(),
      senderId: user.uid,
      content: content,
      type: type,
      status: MessageStatus.sending, // Start with sending status for optimistic UI
      timestamp: DateTime.now(),
    );

    ref.read(chatRepositoryProvider).sendMessage(widget.conversationId, message);
    _messageController.clear();
  }

  Future<void> _attachImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      _uploadAndSend(File(image.path), MessageType.image);
    }
  }

  Future<void> _attachFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'txt'],
    );
    if (result != null && result.files.single.path != null) {
      _uploadAndSend(File(result.files.single.path!), MessageType.file);
    }
  }

  Future<void> _uploadAndSend(File file, MessageType type) async {
    setState(() => _isUploading = true);
    try {
      final url = await ref.read(storageRepositoryProvider).uploadFile(
        path: 'chats/${widget.conversationId}',
        id: const Uuid().v4(),
        file: file,
      );
      _sendMessage(url, type);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _onLongPressMessage(Message message, bool isMe) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy Text'),
              onTap: () {
                // Clipboard logic
                Navigator.pop(context);
              },
            ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: const Text('Delete Message', style: TextStyle(color: Colors.red)),
                onTap: () {
                  ref.read(chatRepositoryProvider).deleteMessage(widget.conversationId, message.id);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesStreamProvider(widget.conversationId));
    final conversationAsync = ref.watch(conversationProvider(widget.conversationId));
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    
    final conversation = conversationAsync.valueOrNull;
    
    // Auto-mark as read when new messages arrive while on screen
    ref.listen(messagesStreamProvider(widget.conversationId), (previous, next) {
      if (next.hasValue && next.value!.isNotEmpty) {
        final lastMessage = next.value!.first;
        if (lastMessage.senderId != currentUser?.uid && currentUser != null) {
          ref.read(chatRepositoryProvider).markAsRead(widget.conversationId, currentUser.uid);
        }
      }
    });
    
    String? otherUserId;
    if (conversation != null && currentUser != null) {
      otherUserId = conversation.participants.firstWhere((id) => id != currentUser.uid, orElse: () => '');
    }
    
    final otherUser = (otherUserId != null && otherUserId.isNotEmpty) 
        ? ref.watch(userByIdProvider(otherUserId)).valueOrNull 
        : null;

    final isOnline = otherUser?.isOnline == true;
    final lastSeen = otherUser?.lastSeen;
    
    final bool isOtherTyping = conversation?.typing[otherUserId] != null;

    final effectiveContext = widget.chatContext ?? conversation?.context;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.indigo.shade50,
              backgroundImage: otherUser?.photoUrl != null ? NetworkImage(otherUser!.photoUrl!) : null,
              child: otherUser?.photoUrl == null 
                ? Text(
                    widget.otherUserName.isNotEmpty ? widget.otherUserName[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.indigo),
                  )
                : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.otherUserName,
                          style: GoogleFonts.plusJakartaSans(fontSize: 15, color: Colors.black, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (otherUser?.isVerified == true) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, color: Color(0xFF6366F1), size: 14),
                      ],
                    ],
                  ),
                  Text(
                    isOtherTyping 
                        ? 'typing...' 
                        : (isOnline ? 'Online' : (lastSeen != null ? 'Last seen ${_formatLastSeen(lastSeen)}' : 'Offline')),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, 
                      color: isOtherTyping || isOnline ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.w600
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.black),
            onPressed: () => _showConversationMenu(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (effectiveContext != null && effectiveContext.type != 'support') 
            _buildContextBanner(effectiveContext),
          
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return _buildEmptyState();
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == currentUser?.uid;
                    final bool isSameSenderAsNext = index > 0 && messages[index - 1].senderId == message.senderId;
                    
                    return GestureDetector(
                      onLongPress: () => _onLongPressMessage(message, isMe),
                      child: _buildMessageBubble(message, isMe, !isSameSenderAsNext),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: Colors.indigo)),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
          
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('Uploading attachment...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),

          _buildQuickReplies(effectiveContext?.type),
          
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Say hello to ${widget.otherUserName}!',
            style: GoogleFonts.plusJakartaSans(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildContextBanner(ChatContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white, 
        border: Border(bottom: BorderSide(color: Colors.grey.shade200))
      ),
      child: Row(
        children: [
          if (context.thumbnail != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: OptimizedImage(imageUrl: context.thumbnail!, width: 40, height: 40, fit: BoxFit.cover),
            )
          else
            Container(
              width: 40, height: 40, 
              decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(8)), 
              child: Icon(_getContextIcon(context.type), color: Colors.indigo, size: 20)
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                Text(context.type.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                Text(context.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]
            )
          ),
          TextButton(
            onPressed: () => _navigateToContext(context), 
            child: const Text('View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

  IconData _getContextIcon(String type) {
    switch (type.toLowerCase()) {
      case 'marketplace': return Icons.storefront;
      case 'housing': return Icons.home_work;
      default: return Icons.info_outline;
    }
  }

  void _navigateToContext(ChatContext chatContext) {
    if (chatContext.type == 'marketplace') {
      context.push('/listing-detail', extra: {'id': chatContext.id}); // Assumes router handles ID or we need full listing
    } else if (chatContext.type == 'housing') {
      context.push('/housing-detail', extra: {'id': chatContext.id});
    }
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))
        ]
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF6366F1), size: 28),
              onPressed: () => _showAttachmentMenu(),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  style: GoogleFonts.plusJakartaSans(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey.shade500, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => _sendMessage(),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFF6366F1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined, color: Colors.indigo),
              title: const Text('Send Photo'),
              onTap: () {
                Navigator.pop(context);
                _attachImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined, color: Colors.indigo),
              title: const Text('Send Document'),
              onTap: () {
                Navigator.pop(context);
                _attachFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showConversationMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: const Text('Delete Conversation', style: TextStyle(color: Colors.red)),
              onTap: () {
                ref.read(chatRepositoryProvider).deleteConversation(widget.conversationId);
                context.pop(); // pop sheet
                context.pop(); // pop screen
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe, bool showTail) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: showTail ? 12 : 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF6366F1) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : (showTail ? 4 : 16)),
            bottomRight: Radius.circular(isMe ? (showTail ? 4 : 16) : 16),
          ),
          boxShadow: [
            if (!isMe)
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            _buildMessageContent(message, isMe),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('HH:mm').format(message.timestamp), 
                  style: TextStyle(
                    fontSize: 9, 
                    fontWeight: FontWeight.w500,
                    color: isMe ? Colors.white70 : Colors.grey.shade500,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  _buildStatusIcon(message.status),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(MessageStatus status) {
    IconData icon;
    Color color = Colors.white70;
    switch (status) {
      case MessageStatus.sending:
        icon = Icons.access_time;
        break;
      case MessageStatus.sent:
        icon = Icons.check;
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all;
        break;
      case MessageStatus.read:
        icon = Icons.done_all;
        color = Colors.lightBlueAccent;
        break;
    }
    return Icon(icon, size: 12, color: color);
  }

  Widget _buildMessageContent(Message message, bool isMe) {
    switch (message.type) {
      case MessageType.image:
        return GestureDetector(
          onTap: () => _openUrl(message.content),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: OptimizedImage(
              imageUrl: message.content,
              fit: BoxFit.cover,
              thumbnailWidth: 500,
            ),
          ),
        );
      case MessageType.file:
        return InkWell(
          onTap: () => _openUrl(message.content),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.description_rounded, color: isMe ? Colors.white : Colors.indigo),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Document',
                  style: TextStyle(color: isMe ? Colors.white : Colors.black87, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        );
      default:
        return Text(
          message.content, 
          style: GoogleFonts.plusJakartaSans(
            color: isMe ? Colors.white : const Color(0xFF1E293B), 
            fontSize: 14,
            height: 1.4,
          ),
        );
    }
  }

  Future<void> _openUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return DateFormat('MMM d').format(lastSeen);
  }

  Widget _buildQuickReplies(String? contextType) {
    List<String> replies;
    if (contextType == 'marketplace') {
      replies = ["Is this available?", "Last price?", "Can we meet today?"];
    } else if (contextType == 'housing') {
      replies = ["Is this still vacant?", "When can I view?", "Are utilities included?"];
    } else {
      replies = ["Hello!", "I have a question", "Thank you"];
    }

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: replies.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ActionChip(
            label: Text(replies[index], style: const TextStyle(fontSize: 12)),
            onPressed: () => _sendMessage(replies[index]),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade200)),
          ),
        ),
      ),
    );
  }
}
