class Tiers {
  final String id;
  final String utilisateurId;
  final String nom;
  final DateTime created;
  final DateTime updated;

  Tiers({
    required this.id,
    required this.utilisateurId,
    required this.nom,
    required this.created,
    required this.updated,
  });

  factory Tiers.fromMap(Map<String, dynamic> map) {
    return Tiers(
      id: map['id'] ?? '',
      utilisateurId: map['utilisateur_id'] ?? '',
      nom: map['nom'] ?? '',
      created: map['created'] != null ? DateTime.parse(map['created']) : DateTime.now(),
      updated: map['updated'] != null ? DateTime.parse(map['updated']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'utilisateur_id': utilisateurId,
      'nom': nom,
      'created': created.toIso8601String(),
      'updated': updated.toIso8601String(),
    };
  }

  Tiers copyWith({
    String? id,
    String? utilisateurId,
    String? nom,
    DateTime? created,
    DateTime? updated,
  }) {
    return Tiers(
      id: id ?? this.id,
      utilisateurId: utilisateurId ?? this.utilisateurId,
      nom: nom ?? this.nom,
      created: created ?? this.created,
      updated: updated ?? this.updated,
    );
  }

  @override
  String toString() {
    return 'Tiers{id: $id, nom: $nom, utilisateurId: $utilisateurId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Tiers && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // Getters utiles pour la logique métier
  String get nomAffichage => nom.trim().isEmpty ? 'Tiers sans nom' : nom;
  bool get nomValide => nom.trim().isNotEmpty;
  
  // Getter de compatibilité pour l'ancien code
  String get userId => utilisateurId;
}
