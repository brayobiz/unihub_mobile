class SystemSettings {
  final String supportEmail;
  final String privacyPolicyUrl;
  final String termsOfServiceUrl;
  final String websiteUrl;
  final Map<String, String> socialLinks;
  final bool maintenanceMode;
  final String maintenanceMessage;
  final String appVersion;
  final DateTime lastUpdated;
  final String updatedBy;

  SystemSettings({
    required this.supportEmail,
    required this.privacyPolicyUrl,
    required this.termsOfServiceUrl,
    required this.websiteUrl,
    required this.socialLinks,
    required this.maintenanceMode,
    required this.maintenanceMessage,
    required this.appVersion,
    required this.lastUpdated,
    required this.updatedBy,
  });

  factory SystemSettings.fromJson(Map<String, dynamic> json) {
    return SystemSettings(
      supportEmail: json['supportEmail'] ?? '',
      privacyPolicyUrl: json['privacyPolicyUrl'] ?? '',
      termsOfServiceUrl: json['termsOfServiceUrl'] ?? '',
      websiteUrl: json['websiteUrl'] ?? '',
      socialLinks: Map<String, String>.from(json['socialLinks'] ?? {}),
      maintenanceMode: json['maintenanceMode'] ?? false,
      maintenanceMessage: json['maintenanceMessage'] ?? 'Ulify is currently under maintenance. We\'ll be back shortly!',
      appVersion: json['appVersion'] ?? '1.0.0',
      lastUpdated: json['lastUpdated'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['lastUpdated']) 
          : DateTime.now(),
      updatedBy: json['updatedBy'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'supportEmail': supportEmail,
      'privacyPolicyUrl': privacyPolicyUrl,
      'termsOfServiceUrl': termsOfServiceUrl,
      'websiteUrl': websiteUrl,
      'socialLinks': socialLinks,
      'maintenanceMode': maintenanceMode,
      'maintenanceMessage': maintenanceMessage,
      'appVersion': appVersion,
      'lastUpdated': lastUpdated.millisecondsSinceEpoch,
      'updatedBy': updatedBy,
    };
  }

  SystemSettings copyWith({
    String? supportEmail,
    String? privacyPolicyUrl,
    String? termsOfServiceUrl,
    String? websiteUrl,
    Map<String, String>? socialLinks,
    bool? maintenanceMode,
    String? maintenanceMessage,
    String? appVersion,
    DateTime? lastUpdated,
    String? updatedBy,
  }) {
    return SystemSettings(
      supportEmail: supportEmail ?? this.supportEmail,
      privacyPolicyUrl: privacyPolicyUrl ?? this.privacyPolicyUrl,
      termsOfServiceUrl: termsOfServiceUrl ?? this.termsOfServiceUrl,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      socialLinks: socialLinks ?? this.socialLinks,
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
      maintenanceMessage: maintenanceMessage ?? this.maintenanceMessage,
      appVersion: appVersion ?? this.appVersion,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
