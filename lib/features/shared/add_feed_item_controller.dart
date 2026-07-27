import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/feed_type.dart';
import '../auth/shared/providers.dart';
import 'feed_repository.dart';
import 'storage_repository.dart';

class AddFeedItemState {
  final bool isLoading;
  final double uploadProgress;
  final String? error;
  final bool success;

  AddFeedItemState({
    this.isLoading = false,
    this.uploadProgress = 0,
    this.error,
    this.success = false,
  });

  AddFeedItemState copyWith({
    bool? isLoading,
    double? uploadProgress,
    String? error,
    bool? success,
  }) {
    return AddFeedItemState(
      isLoading: isLoading ?? this.isLoading,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      error: error ?? this.error,
      success: success ?? this.success,
    );
  }
}

class AddFeedItemController extends StateNotifier<AddFeedItemState> {
  final Ref _ref;
  AddFeedItemController(this._ref) : super(AddFeedItemState());

  void reset() {
    state = AddFeedItemState();
  }

  Future<bool> submit({
    required FeedType type,
    required String title,
    required String content,
    String? price,
    DateTime? deadline,
    List<File> images = const [],
    String? category,
  }) async {
    final user = _ref.read(appUserProvider).valueOrNull;
    if (user == null) {
      state = state.copyWith(error: 'User session expired. Please log in again.');
      return false;
    }

    state = state.copyWith(isLoading: true, uploadProgress: 0, error: null, success: false);

    try {
      final itemId = const Uuid().v4();
      final imageUrls = <String>[];
      
      final isConfession = type == FeedType.confession;

      // 1. Upload Images
      for (var i = 0; i < images.length; i++) {
        final url = await _ref.read(storageRepositoryProvider).uploadFile(
          path: 'feed/$itemId',
          id: 'img_$i',
          file: images[i],
          onProgress: (sent, total) {
            state = state.copyWith(
              uploadProgress: (i / images.length) + ((sent / total) / images.length),
            );
          },
        );
        imageUrls.add(url);
      }

      state = state.copyWith(uploadProgress: 1.0);

      // 2. Create Feed Item
      final item = FeedItem(
        id: itemId,
        authorId: user.uid,
        authorName: isConfession ? 'Anonymous' : user.fullName,
        authorPhotoUrl: isConfession ? null : user.photoUrl,
        title: title.trim(),
        subtitle: content.trim(),
        price: price?.isNotEmpty == true ? 'KES ${price!.trim()}' : null,
        type: type,
        university: user.university,
        createdAt: DateTime.now(),
        deadline: deadline,
        images: imageUrls,
        category: category,
      );

      // 3. Post to Feed
      await _ref.read(feedRepositoryProvider).postToFeed(item);
      
      state = state.copyWith(isLoading: false, success: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final addFeedItemControllerProvider = StateNotifierProvider.autoDispose<AddFeedItemController, AddFeedItemState>((ref) {
  return AddFeedItemController(ref);
});
