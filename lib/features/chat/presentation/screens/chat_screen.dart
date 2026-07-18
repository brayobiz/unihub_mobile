import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
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
import '../../../auth/domain/models/app_user.dart';
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
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/empty_state.dart';

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
                  final user = ref.read(authStateProvider).valueOrNull;
                  if (user != null) {
                    ref.read(chatRepositoryProvider).deleteMessage(widget.conversationId, message.id, user.uid);
                  }
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
    
    final bool isSupport = widget.otherUserName == 'Ulify Support' ||
                          otherUserId == 'ulify_admin' ||
                          (conversation?.isSupport ?? false);

    final effectiveStatusId = (isSupport && conversation?.assignedAdminId != null)
        ? conversation!.assignedAdminId!
        : otherUserId;

    final otherUser = (effectiveStatusId != null && effectiveStatusId.isNotEmpty && effectiveStatusId != 'ulify_admin')
        ? ref.watch(publicUserProvider(effectiveStatusId)).valueOrNull
        : null;

    final bool isResolved = (conversation?.supportStatus == 'resolved' || conversation?.supportStatus == 'closed') &&
                           (conversation?.lastMessageSenderId == 'ulify_admin');
    final effectiveContext = widget.chatContext ?? conversation?.context;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.chevron_left_rounded, color: theme.colorScheme.onSurface, size: 30),
          onPressed: () => context.pop(),
        ),
        title: Consumer(
          builder: (context, ref, child) {
            // Identity Logic: Ensure we distinguish between Support and regular Users
            final bool isSupportSession = isSupport;

            final isOnline = otherUser?.isOnline == true;

            // Check if ANY other participant is typing
            String? typingUserId;
            if (conversation != null) {
              for (final uid in conversation.participants) {
                if (uid != currentUser?.uid && conversation.isParticipantTyping(uid)) {
                  typingUserId = uid;
                  break;
                }
              }
            }
            final bool isOtherTyping = typingUserId != null;

            String statusText;
            if (isOtherTyping) {
              statusText = (typingUserId == 'ulify_admin') ? 'Ulify Assistant is typing...' : 'typing...';
            } else if (isSupportSession && conversation?.assignedAdminId == null) {
              final bool isHighPriority = conversation?.supportPriority == 'high';
              statusText = isHighPriority ? '🚀 Escalated to Human Team' : '🤖 Always active • Instant Support';
            } else {
              // Hardware: For production, we remove the "typically replies in 5m" estimation
              // as requested and use real-time online/offline status.
              statusText = isOnline
                  ? 'Online'
                  : (otherUser?.lastSeen != null
                      ? 'Last seen ${_formatLastSeen(otherUser!.lastSeen!)}'
                      : 'Offline');
            }

            return Row(
              children: [
                if (isSupportSession)
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8E8FFA), Color(0xFF6C63FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))
                      ],
                    ),
                    child: const Icon(Icons.headset_mic_rounded, size: 20, color: Colors.white),
                  )
                else
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    backgroundImage: otherUser?.photoUrl != null ? CachedNetworkImageProvider(otherUser!.photoUrl!) : null,
                    onBackgroundImageError: otherUser?.photoUrl != null ? (exception, stackTrace) {
                      debugPrint('🖼️ Header Avatar Error: $exception');
                    } : null,
                    child: otherUser?.photoUrl == null
                        ? Text(
                            widget.otherUserName.isNotEmpty ? widget.otherUserName[0].toUpperCase() : 'U',
                            style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13),
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
                              style: theme.textTheme.titleSmall?.copyWith(fontSize: 16, color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Blue tick: Only for Support or Identity-Verified Users
                          if (isSupportSession || otherUser?.isVerified == true) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.verified,
                              color: isSupportSession ? const Color(0xFF6C63FF) : theme.colorScheme.primary,
                              size: 16
                            ),
                          ],
                        ],
                      ),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11, 
                          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                          fontWeight: FontWeight.w500
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
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
          // Safety & Security Banner (Visible in all chats)
          _buildSafetyBanner(context, isSupport),
            
          // Context Banner: Only show for specific topics like Marketplace, Housing, or Events.
          // Hide for 'support' and generic 'user' chats to keep the UI clean.
          if (effectiveContext != null &&
              effectiveContext.type != 'support' &&
              effectiveContext.type != 'user')
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
                    
                    // Context Divider Logic: Only show for marketplace/housing to distinguish topics.
                    // Hide for 'support' and generic 'user' chats to keep the conversation clean.
                    bool showContextDivider = false;
                    if (message.context != null &&
                        message.context?.type != 'support' &&
                        message.context?.type != 'user') {
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
                          child: _buildMessageBubble(context, message, isMe, !isSameSenderAsNext, isSupport, otherUser),
                        ),
                      ],
                    );
                  },
                );
              },
              loading: () => Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
              error: (err, stack) => ErrorView(
                error: err,
                onRetry: () => ref.invalidate(messagesStreamProvider(widget.conversationId)),
                isFullPage: false,
              ),
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

  Widget _buildSafetyBanner(BuildContext context, bool isSupport) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => _showSafetyInfo(context, isSupport),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isSupport ? const Color(0xFF6C63FF) : Colors.orange).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSupport ? Icons.verified_user_outlined : Icons.shield_outlined,
                color: isSupport ? const Color(0xFF6C63FF) : Colors.orange,
                size: 20
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSupport ? 'Official Support Channel' : 'Secure Student Chat',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    isSupport ? 'Verified assistance is active' : 'Tap for campus safety tips',
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(Icons.info_outline_rounded, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5), size: 18),
          ],
        ),
      ),
    );
  }

  void _showSafetyInfo(BuildContext context, bool isSupport) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isSupport ? Icons.verified_user : Icons.security, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  isSupport ? 'Security & Privacy' : 'Campus Safety Guide',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (isSupport) ...[
              _safetyInfoItem(Icons.lock_outline, 'End-to-End Encryption', 'Your messages with support are encrypted and only accessible by authorized admins.'),
              _safetyInfoItem(Icons.history, 'Session Logging', 'Transcripts are saved to ensure quality and resolve disputes. They are never shared with third parties.'),
              _safetyInfoItem(Icons.gpp_good_outlined, 'Official Support', 'You are chatting with a verified Ulify staff member or automated assistant.'),
            ] else ...[
              _safetyInfoItem(Icons.location_on_outlined, 'Meet in Public', 'Always meet in well-lit, public campus areas like the library or cafeteria.'),
              _safetyInfoItem(Icons.payments_outlined, 'No Pre-payments', 'Never send money or deposits before inspecting the item or room in person.'),
              _safetyInfoItem(Icons.report_problem_outlined, 'Report Activity', 'Use the "Block" or "Report" tools in the menu if you feel uncomfortable.'),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('I Understand', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _safetyInfoItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF6C63FF)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(description, style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextDivider(BuildContext context, ChatContext chatContext) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        children: [
          const Expanded(child: Divider(height: 1, thickness: 0.5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              chatContext.type.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary.withOpacity(0.5),
                letterSpacing: 2.0,
              ),
            ),
          ),
          const Expanded(child: Divider(height: 1, thickness: 0.5)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return EmptyState(
      title: 'No messages yet',
      message: 'Say hello to ${widget.otherUserName}!',
      icon: Icons.chat_bubble_outline_rounded,
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
      case 'roommate': return Icons.people_outline_rounded;
      case 'organizer': return Icons.business_rounded;
      default: return Icons.info_outline;
    }
  }

  Future<void> _navigateToContext(ChatContext chatContext) async {
    try {
      if (chatContext.type == 'marketplace') {
        final listing = await ref.read(marketplaceRepositoryProvider).getListingById(chatContext.id);
        if (listing != null && mounted) {
          context.push('/listing-detail/${listing.id}', extra: listing);
        } else if (mounted) {
          context.push('/listing-detail/${chatContext.id}');
        }
      } else if (chatContext.type == 'housing') {
        final housing = await ref.read(housingRepositoryProvider).getListingById(chatContext.id);
        if (housing != null && mounted) {
          context.push('/housing-detail/${housing.id}', extra: housing);
        } else if (mounted) {
          context.push('/housing-detail/${chatContext.id}');
        }
      } else if (chatContext.type == 'roommate') {
        context.push('/roommates');
      } else if (chatContext.type == 'organizer') {
        context.push('/organizers/${chatContext.id}');
      } else if (chatContext.type == 'event') {
        context.push('/events/${chatContext.id}');
      } else if (chatContext.type == 'map') {
        context.push('/campus-map?landmarkId=${chatContext.id}');
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
      ),
      child: SafeArea(
        child: Row(
          children: [
            Container(
              decoration: const BoxDecoration(color: Color(0xFF6C63FF), shape: BoxShape.circle),
              child: IconButton(
                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
                onPressed: () => _showAttachmentMenu(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Expanded(
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
                    IconButton(
                      icon: Icon(Icons.sentiment_satisfied_alt_rounded, color: Colors.grey.shade400),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => _sendMessage(),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFF6C63FF),
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
                if (user != null) {
                  ref.read(chatRepositoryProvider).deleteConversation(widget.conversationId, user.uid);
                }
                context.pop(); // pop sheet
                context.pop(); // pop screen
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, Message message, bool isMe, bool showTail, bool isSupport, AppUser? otherUser) {
    final theme = Theme.of(context);
    final isAi = message.metadata?['isAi'] == true;
    final String? botName = message.metadata?['botName'];
    
    return RepaintBoundary(
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                Consumer(
                  builder: (context, ref, _) {
                    final sender = ref.watch(publicUserProvider(message.senderId)).valueOrNull;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 2),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
                        image: (!isAi && sender?.photoUrl != null) 
                            ? DecorationImage(
                                image: CachedNetworkImageProvider(sender!.photoUrl!),
                                fit: BoxFit.cover,
                                onError: (exception, stackTrace) {
                                  debugPrint('🖼️ Bubble Avatar Error: $exception');
                                },
                              )
                            : null,
                      ),
                      child: (!isAi && sender?.photoUrl == null)
                        ? Icon(isAi ? Icons.smart_toy_rounded : Icons.person_rounded, 
                               size: 14, color: isAi ? const Color(0xFF6C63FF) : Colors.grey)
                        : (isAi ? const Icon(Icons.smart_toy_rounded, size: 14, color: Color(0xFF6C63FF)) : null),
                    );
                  }
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Tighter padding
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFF6C63FF) : theme.colorScheme.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 20),
                    ),
                    border: isMe ? null : Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      if (!isMe && isAi)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.auto_awesome, size: 10, color: Color(0xFF6C63FF)),
                              const SizedBox(width: 4),
                              Text(
                                botName ?? 'Ulify Assistant',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF6C63FF),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(
                            child: _buildMessageContent(context, message, isMe),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (isMe)
                                _buildStatusIcon(
                                  message.status,
                                  showMiniAvatar: showTail && message.status == MessageStatus.read,
                                  otherUser: otherUser,
                                  isSupport: isSupport
                                ),
                              Text(
                                DateFormat('HH:mm').format(message.timestamp),
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w400,
                                  color: isMe ? Colors.white.withOpacity(0.5) : Colors.grey.withOpacity(0.6),
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (isMe) const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(MessageStatus status, {bool showMiniAvatar = false, AppUser? otherUser, bool isSupport = false}) {
    IconData icon;
    Color color = Colors.white70;
    bool hasGlow = false;

    switch (status) {
      case MessageStatus.sending:
        icon = Icons.access_time;
        break;
      case MessageStatus.sent:
        icon = Icons.check;
        color = Colors.grey.shade400; // 1 Grey Check (Sent/Offline)
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all;
        color = Colors.grey.shade400; // 2 Grey Checks (Delivered/In-app)
        break;
      case MessageStatus.read:
        icon = Icons.done_all;
        color = const Color(0xFF00FFFF); // Electric Cyan (High Glow)
        hasGlow = true;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasGlow)
          Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 6,
                  spreadRadius: 1,
                )
              ],
            ),
            child: Icon(icon, size: 12, color: color),
          )
        else
          Icon(icon, size: 12, color: color),
        if (showMiniAvatar) ...[
          const SizedBox(width: 4),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 0.5),
              image: (!isSupport && otherUser?.photoUrl != null)
                  ? DecorationImage(image: CachedNetworkImageProvider(otherUser!.photoUrl!), fit: BoxFit.cover)
                  : null,
            ),
            child: (isSupport || otherUser?.photoUrl == null)
                ? Icon(isSupport ? Icons.headset_mic_rounded : Icons.person_rounded, size: 8, color: Colors.white)
                : null,
          ),
        ],
      ],
    );
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
            height: 1.3, // Sleeker line height
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
    List<Map<String, dynamic>> replies;
    
    if (contextType == 'marketplace') {
      replies = [
        {'text': "Is this available?", 'icon': Icons.shopping_bag_outlined},
        {'text': "Last price?", 'icon': Icons.sell_outlined},
      ];
    } else {
      replies = [
        {'text': "Hello!", 'icon': Icons.waving_hand_rounded},
        {'text': "I have a question", 'icon': Icons.help_outline_rounded},
        {'text': "Thank you", 'icon': Icons.thumb_up_rounded},
      ];
    }

    return Container(
      height: 50,
      color: theme.colorScheme.surface,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: replies.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ActionChip(
            avatar: Icon(replies[index]['icon'], size: 16, color: const Color(0xFF6C63FF)),
            label: Text(replies[index]['text'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: () => _sendMessage(replies[index]['text']),
            backgroundColor: theme.colorScheme.surface,
            labelStyle: const TextStyle(color: Color(0xFF6C63FF)),
            side: BorderSide(color: const Color(0xFF6C63FF).withOpacity(0.2)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        ),
      ),
    );
  }
}
