import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../auth/shared/providers.dart';
import '../../domain/models/conversation.dart';
import '../../domain/models/message.dart';
import '../../shared/providers.dart';
import '../../../marketplace/domain/models/listing.dart';
import '../../../marketplace/shared/providers.dart';
import '../../../shared/storage_repository.dart';
import 'package:unihub_mobile/core/widgets/optimized_image.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String otherUserName;
  final Listing? listing;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    this.listing,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  bool _isUploading = false;

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

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesStreamProvider(widget.conversationId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherUserName, style: const TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.bold)),
            const Text('Online', style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
      body: Column(
        children: [
          if (widget.listing != null) _buildListingPreview(),
          if (widget.listing?.status == ListingStatus.sold) _buildReviewPrompt(),
          
          Expanded(
            child: messagesAsync.when(
              data: (messages) => ListView.builder(
                padding: const EdgeInsets.all(16),
                reverse: true,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isMe = message.senderId == ref.read(authStateProvider).valueOrNull?.uid;
                  return _buildMessageBubble(message, isMe);
                },
              ),
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

          _buildQuickReplies(),
          
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: Colors.white),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.indigo),
              onPressed: () => _showAttachmentMenu(),
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  filled: true,
                  fillColor: const Color(0xFFF8F9FB),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.indigo,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: () => _sendMessage(),
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

  Widget _buildMessageBubble(Message message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? Colors.indigo : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 20),
          ),
          boxShadow: [if (!isMe) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            _buildMessageContent(message, isMe),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(message.timestamp), 
              style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.grey),
            ),
          ],
        ),
      ),
    );
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
        return Text(message.content, style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 15));
    }
  }

  Future<void> _openUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  // ... rest of methods (review prompt, listing preview, quick replies)
  Widget _buildReviewPrompt() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.amber.shade50,
      child: Row(
        children: [
          const Icon(Icons.star_outline, color: Colors.amber),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('This item was marked as sold. Rate your experience?', 
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          TextButton(onPressed: () => _showReviewDialog(), child: const Text('Rate Now')),
        ],
      ),
    );
  }

  void _showReviewDialog() {
    double rating = 5.0;
    final commentController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Rate Experience'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) => IconButton(
                  icon: Icon(index < rating ? Icons.star : Icons.star_border, color: Colors.amber),
                  onPressed: () => setModalState(() => rating = index + 1.0),
                )),
              ),
              TextField(controller: commentController, decoration: const InputDecoration(hintText: 'Comment (optional)'), maxLines: 2),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                final buyer = ref.read(authStateProvider).valueOrNull;
                if (buyer != null && widget.listing != null) {
                  ref.read(marketplaceRepositoryProvider).submitReview(
                    sellerId: widget.listing!.sellerId,
                    buyerId: buyer.uid,
                    listingId: widget.listing!.id,
                    rating: rating,
                    comment: commentController.text,
                  );
                }
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thank you!')));
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListingPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Row(
        children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.shopping_bag_outlined, color: Colors.indigo, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.listing!.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('KES ${widget.listing!.price.toInt()}', style: const TextStyle(color: Colors.indigo, fontSize: 12, fontWeight: FontWeight.bold)),
          ])),
          TextButton(onPressed: () => context.push('/listing-detail', extra: widget.listing), child: const Text('View', style: TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildQuickReplies() {
    final replies = ["Is this available?", "Last price?", "Can we meet today?"];
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
