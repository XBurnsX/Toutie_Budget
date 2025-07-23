class CompteDette {
  final String id;
  final String utilisateurId;
  final String nom;
  final double soldeDette;
  final double tauxInteret;
  final double montantInitial;
  final double paiementMinimum;
  final int? ordre;
  final bool archive;
  final DateTime created;
  final DateTime updated;

  CompteDette({
    required this.id,
    required this.utilisateurId,
    required this.nom,
    required this.soldeDette,
    required this.tauxInteret,
    required this.montantInitial,
    required this.paiementMinimum,
    this.ordre,
    required this.archive,
    required this.created,
    required this.updated,
  });

  factory CompteDette.fromMap(Map<String, dynamic> map) {
    return CompteDette(
      id: map['id'] ?? '',
      utilisateurId: map['utilisateur_id'] ?? '',
      nom: map['nom'] ?? '',
      soldeDette: (map['solde_dette'] ?? 0).toDouble(),
      tauxInteret: (map['taux_interet'] ?? 0).toDouble(),
      montantInitial: (map['montant_initial'] ?? 0).toDouble(),
      paiementMinimum: (map['paiement_minimum'] ?? 0).toDouble(),
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
      'solde_dette': soldeDette,
      'taux_interet': tauxInteret,
      'montant_initial': montantInitial,
      'paiement_minimum': paiementMinimum,
      'ordre': ordre,
      'archive': archive,
      'created': created.toIso8601String(),
      'updated': updated.toIso8601String(),
    };
  }

  CompteDette copyWith({
    String? id,
    String? utilisateurId,
    String? nom,
    double? soldeDette,
    double? tauxInteret,
    double? montantInitial,
    double? paiementMinimum,
    int? ordre,
    bool? archive,
    DateTime? created,
    DateTime? updated,
  }) {
    return CompteDette(
      id: id ?? this.id,
      utilisateurId: utilisateurId ?? this.utilisateurId,
      nom: nom ?? this.nom,
      soldeDette: soldeDette ?? this.soldeDette,
      tauxInteret: tauxInteret ?? this.tauxInteret,
      montantInitial: montantInitial ?? this.montantInitial,
      paiementMinimum: paiementMinimum ?? this.paiementMinimum,
      ordre: ordre ?? this.ordre,
      archive: archive ?? this.archive,
      created: created ?? this.created,
      updated: updated ?? this.updated,
    );
  }

  @override
  String toString() {
    return 'CompteDette{id: $id, nom: $nom, soldeDette: $soldeDette, montantInitial: $montantInitial, pourcentageRembourse: ${pourcentageRembourse.toStringAsFixed(1)}%}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CompteDette && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // Getters utiles pour la logique métier
  bool get estActif => !archive;
  double get montantRembourse => montantInitial - soldeDette;
  double get pourcentageRembourse => montantInitial > 0 ? (montantRembourse / montantInitial) * 100 : 0;
  bool get estPresqueRembourse => pourcentageRembourse >= 90;
  bool get estEntierementRembourse => soldeDette <= 0;
  double get interetsMensuels => (soldeDette * tauxInteret) / 12 / 100;
  
  // Calcul du temps de remboursement estimé (en mois)
  int get moisPourRemboursementComplet {
    if (paiementMinimum <= interetsMensuels) return -1; // Jamais remboursé
    if (soldeDette <= 0) return 0;
    
    double paiementCapital = paiementMinimum - interetsMensuels;
    return (soldeDette / paiementCapital).ceil();
  }
  
  // Getters de compatibilité pour l'ancien code
  String get userId => utilisateurId;
  String get type => 'Dette';
  bool get estArchive => archive;
  DateTime get dateCreation => created;
  double get solde => -soldeDette; // Négatif car c'est une dette
}
