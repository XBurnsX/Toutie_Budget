class CompteCredit {
  final String id;
  final String utilisateurId;
  final String nom;
  final double limiteCredit;
  final double soldeUtilise;
  final double tauxInteret;
  final String couleur;
  final int? ordre;
  final bool archive;
  final DateTime created;
  final DateTime updated;

  CompteCredit({
    required this.id,
    required this.utilisateurId,
    required this.nom,
    required this.limiteCredit,
    required this.soldeUtilise,
    required this.tauxInteret,
    required this.couleur,
    this.ordre,
    required this.archive,
    required this.created,
    required this.updated,
  });

  factory CompteCredit.fromMap(Map<String, dynamic> map) {
    return CompteCredit(
      id: map['id'] ?? '',
      utilisateurId: map['utilisateur_id'] ?? '',
      nom: map['nom'] ?? '',
      limiteCredit: (map['limite_credit'] ?? 0).toDouble(),
      soldeUtilise: (map['solde_utilise'] ?? 0).toDouble(),
      tauxInteret: (map['taux_interet'] ?? 0).toDouble(),
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
      'limite_credit': limiteCredit,
      'solde_utilise': soldeUtilise,
      'taux_interet': tauxInteret,
      'couleur': couleur,
      'ordre': ordre,
      'archive': archive,
      'created': created.toIso8601String(),
      'updated': updated.toIso8601String(),
    };
  }

  CompteCredit copyWith({
    String? id,
    String? utilisateurId,
    String? nom,
    double? limiteCredit,
    double? soldeUtilise,
    double? tauxInteret,
    String? couleur,
    int? ordre,
    bool? archive,
    DateTime? created,
    DateTime? updated,
  }) {
    return CompteCredit(
      id: id ?? this.id,
      utilisateurId: utilisateurId ?? this.utilisateurId,
      nom: nom ?? this.nom,
      limiteCredit: limiteCredit ?? this.limiteCredit,
      soldeUtilise: soldeUtilise ?? this.soldeUtilise,
      tauxInteret: tauxInteret ?? this.tauxInteret,
      couleur: couleur ?? this.couleur,
      ordre: ordre ?? this.ordre,
      archive: archive ?? this.archive,
      created: created ?? this.created,
      updated: updated ?? this.updated,
    );
  }

  @override
  String toString() {
    return 'CompteCredit{id: $id, nom: $nom, soldeUtilise: $soldeUtilise, limiteCredit: $limiteCredit, creditDisponible: $creditDisponible}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CompteCredit && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // Getters utiles pour la logique métier
  bool get estActif => !archive;
  double get creditDisponible => limiteCredit - soldeUtilise;
  double get pourcentageUtilise => limiteCredit > 0 ? (soldeUtilise / limiteCredit) * 100 : 0;
  bool get estProcheLimite => pourcentageUtilise >= 80;
  bool get estAuMaximum => soldeUtilise >= limiteCredit;
  double get interetsMensuels => (soldeUtilise * tauxInteret) / 12 / 100;
  
  // Getters de compatibilité pour l'ancien code
  String get userId => utilisateurId;
  String get type => 'Carte de crédit';
  bool get estArchive => archive;
  DateTime get dateCreation => created;
  double get solde => -soldeUtilise; // Négatif car c'est une dette
}
