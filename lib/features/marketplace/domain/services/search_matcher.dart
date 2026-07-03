import '../models/listing.dart';
import '../models/saved_search.dart';

class SearchMatcher {
  static bool matches(Listing listing, SavedSearch savedSearch) {
    final filter = savedSearch.filter;

    // 1. Campus Check
    if (savedSearch.campusId != null && listing.sellerUniversity != savedSearch.campusId) {
      return false;
    }

    // 2. Category Check
    if (filter.selectedCategory != null && filter.selectedCategory != 'All') {
      if (listing.category != filter.selectedCategory) return false;
    }

    // 3. Keyword Check (Title & Description)
    if (filter.searchQuery.isNotEmpty) {
      final query = filter.searchQuery.toLowerCase();
      final title = listing.title.toLowerCase();
      final desc = listing.description.toLowerCase();
      
      // Simple keyword matching
      final words = query.split(' ').where((w) => w.length > 2);
      bool keywordMatch = false;
      if (words.isEmpty) {
        if (title.contains(query) || desc.contains(query)) keywordMatch = true;
      } else {
        // If any word matches, we consider it a match (OR logic) or all words (AND logic)?
        // Usually AND logic for better precision
        if (words.every((word) => title.contains(word) || desc.contains(word))) {
          keywordMatch = true;
        }
      }
      
      if (!keywordMatch) return false;
    }

    // 4. Price Check
    if (filter.priceRange != null) {
      if (listing.price < filter.priceRange!.start || listing.price > filter.priceRange!.end) {
        return false;
      }
    }

    // 5. Condition Check
    if (filter.selectedConditions.isNotEmpty) {
      if (!filter.selectedConditions.contains(listing.condition.name)) {
        return false;
      }
    }

    // 6. Attribute Check (Optional but powerful)
    if (filter.categoryAttributes.isNotEmpty) {
      for (var entry in filter.categoryAttributes.entries) {
        if (listing.attributes[entry.key] != entry.value) {
          // If the listing doesn't have the attribute or it doesn't match, return false
          // Note: brand/storage/color are special cases in current model
          if (entry.key == 'brand' && listing.brand != entry.value) return false;
          if (entry.key == 'storage' && listing.storage != entry.value) return false;
          if (entry.key == 'color' && listing.color != entry.value) return false;
          
          if (!listing.attributes.containsKey(entry.key)) return false;
        }
      }
    }

    return true;
  }
}
