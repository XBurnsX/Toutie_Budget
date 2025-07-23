class Categorie {
  final String id;
  final String utilisateurId;
  final String nom;
  final int? ordre;

  Categorie({
    required this.id,
    required this.utilisateurId,
    required this.nom,
    this.ordre,
  });

  Categorie copyWith({
    String? id,
    String? utilisateurId,
    String? nom,
    int? ordre,
  }) {
    return Categorie(
      id: id ?? this.id,
      utilisateurId: utilisateurId ?? this.utilisateurId,
      nom: nom ?? this.nom,
      ordre: ordre ?? this.ordre,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'utilisateur_id': utilisateurId,
      'nom': nom,
      'ordre': ordre,
    };
  }

  factory Categorie.fromMap(Map<String, dynamic> map) {
    return Categorie(
      id: map['id'] ?? '',
      utilisateurId: map['utilisateur_id'] ?? '',
      nom: map['nom'] ?? '',
      ordre: map['ordre'],
    );
  }

  @override
  String toString() {
    return 'Categorie{id: $id, nom: $nom, utilisateurId: $utilisateurId, ordre: $ordre}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Categorie && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // Getter de compatibilité pour l'ancien code
  String? get userId => utilisateurId;
}
