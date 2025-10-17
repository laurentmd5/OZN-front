// lib/src/core/constants/app_constants.dart

/// Constantes essentielles pour le MVP
abstract class AppConstants {
  static const String appName = 'OZN';
  static const double maxSearchRadius = 500.0;
  static const double defaultBorderRadius = 12.0;
  static const double buttonBorderRadius = 25.0;
}

/// Rôles utilisateur MVP
enum UserRole {
  driver('Conducteur'),
  passenger('Passager'),
  both('Les deux');

  const UserRole(this.label);
  final String label;
}

/// Statuts des courses MVP
enum TripStatus {
  pending('En attente'),
  confirmed('Confirmé'), 
  active('En cours'),
  completed('Terminé'),
  cancelled('Annulé');

  const TripStatus(this.label);
  final String label;
}