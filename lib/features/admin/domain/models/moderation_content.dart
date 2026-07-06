import '../../../marketplace/domain/models/listing.dart';
import '../../../housing/domain/models/housing_listing.dart';
import '../../../notes/domain/models/note.dart';
import '../../../events/domain/models/event.dart';

enum ContentType { marketplace, housing, notes, events }

class ModeratedContent {
  final String id;
  final ContentType type;
  final String title;
  final String authorId;
  final String authorName;
  final String? university;
  final DateTime createdAt;
  final String status;
  final List<String> imageUrls;
  final dynamic originalData; // Holds the original Listing, HousingListing, or NoteListing

  ModeratedContent({
    required this.id,
    required this.type,
    required this.title,
    required this.authorId,
    required this.authorName,
    this.university,
    required this.createdAt,
    required this.status,
    this.imageUrls = const [],
    this.originalData,
  });

  factory ModeratedContent.fromMarketplace(Listing listing) {
    return ModeratedContent(
      id: listing.id,
      type: ContentType.marketplace,
      title: listing.title,
      authorId: listing.sellerId,
      authorName: listing.sellerName,
      university: listing.sellerUniversity,
      createdAt: listing.createdAt,
      status: listing.status.name,
      imageUrls: listing.imageUrls,
      originalData: listing,
    );
  }

  factory ModeratedContent.fromHousing(HousingListing listing) {
    return ModeratedContent(
      id: listing.id,
      type: ContentType.housing,
      title: listing.title,
      authorId: listing.plugId,
      authorName: listing.plugName,
      university: listing.university,
      createdAt: listing.createdAt,
      status: listing.status.name,
      imageUrls: listing.images,
      originalData: listing,
    );
  }

  factory ModeratedContent.fromNote(NoteListing note) {
    return ModeratedContent(
      id: note.id,
      type: ContentType.notes,
      title: note.title,
      authorId: note.authorId,
      authorName: note.authorName,
      university: note.university,
      createdAt: note.createdAt,
      status: note.status,
      imageUrls: [],
      originalData: note,
    );
  }

  factory ModeratedContent.fromEvent(Event event) {
    return ModeratedContent(
      id: event.id,
      type: ContentType.events,
      title: event.title,
      authorId: event.organizerId,
      authorName: 'Organizer', // We'd need to fetch the organizer name if we want it here
      university: event.campusId,
      createdAt: event.createdAt,
      status: event.status.name,
      imageUrls: event.imageUrls,
      originalData: event,
    );
  }
}
