class CompteCheque {
  final String id;
  final String utilisateurId;
  final String nom;
  final double solde;
  final double pretAPlacer;
  final String couleur;
  final int? ordre;
  final bool archive;
  final DateTime created;
  final DateTime updated;

  CompteCheque({
    required this.id,
    required this.utilisateurId,
    required this.nom,
    required this.solde,
    required this.pretAPlacer,
    required this.couleur,
    this.ordre,
    required this.archive,
    required this.created,
    required this.updated,
  });

  factory CompteCheque.fromMap(Map<String, dynamic> map) {
    return CompteCheque(
      id: map['id'] ?? '',
      utilisateurId: map['utilisateur_id'] ?? '',
      nom: map['nom'] ?? '',
      solde: (map['solde'] ?? 0).toDouble(),
      pretAPlacer: (map['pret_a_placer'] ?? 0).toDouble(),
      couleur: map['couleur'] ?? '',
      ordre: map['ordre'],
      archive: map['archive'] ?? false,
      created: map['created'] != null ? DateTime.parse(map['created']) : DateTime.now(),
      updated: map['updated'] != null ? DateTime.parse(map['updated']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'utilisateur_id': utilisateurId,
      'nom': nom,
      'solde': solde,
      'pret_a_placer': pretAPlacer,
      'couleur': couleur,
      'ordre': ordre,
      'archive': archive,
      'created': created.toIso8601String(),
      'updated': updated.toIso8601String(),
    };
  }

  CompteCheque copyWith({
    String? id,
    String? utilisateurId,
    String? nom,
    double? solde,
    double? pretAPlacer,
    String? couleur,
    int? ordre,
    bool? archive,
    DateTime? created,
    DateTime? updated,
  }) {
    return CompteCheque(
      id: id ?? this.id,
      utilisateurId: utilisateurId ?? this.utilisateurId,
      nom: nom ?? this.nom,
      solde: solde ?? this.solde,
      pretAPlacer: pretAPlacer ?? this.pretAPlacer,
      couleur: couleur ?? this.couleur,
      ordre: ordre ?? this.ordre,
      archive: archive ?? this.archive,
      created: created ?? this.created,
      updated: updated ?? this.updated,
    );
  }

  @override
  String toString() {
    return 'CompteCheque{id: $id, nom: $nom, solde: $solde, pretAPlacer: $pretAPlacer, archive: $archive}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CompteCheque && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // Getters utiles pour la logique métier
  bool get estActif => !archive;
  double get soldeTotal => solde + pretAPlacer;
  bool get aPretAPlacer => pretAPlacer > 0;
  
  // Getters de compatibilité pour l'ancien code
  String get userId => utilisateurId;
  String get type => 'Chèque';
  bool get estArchive => archive;
  DateTime get dateCreation => created;
}
