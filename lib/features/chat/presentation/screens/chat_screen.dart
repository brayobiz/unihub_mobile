import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import '../../../auth/shared/providers.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/models/conversation.dart';
import '../../domain/models/message.dart';
import '../../domain/models/chat_context.dart';
import '../../shared/providers.dart';
import '../../../shared/storage_repository.dart';
import '../../../../features/marketplace/domain/models/listing.dart';
import '../../../../features/housing/domain/models/housing_listing.dart';
import '../../../../features/marketplace/shared/providers.dart';
import '../../../../features/housing/shared/providers.dart';
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

    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null) return;

    final conversation = ref.read(conversationProvider(widget.conversationId)).valueOrNull;
    final otherUserId = conversation?.participants.firstWhere((id) => id != user.uid, orElse: () => '');
    
    if (user.blockedUids.contains(otherUserId)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unblock this user to send a message.')));
      return;
    }

    final effectiveContext = widget.chatContext ?? conversation?.context;

    final message = Message(
      id: const Uuid().v4(),
      senderId: user.uid,
      content: content,
      type: type,
      status: MessageStatus.sending, // UI shows clock icon
      timestamp: DateTime.now(),
      context: effectiveContext,
      metadata: {
        'senderName': user.fullName,
      },
    );

    // Reset typing status immediately
    if (_isTyping) {
      _isTyping = false;
      _typingTimer?.cancel();
      ref.read(chatRepositoryProvider).updateTypingStatus(widget.conversationId, user.uid, false);
    }

    // Optimistically clear input
    _messageController.clear();

    // Send to repository - fire and forget, Firestore handles local update
    ref.read(chatRepositoryProvider).sendMessage(widget.conversationId, message);

    // Scroll to bottom if not already there
    if (_scrollController.hasClients && _scrollController.offset > 50) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
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
    final theme = Theme.of(context);
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
    final bool isResolved = conversation?.supportStatus == 'resolved' || conversation?.supportStatus == 'closed';

    final effectiveContext = widget.chatContext ?? conversation?.context;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0.5,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.colorScheme.onSurface, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              backgroundImage: otherUser?.photoUrl != null ? NetworkImage(otherUser!.photoUrl!) : null,
              child: otherUser?.photoUrl == null
                ? Text(
                    widget.otherUserName.isNotEmpty ? widget.otherUserName[0].toUpperCase() : '?',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
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
                          style: theme.textTheme.titleSmall?.copyWith(fontSize: 15, color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (otherUser?.isVerified == true) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.verified, color: theme.colorScheme.primary, size: 14),
                      ],
                    ],
                  ),
                  Text(
                    isOtherTyping 
                        ? 'typing...' 
                        : (isOnline ? 'Online' : (lastSeen != null ? 'Last seen ${_formatLastSeen(lastSeen)}' : 'Offline')),
                    style: TextStyle(
                      fontSize: 11, 
                      color: isOtherTyping || isOnline ? AppColors.success : theme.colorScheme.onSurfaceVariant,
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
            icon: Icon(Icons.more_vert_rounded, color: theme.colorScheme.onSurface),
            onPressed: () => _showConversationMenu(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (effectiveContext != null && effectiveContext.type != 'support') 
            _buildContextBanner(context, effectiveContext),
          
          if (isResolved)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.success.withValues(alpha: 0.1),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This support session has been resolved. If you still need help, please start a new request.',
                      style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            )
          else if (conversation?.expiresAt != null)
            _buildExpirationBanner(conversation!.expiresAt!),
          
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return _buildEmptyState(context);
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
                    
                    // Context Divider Logic
                    bool showContextDivider = false;
                    if (message.context != null) {
                      if (index == messages.length - 1) {
                        showContextDivider = true;
                      } else {
                        final olderMessage = messages[index + 1];
                        if (olderMessage.context?.id != message.context?.id) {
                          showContextDivider = true;
                        }
                      }
                    }

                    return Column(
                      children: [
                        if (showContextDivider) 
                          _buildContextDivider(context, message.context!),
                        GestureDetector(
                          onLongPress: () => _onLongPressMessage(message, isMe),
                          child: _buildMessageBubble(context, message, isMe, !isSameSenderAsNext),
                        ),
                      ],
                    );
                  },
                );
              },
              loading: () => Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
          
          if (_isUploading)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary)),
                  const SizedBox(width: 8),
                  Text('Uploading attachment...', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),

          if (!isResolved)
            _buildQuickReplies(context, effectiveContext?.type),
          
          if (isResolved)
            Container(
              padding: const EdgeInsets.all(24),
              color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.1),
              child: SafeArea(
                child: Center(
                  child: Text(
                    'SESSION RESOLVED',
                    style: TextStyle(
                      letterSpacing: 2, 
                      fontWeight: FontWeight.bold, 
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                    ),
                  ),
                ),
              ),
            )
          else
            _buildInputArea(context),
        ],
      ),
    );
  }

  Widget _buildContextDivider(BuildContext context, ChatContext chatContext) {
    final theme = Theme.of(context);
    final isSupport = chatContext.type == 'support';
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 4),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(child: Divider(height: 1, thickness: 0.5)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  chatContext.type.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                    letterSpacing: 2.0,
                  ),
                ),
              ),
              const Expanded(child: Divider(height: 1, thickness: 0.5)),
            ],
          ),
          const SizedBox(height: 16),
          if (!isSupport)
            InkWell(
              onTap: () => _navigateToContext(chatContext),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    if (chatContext.thumbnail != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: OptimizedImage(imageUrl: chatContext.thumbnail!, width: 52, height: 52, fit: BoxFit.cover),
                      )
                    else
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_getContextIcon(chatContext.type), color: theme.colorScheme.primary, size: 24),
                      ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            chatContext.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'Tap to view details',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_forward_ios_rounded, size: 10, color: theme.colorScheme.primary),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 48, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            'Say hello to ${widget.otherUserName}!',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildContextBanner(BuildContext context, ChatContext chatContext) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface, 
        border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)))
      ),
      child: Row(
        children: [
          if (chatContext.thumbnail != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: OptimizedImage(imageUrl: chatContext.thumbnail!, width: 40, height: 40, fit: BoxFit.cover),
            )
          else
            Container(
              width: 40, height: 40, 
              decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), 
              child: Icon(_getContextIcon(chatContext.type), color: theme.colorScheme.primary, size: 20)
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                Text(chatContext.type.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant)),
                Text(chatContext.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]
            )
          ),
          TextButton(
            onPressed: () => _navigateToContext(chatContext), 
            child: Text('View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.primary))
          ),
        ],
      ),
    );
  }

  IconData _getContextIcon(String type) {
    switch (type.toLowerCase()) {
      case 'marketplace': return Icons.storefront;
      case 'housing': return Icons.home_work;
      case 'support': return Icons.headset_mic_rounded;
      case 'notes': return Icons.description_rounded;
      case 'plug': return Icons.electrical_services_rounded;
      default: return Icons.info_outline;
    }
  }

  Future<void> _navigateToContext(ChatContext chatContext) async {
    try {
      if (chatContext.type == 'marketplace') {
        final listing = await ref.read(marketplaceRepositoryProvider).getListingById(chatContext.id);
        if (listing != null && mounted) {
          context.push('/listing-detail', extra: listing);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Marketplace item no longer available'))
          );
        }
      } else if (chatContext.type == 'housing') {
        final housing = await ref.read(housingRepositoryProvider).getListingById(chatContext.id);
        if (housing != null && mounted) {
          context.push('/housing-detail', extra: housing);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Housing listing no longer available'))
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading details: $e'))
        );
      }
    }
  }

  Widget _buildExpirationBanner(DateTime expiresAt) {
    final now = DateTime.now();
    final remaining = expiresAt.difference(now);
    
    // Only show if less than 12 hours remaining
    if (remaining.inHours > 12 || remaining.isNegative) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.warning.withOpacity(0.1),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, size: 16, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'This conversation expires in ${remaining.inHours}h due to inactivity. Send a message to keep it active.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.warning.withOpacity(0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))
        ]
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.add_circle_outline_rounded, color: theme.colorScheme.primary, size: 28),
              onPressed: () => _showAttachmentMenu(),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                ),
                child: TextField(
                  controller: _messageController,
                  style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5), fontSize: 14),
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
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
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
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.image_outlined, color: theme.colorScheme.primary),
              title: const Text('Send Photo'),
              onTap: () {
                Navigator.pop(context);
                _attachImage();
              },
            ),
            ListTile(
              leading: Icon(Icons.description_outlined, color: theme.colorScheme.primary),
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
    final theme = Theme.of(context);
    final user = ref.read(appUserProvider).valueOrNull;
    final otherUserId = ref.watch(conversationProvider(widget.conversationId)).valueOrNull?.participants.firstWhere((id) => id != user?.uid, orElse: () => '');
    final isBlocked = user?.blockedUids.contains(otherUserId) ?? false;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(isBlocked ? Icons.check_circle_outline : Icons.block_flipped, color: isBlocked ? AppColors.success : AppColors.error),
              title: Text(isBlocked ? 'Unblock User' : 'Block User', style: TextStyle(color: isBlocked ? AppColors.success : AppColors.error)),
              onTap: () {
                if (otherUserId != null && otherUserId.isNotEmpty) {
                  if (isBlocked) {
                    ref.read(authControllerProvider.notifier).unblockUser(otherUserId);
                  } else {
                    ref.read(authControllerProvider.notifier).blockUser(otherUserId);
                  }
                }
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              title: const Text('Delete Conversation', style: TextStyle(color: AppColors.error)),
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

  Widget _buildMessageBubble(BuildContext context, Message message, bool isMe, bool showTail) {
    final theme = Theme.of(context);
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: showTail ? 12 : 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? theme.colorScheme.primary : theme.colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : (showTail ? 4 : 16)),
            bottomRight: Radius.circular(isMe ? (showTail ? 4 : 16) : 16),
          ),
          border: isMe ? null : Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
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
            _buildMessageContent(context, message, isMe),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('HH:mm').format(message.timestamp), 
                  style: TextStyle(
                    fontSize: 9, 
                    fontWeight: FontWeight.w500,
                    color: isMe ? Colors.white.withOpacity(0.7) : theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
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

  Widget _buildMessageContent(BuildContext context, Message message, bool isMe) {
    final theme = Theme.of(context);
    
    // Auto-detect image URLs in text messages
    bool isLikelyImage = message.type == MessageType.image;
    if (message.type == MessageType.text) {
      final content = message.content.trim();
      if (content.startsWith('http') && 
          (content.contains('cloudinary.com') || 
           content.toLowerCase().endsWith('.jpg') || 
           content.toLowerCase().endsWith('.jpeg') || 
           content.toLowerCase().endsWith('.png') || 
           content.toLowerCase().endsWith('.webp'))) {
        isLikelyImage = true;
      }
    }

    if (isLikelyImage) {
      return GestureDetector(
        onTap: () => _viewImage(message.content),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: OptimizedImage(
            imageUrl: message.content,
            fit: BoxFit.cover,
            thumbnailWidth: 500,
          ),
        ),
      );
    }

    switch (message.type) {
      case MessageType.file:
        return InkWell(
          onTap: () => _openUrl(message.content),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.description_rounded, color: isMe ? Colors.white : theme.colorScheme.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Document',
                  style: TextStyle(color: isMe ? Colors.white : theme.colorScheme.onSurface, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        );
      default:
        return Text(
          message.content, 
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isMe ? Colors.white : theme.colorScheme.onSurface, 
            fontSize: 14,
            height: 1.4,
          ),
        );
    }
  }

  void _viewImage(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: OptimizedImage(
                imageUrl: url,
                fit: BoxFit.contain,
                useCloudinaryTransform: false,
              ),
            ),
          ),
        ),
      ),
    );
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

  Widget _buildQuickReplies(BuildContext context, String? contextType) {
    final theme = Theme.of(context);
    List<String> replies;
    if (contextType == 'marketplace') {
      replies = ["Is this available?", "Last price?", "Can we meet today?"];
    } else if (contextType == 'housing') {
      replies = ["Is this still vacant?", "When can I view?", "Are utilities included?"];
    } else {
      replies = ["Hello!", "I have a question", "Thank you"];
    }

    return Container(
      height: 40,
      color: theme.colorScheme.surface,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: replies.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ActionChip(
            label: Text(replies[index], style: const TextStyle(fontSize: 12)),
            onPressed: () => _sendMessage(replies[index]),
            backgroundColor: theme.colorScheme.surface,
            labelStyle: TextStyle(color: theme.colorScheme.onSurface),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5))),
          ),
        ),
      ),
    );
  }
}
