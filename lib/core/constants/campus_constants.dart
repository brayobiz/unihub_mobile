import '../../features/campus_filter/domain/models/campus.dart';

class CampusConstants {
  static const List<Campus> campuses = [
    Campus(
      campusId: 'uon_main',
      officialName: 'University of Nairobi',
      shortName: 'UoN',
      aliases: ['University of Nairobi', 'UoN', 'UON'],
    ),
    Campus(
      campusId: 'ku_main',
      officialName: 'Kenyatta University',
      shortName: 'KU',
      aliases: ['Kenyatta University', 'KU', 'Ku'],
    ),
    Campus(
      campusId: 'strath_main',
      officialName: 'Strathmore University',
      shortName: 'Strathmore',
      aliases: ['Strathmore University', 'Strathmore', 'Strath'],
    ),
    Campus(
      campusId: 'jkuat_main',
      officialName: 'Jomo Kenyatta University of Agriculture and Technology',
      shortName: 'JKUAT',
      aliases: ['Jomo Kenyatta University', 'JKUAT', 'Jkuat'],
    ),
    Campus(
      campusId: 'usiu_main',
      officialName: 'United States International University-Africa',
      shortName: 'USIU',
      aliases: ['USIU-Africa', 'USIU', 'Usiu'],
    ),
    Campus(
      campusId: 'daystar_main',
      officialName: 'Daystar University',
      shortName: 'Daystar',
      aliases: ['Daystar University', 'Daystar'],
    ),
    Campus(
      campusId: 'mku_main',
      officialName: 'Mount Kenya University',
      shortName: 'MKU',
      aliases: ['Mount Kenya University', 'MKU', 'Mku'],
    ),
    Campus(
      campusId: 'egerton_main',
      officialName: 'Egerton University',
      shortName: 'Egerton',
      aliases: ['Egerton University', 'Egerton'],
    ),
    Campus(
      campusId: 'moi_main',
      officialName: 'Moi University',
      shortName: 'Moi',
      aliases: ['Moi University', 'Moi'],
    ),
  ];

  static String? resolveToId(String? input) {
    if (input == null || input.isEmpty) return null;
    final normalized = input.trim().toLowerCase();
    
    for (final campus in campuses) {
      if (campus.campusId.toLowerCase() == normalized) return campus.campusId;
      if (campus.officialName.toLowerCase() == normalized) return campus.campusId;
      if (campus.shortName.toLowerCase() == normalized) return campus.campusId;
      if (campus.aliases.any((a) => a.toLowerCase() == normalized)) return campus.campusId;
    }
    return null;
  }

  static Campus? getById(String? id) {
    if (id == null) return null;
    return campuses.firstWhere(
      (c) => c.campusId == id,
      orElse: () => Campus(campusId: id, officialName: id, shortName: id),
    );
  }

  static String getDisplayName(String? id) {
    if (id == null) return 'Unknown Campus';
    final campus = getById(id);
    return campus?.officialName ?? id;
  }
}
