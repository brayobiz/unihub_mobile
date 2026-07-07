import '../location/models/campus.dart';

  /// Legacy Constants class being phased out in favor of [CampusRepository].
  /// For now, it provides a bridge to ensure existing features continue to work.
  class CampusConstants {
    // This will be replaced by a stream from Firestore in the next phase
    static final List<Campus> campuses = [
      Campus(id: 'uon_main', name: 'University of Nairobi', shortName: 'UoN', latitude: -1.2801, longitude: 36.8163, defaultZoom: 15.0, country: 'Kenya', city: 'Nairobi', aliases: ['Main Campus', 'UON', 'Varsity']),
      Campus(id: 'ku_main', name: 'Kenyatta University', shortName: 'KU', latitude: -1.1813, longitude: 36.9312, defaultZoom: 15.0, country: 'Kenya', city: 'Nairobi', aliases: ['Kahawa', 'Green Campus']),
      Campus(id: 'strath_main', name: 'Strathmore University', shortName: 'SU', latitude: -1.3098, longitude: 36.8126, defaultZoom: 16.0, country: 'Kenya', city: 'Nairobi', aliases: ['Strathmore', 'Strath']),
      Campus(id: 'jkuat_main', name: 'Jomo Kenyatta University (JKUAT)', shortName: 'JKUAT', latitude: -1.1026, longitude: 37.0135, defaultZoom: 15.0, country: 'Kenya', city: 'Juja', aliases: ['Juja']),
      Campus(id: 'usiu_main', name: 'United States International University', shortName: 'USIU-A', latitude: -1.2185, longitude: 36.8795, defaultZoom: 16.0, country: 'Kenya', city: 'Nairobi', aliases: ['USIU']),
      Campus(id: 'daystar_athi', name: 'Daystar University (Athi River)', shortName: 'Daystar', latitude: -1.4485, longitude: 37.0394, defaultZoom: 15.0, country: 'Kenya', city: 'Athi River'),
      Campus(id: 'mku_main', name: 'Mount Kenya University (Main)', shortName: 'MKU', latitude: -1.0475, longitude: 37.0831, defaultZoom: 16.0, country: 'Kenya', city: 'Thika', aliases: ['MKU', 'Mku']),
      Campus(id: 'egerton_main', name: 'Egerton University (Njoro)', shortName: 'EU', latitude: -0.3697, longitude: 35.9281, defaultZoom: 15.0, country: 'Kenya', city: 'Njoro', aliases: ['Njoro', 'Egerton']),
      Campus(id: 'moi_main', name: 'Moi University (Main)', shortName: 'MU', latitude: 0.2831, longitude: 35.2917, defaultZoom: 15.0, country: 'Kenya', city: 'Eldoret', aliases: ['Kesses', 'Moi']),
      Campus(id: 'tukenya_main', name: 'Technical University of Kenya', shortName: 'TUK', latitude: -1.2919, longitude: 36.8224, defaultZoom: 16.0, country: 'Kenya', city: 'Nairobi', aliases: ['Npoly']),
      Campus(id: 'dekut_main', name: 'Dedan Kimathi University', shortName: 'DeKUT', latitude: -0.3978, longitude: 36.9611, defaultZoom: 15.5, country: 'Kenya', city: 'Nyeri', aliases: ['Kimathi']),
      Campus(id: 'maseno_main', name: 'Maseno University', shortName: 'MSU', latitude: -0.0044, longitude: 34.6015, defaultZoom: 15.0, country: 'Kenya', city: 'Maseno', aliases: ['The Equator University']),
      Campus(id: 'chuka_main', name: 'Chuka University', shortName: 'Chuka', latitude: -0.3325, longitude: 37.6475, defaultZoom: 15.5, country: 'Kenya', city: 'Chuka'),
      Campus(id: 'mmust_main', name: 'Masinde Muliro University', shortName: 'MMUST', latitude: 0.2827, longitude: 34.7617, defaultZoom: 15.5, country: 'Kenya', city: 'Kakamega'),
      Campus(id: 'kisii_main', name: 'Kisii University', shortName: 'KSU', latitude: -0.6861, longitude: 34.7772, defaultZoom: 15.5, country: 'Kenya', city: 'Kisii', aliases: ['Kisii']),
      Campus(id: 'tum_main', name: 'Technical University of Mombasa', shortName: 'TUM', latitude: -4.0379, longitude: 39.6678, defaultZoom: 15.5, country: 'Kenya', city: 'Mombasa'),
      Campus(id: 'pwani_main', name: 'Pwani University', shortName: 'Pwani', latitude: -3.6200, longitude: 39.8466, defaultZoom: 15.5, country: 'Kenya', city: 'Kilifi'),
      Campus(id: 'uoe_main', name: 'University of Eldoret', shortName: 'UoE', latitude: 0.5792, longitude: 35.3061, defaultZoom: 15.5, country: 'Kenya', city: 'Eldoret'),
      Campus(id: 'meru_main', name: 'Meru University of Science and Tech', shortName: 'MUST', latitude: 0.1350, longitude: 37.7083, defaultZoom: 15.5, country: 'Kenya', city: 'Meru'),
      Campus(id: 'karatina_main', name: 'Karatina University', shortName: 'Karatina', latitude: -0.3894, longitude: 37.1450, defaultZoom: 15.5, country: 'Kenya', city: 'Karatina'),
      Campus(id: 'seku_main', name: 'South Eastern Kenya University', shortName: 'SEKU', latitude: -1.5034, longitude: 37.7554, defaultZoom: 15.5, country: 'Kenya', city: 'Kitui'),
      Campus(id: 'mmu_main', name: 'Multimedia University of Kenya', shortName: 'MMU', latitude: -1.4032, longitude: 36.7257, defaultZoom: 15.5, country: 'Kenya', city: 'Nairobi'),
      Campus(id: 'laikipia_main', name: 'Laikipia University', shortName: 'LU', latitude: 0.0411, longitude: 36.3225, defaultZoom: 15.5, country: 'Kenya', city: 'Nyahururu'),
      Campus(id: 'mmarau_main', name: 'Maasai Mara University', shortName: 'MMARAU', latitude: -1.0931, longitude: 35.8578, defaultZoom: 15.5, country: 'Kenya', city: 'Narok'),
      Campus(id: 'jooust_main', name: 'Jaramogi Oginga Odinga University', shortName: 'JOOUST', latitude: -0.0939, longitude: 34.2586, defaultZoom: 15.5, country: 'Kenya', city: 'Bondo'),
      Campus(id: 'kibabii_main', name: 'Kibabii University', shortName: 'KIBU', latitude: 0.6179, longitude: 34.5243, defaultZoom: 15.5, country: 'Kenya', city: 'Bungoma'),
      Campus(id: 'rongo_main', name: 'Rongo University', shortName: 'RU', latitude: -0.8257, longitude: 34.6107, defaultZoom: 15.5, country: 'Kenya', city: 'Rongo'),
      Campus(id: 'embu_main', name: 'University of Embu', shortName: 'UoEm', latitude: -0.5149, longitude: 37.4563, defaultZoom: 15.5, country: 'Kenya', city: 'Embu'),
      Campus(id: 'kirinyaga_main', name: 'Kirinyaga University', shortName: 'KyU', latitude: -0.5022, longitude: 37.2792, defaultZoom: 15.5, country: 'Kenya', city: 'Kutus'),
      Campus(id: 'machakos_main', name: 'Machakos University', shortName: 'MksU', latitude: -1.5316, longitude: 37.2625, defaultZoom: 15.5, country: 'Kenya', city: 'Machakos'),
      Campus(id: 'ttu_main', name: 'Taita Taveta University', shortName: 'TTU', latitude: -3.4201, longitude: 38.5033, defaultZoom: 15.5, country: 'Kenya', city: 'Voi'),
      Campus(id: 'muranga_main', name: 'Murang\'a University of Technology', shortName: 'MUT', latitude: -0.7160, longitude: 37.1470, defaultZoom: 15.5, country: 'Kenya', city: 'Murang\'a'),
      Campus(id: 'coop_main', name: 'Co-operative University of Kenya', shortName: 'CUK', latitude: -1.3650, longitude: 36.7210, defaultZoom: 15.5, country: 'Kenya', city: 'Nairobi'),
      Campus(id: 'cuea_main', name: 'Catholic University of E. Africa', shortName: 'CUEA', latitude: -1.3506, longitude: 36.7570, defaultZoom: 15.5, country: 'Kenya', city: 'Nairobi'),
      Campus(id: 'anu_main', name: 'Africa Nazarene University', shortName: 'ANU', latitude: -1.3994, longitude: 36.7562, defaultZoom: 15.5, country: 'Kenya', city: 'Nairobi'),
      Campus(id: 'kca_main', name: 'KCA University', shortName: 'KCAU', latitude: -1.2429, longitude: 36.8647, defaultZoom: 15.5, country: 'Kenya', city: 'Nairobi'),
      Campus(id: 'kabarak_main', name: 'Kabarak University', shortName: 'KABU', latitude: -0.1706, longitude: 35.9525, defaultZoom: 15.5, country: 'Kenya', city: 'Nakuru'),
      Campus(id: 'kemu_main', name: 'Kenya Methodist University', shortName: 'KeMU', latitude: 0.0843, longitude: 37.6492, defaultZoom: 15.5, country: 'Kenya', city: 'Meru'),
      Campus(id: 'stpauls_main', name: 'St. Paul\'s University', shortName: 'SPU', latitude: -1.1484, longitude: 36.6669, defaultZoom: 15.5, country: 'Kenya', city: 'Limuru'),
      Campus(id: 'zetech_main', name: 'Zetech University', shortName: 'ZU', latitude: -1.2630, longitude: 36.8036, defaultZoom: 15.5, country: 'Kenya', city: 'Ruiru'),
      Campus(id: 'riara_main', name: 'Riara University', shortName: 'Riara', latitude: -1.3140, longitude: 36.8080, defaultZoom: 16.0, country: 'Kenya', city: 'Nairobi'),
      Campus(id: 'aku_main', name: 'Aga Khan University', shortName: 'AKU', latitude: -1.2618, longitude: 36.8208, defaultZoom: 16.0, country: 'Kenya', city: 'Nairobi'),
    ];

  static String? resolveToId(String? input) {
    if (input == null || input.isEmpty) return null;
    final normalized = input.trim().toLowerCase();
    
    for (final campus in campuses) {
      if (campus.id.toLowerCase() == normalized) return campus.id;
      if (campus.name.toLowerCase() == normalized) return campus.id;
      if (campus.shortName.toLowerCase() == normalized) return campus.id;
      if (campus.aliases.any((a) => a.toLowerCase() == normalized)) return campus.id;
    }
    return null;
  }

  static Campus? getById(String? id) {
    if (id == null) return null;
    try {
      return campuses.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  static String getDisplayName(String? id) {
    if (id == null) return 'Unknown Campus';
    final campus = getById(id);
    return campus?.name ?? id;
  }

  static String getShortDisplayName(String? id) {
    if (id == null) return 'Unknown';
    final campus = getById(id);
    if (campus == null) return id;
    return campus.shortName.isNotEmpty ? campus.shortName : campus.name;
  }
}
