import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:unihub_mobile/core/constants/campus_constants.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../auth/shared/providers.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../../chat/domain/models/conversation.dart';
import '../../../chat/domain/models/message.dart';
import '../../../chat/shared/providers.dart';
import '../../shared/providers.dart';
import '../../../shared/storage_repository.dart';
import '../layout/admin_layout.dart';
import 'package:unihub_mobile/core/widgets/optimized_image.dart';

class SupportConversationAdminScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final Conversation? initialConversation;

  const SupportConversationAdminScreen({
    super.key,
    required this.conversationId,
    this.initialConversation,
  });

  @override
  ConsumerState<SupportConversationAdminScreen> createState() => _SupportConversationAdminScreenState();
}

class _SupportConversationAdminScreenState extends ConsumerState<SupportConversationAdminScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _adminNoteController = TextEditingController();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(appUserProvider).valueOrNull;
      if (user != null) {
        ref.read(chatRepositoryProvider).markAsRead(widget.conversationId, user.uid);
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _adminNoteController.dispose();
    super.dispose();
  }

  void _sendMessage([String? quickContent, MessageType type = MessageType.text]) async {
    final content = quickContent ?? _messageController.text.trim();
    if (content.isEmpty) return;

    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null) return;

    final message = Message(
      id: const Uuid().v4(),
      senderId: 'unihub_admin', // Send as the generic support identity
      content: content,
      type: type,
      status: MessageStatus.sending,
      timestamp: DateTime.now(),
      context: widget.initialConversation?.context,
      metadata: {
        'adminId': user.uid,
        'adminName': user.fullName,
      },
    );

    _messageController.clear();
    final messenger = ScaffoldMessenger.of(context);
    
    try {
      await ref.read(chatRepositoryProvider).sendMessage(widget.conversationId, message);
      // Status update is handled automatically in ChatRepositoryImpl.sendMessage for support chats
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  Future<void> _attachImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      _uploadAndSend(File(image.path), MessageType.image);
    }
  }

  Future<void> _uploadAndSend(File file, MessageType type) async {
    setState(() => _isProcessing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await ref.read(storageRepositoryProvider).uploadFile(
        path: 'chats/${widget.conversationId}',
        id: const Uuid().v4(),
        file: file,
      );
      _sendMessage(url, type);
    } catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _updateStatus(String status) async {
    final admin = ref.read(appUserProvider).valueOrNull;
    if (admin == null) return;

    setState(() => _isProcessing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(adminRepositoryProvider).updateSupportConversationStatus(
        widget.conversationId, 
        status,
        adminId: admin.uid,
        adminName: admin.fullName,
      );
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Status updated to ${status.replaceAll('_', ' ')}')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _updatePriority(String priority) async {
    final admin = ref.read(appUserProvider).valueOrNull;
    if (admin == null) return;

    await ref.read(adminRepositoryProvider).updateSupportConversationPriority(
      widget.conversationId, 
      priority,
      adminId: admin.uid,
      adminName: admin.fullName,
    );
  }

  Future<void> _toggleAssignment(String? adminId) async {
    final admin = ref.read(appUserProvider).valueOrNull;
    if (admin == null) return;

    await ref.read(adminRepositoryProvider).assignSupportConversation(
      widget.conversationId, 
      adminId,
      adminName: admin.fullName,
      performingAdminId: admin.uid,
    );
  }

  Future<void> _addInternalNote() async {
    final note = _adminNoteController.text.trim();
    if (note.isEmpty) return;

    final admin = ref.read(appUserProvider).valueOrNull;
    if (admin == null) return;

    final messenger = ScaffoldMessenger.of(context);
    await ref.read(adminRepositoryProvider).addSupportAdminNote(widget.conversationId, note, admin.uid);
    _adminNoteController.clear();
    if (mounted) {
      Navigator.pop(context); // Close dialog
      messenger.showSnackBar(const SnackBar(content: Text('Internal note added')));
    }
  }

  final List<Map<String, String>> _quickReplies = [
    {'title': 'Greeting', 'text': 'Hello! How can I assist you today?'},
    {'title': 'Need Info', 'text': 'To help you further, could you please provide more details or a screenshot of the issue?'},
    {'title': 'Resolved', 'text': 'I have resolved the issue for you. Is there anything else I can help with?'},
    {'title': 'Escalated', 'text': 'I am escalating this to our technical team. We will get back to you soon.'},
    {'title': 'Closing', 'text': 'Thank you for contacting UniHub support. This session will now be closed.'},
  ];

  void _showQuickReplies() {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: _quickReplies.map((reply) => ListTile(
          title: Text(reply['title']!),
          subtitle: Text(reply['text']!),
          onTap: () {
            _messageController.text = reply['text']!;
            Navigator.pop(context);
          },
        )).toList(),
      ),
    );
  }

  Future<void> _resolveAndClose() async {
    final admin = ref.read(appUserProvider).valueOrNull;
    if (admin == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resolve & Close Session?'),
        content: const Text('This will set the status to "Resolved" and notify the user.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    final navigator = Navigator.of(context);
    try {
      _sendMessage('Thank you for using UniHub Support. This ticket is now marked as Resolved.');
      
      // Mark as read and update status
      await ref.read(adminRepositoryProvider).updateSupportConversationStatus(
        widget.conversationId, 
        'resolved',
        adminId: admin.uid,
        adminName: admin.fullName,
      );

      // Force refresh the support conversations list
      ref.invalidate(supportConversationsProvider);

      if (mounted) navigator.pop();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversationAsync = ref.watch(conversationProvider(widget.conversationId));
    final messagesAsync = ref.watch(messagesStreamProvider(widget.conversationId));
    final currentUser = ref.watch(appUserProvider).valueOrNull;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900;

    return AdminLayout(
      title: 'Support Session',
      child: conversationAsync.when(
        data: (conversation) {
          if (conversation == null) return const Center(child: Text('Conversation not found'));
          
          final userId = conversation.participants.firstWhere((p) => p != 'unihub_admin' && p != currentUser?.uid, orElse: () => '');
          final userAsync = ref.watch(userByIdProvider(userId));

          if (isMobile) {
            return Column(
              children: [
                Expanded(child: _buildChatArea(messagesAsync, currentUser, conversation)),
                // Management button/sheet for mobile
                Container(
                  padding: const EdgeInsets.all(8),
                  child: OutlinedButton.icon(
                    onPressed: () => _showMobileManagementSheet(conversation, userAsync),
                    icon: const Icon(Icons.settings),
                    label: const Text('Manage Session'),
                  ),
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildChatArea(messagesAsync, currentUser, conversation),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                flex: 1,
                child: _buildManagementSidebar(conversation, userAsync),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  void _showMobileManagementSheet(Conversation conversation, AsyncValue<AppUser?> userAsync) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _buildManagementSidebar(conversation, userAsync),
      ),
    );
  }

  Widget _buildChatArea(AsyncValue<List<Message>> messagesAsync, AppUser? currentUser, Conversation conversation) {
    final isResolved = conversation.supportStatus == 'resolved' || conversation.supportStatus == 'closed';

    return Column(
      children: [
        // Ticket Header Info
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          color: isResolved ? AppColors.success.withValues(alpha: 0.1) : Theme.of(context).cardColor,
          child: Row(
            children: [
              Text('SESSION ID: ', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text(conversation.id.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (isResolved)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(4)),
                  child: const Text('RESOLVED', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: messagesAsync.when(
            data: (messages) => ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(24),
              reverse: true,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                final isMe = message.senderId == 'unihub_admin';
                return _buildMessageBubble(message, isMe);
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
          ),
        ),
        if (_isProcessing)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 8),
                Text('Processing...', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        if (isResolved)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Text(
              'This support session is resolved. New messages are disabled.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic),
            ),
          )
        else
          _buildInputArea(),
      ],
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            _buildMessageContent(message, isMe),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(message.timestamp),
              style: TextStyle(
                fontSize: 10, 
                color: (isMe ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant).withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(Message message, bool isMe) {
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

    return Text(
      message.content,
      style: TextStyle(color: isMe ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color),
    );
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

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.flash_on_outlined, color: AppColors.primary),
                onPressed: _showQuickReplies,
                tooltip: 'Quick Replies',
              ),
              IconButton(
                icon: const Icon(Icons.image_outlined),
                onPressed: _attachImage,
                tooltip: 'Send Image',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Type your reply as support...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => _sendMessage(),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManagementSidebar(Conversation conversation, AsyncValue<AppUser?> userAsync) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. User Header Section
          userAsync.when(
            data: (user) => _buildUserCard(user),
            loading: () => const Center(child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            )),
            error: (_, __) => const Text('Error loading user metadata'),
          ),
          
          const SizedBox(height: 32),
          
          // 2. Active Session Management Section
          _buildSectionHeader('Live Session Management', Icons.admin_panel_settings_rounded),
          const SizedBox(height: 16),
          _buildAssignmentControl(conversation),
          
          const SizedBox(height: 24),
          _buildPriorityControl(conversation),
          
          const SizedBox(height: 24),
          _buildStatusControl(conversation),
          
          const SizedBox(height: 32),
          
          // 3. Resolution Section
          if (conversation.supportStatus != 'resolved' && conversation.supportStatus != 'closed') ...[
            _buildSectionHeader('Final Actions', Icons.check_circle_outline),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _resolveAndClose,
              icon: const Icon(Icons.verified_rounded),
              label: const Text('Resolve & Close Session'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 32),
          ],
          
          // 4. Internal Documentation Section
          _buildSectionHeader('Internal Audit Trail', Icons.history_edu_rounded),
          const SizedBox(height: 12),
          if (conversation.supportAdminNotes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'No internal notes have been added yet.',
                style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            )
          else
            ...conversation.supportAdminNotes.map((note) => _buildInternalNote(note)),
          
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _showAddNoteDialog(),
            icon: const Icon(Icons.add_comment_rounded),
            label: const Text('Add Internal Note'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.w900, 
            fontSize: 11, 
            letterSpacing: 1.2,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityControl(Conversation conversation) {
    final priorities = ['low', 'normal', 'high', 'urgent'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ticket Priority', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: priorities.map((p) {
            final isSelected = conversation.supportPriority == p;
            Color color = AppColors.grey;
            if (p == 'high') color = AppColors.warning;
            if (p == 'urgent') color = AppColors.error;
            if (p == 'low') color = AppColors.success;

            return FilterChip(
              label: Text(p.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              selected: isSelected,
              onSelected: (_) => _updatePriority(p),
              selectedColor: color.withOpacity(0.2),
              checkmarkColor: color,
              labelStyle: TextStyle(color: isSelected ? color : Colors.grey),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: isSelected ? color : Colors.grey.withOpacity(0.3)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStatusControl(Conversation conversation) {
    final statuses = ['waiting_admin', 'waiting_user', 'resolved', 'closed'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Lifecycle Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: conversation.supportStatus ?? 'waiting_admin',
              isExpanded: true,
              items: statuses.map((s) => DropdownMenuItem(
                value: s,
                child: Text(s.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              )).toList(),
              onChanged: (val) => _updateStatus(val!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(AppUser? user) {
    if (user == null) return const Text('User context unavailable');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                child: user.photoUrl == null ? const Icon(Icons.person, size: 30) : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(user.email, style: TextStyle(color: Colors.grey, fontSize: 11)),
                    if (user.university != null)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          CampusConstants.getDisplayName(user.university), 
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => context.push('/admin/users/${user.uid}', extra: user),
                icon: const Icon(Icons.open_in_new_rounded, size: 18, color: AppColors.primary),
                tooltip: 'View Full Profile',
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCompactStat('Listings', user.activeListingsCount.toString()),
              _buildCompactStat('Trust', '${user.trustScore.toStringAsFixed(0)}%'),
              _buildCompactStat('Status', user.isBanned ? 'Banned' : 'Active', color: user.isBanned ? AppColors.error : AppColors.success),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStat(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }


  Widget _buildAssignmentControl(Conversation conversation) {
    final admin = ref.read(appUserProvider).valueOrNull;
    final isAssignedToMe = conversation.assignedAdminId == admin?.uid;
    final isUnassigned = conversation.assignedAdminId == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Assignment', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        if (isUnassigned)
          ElevatedButton.icon(
            onPressed: () => _toggleAssignment(admin?.uid),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text('Assign to Me'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 40),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isAssignedToMe ? AppColors.success.withValues(alpha: 0.1) : AppColors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isAssignedToMe ? AppColors.success.withValues(alpha: 0.3) : AppColors.grey.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  isAssignedToMe ? Icons.person_rounded : Icons.person_outline_rounded,
                  size: 18,
                  color: isAssignedToMe ? AppColors.success : AppColors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isAssignedToMe ? 'Assigned to you' : 'Assigned to another admin',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isAssignedToMe ? AppColors.success : AppColors.grey,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _toggleAssignment(null),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                  child: const Text('Unassign', style: TextStyle(fontSize: 12, color: AppColors.error)),
                ),
              ],
            ),
          ),
      ],
    );
  }


  Widget _buildInternalNote(Map<String, dynamic> note) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ADMIN NOTE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.orange, letterSpacing: 1.0)),
              if (note['timestamp'] != null)
                Text(
                  DateFormat('MMM dd, HH:mm').format((note['timestamp'] as Timestamp).toDate()),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            note['note'] ?? '', 
            style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  void _showAddNoteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Internal Support Note'),
        content: TextField(
          controller: _adminNoteController,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Enter internal details about this case...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: _addInternalNote, child: const Text('Save Note')),
        ],
      ),
    );
  }
}
