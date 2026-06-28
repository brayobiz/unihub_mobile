enum ProfessionalRole {
  seller,
  housePlug,
  tutor,
  serviceProvider,
  technician,
  business;

  String get label {
    switch (this) {
      case ProfessionalRole.seller: return 'Verified Seller';
      case ProfessionalRole.housePlug: return 'Verified House Plug';
      case ProfessionalRole.tutor: return 'Verified Tutor';
      case ProfessionalRole.serviceProvider: return 'Verified Service Provider';
      case ProfessionalRole.technician: return 'Verified Technician';
      case ProfessionalRole.business: return 'Verified Business';
    }
  }
}
