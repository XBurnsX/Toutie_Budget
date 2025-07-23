class Enveloppe {
  final String id;
  final String utilisateurId;
  final String categorieId;
  final String nom;
  final DateTime? objectifDate;
  final String frequenceObjectif;
  final String compteProvenanceId;
  final int? ordre;
  final double soldeEnveloppe;
  final double depense;
  final bool estArchive;
  final double objectifMontant;
  final DateTime? moisObjectif;

  Enveloppe({
    required this.id,
    required this.utilisateurId,
    required this.categorieId,
    required this.nom,
    this.objectifDate,
    required this.frequenceObjectif,
    required this.compteProvenanceId,
    this.ordre,
    required this.soldeEnveloppe,
    required this.depense,
    required this.estArchive,
    required this.objectifMontant,
    this.moisObjectif,
  });

  factory Enveloppe.fromMap(Map<String, dynamic> map) {
    return Enveloppe(
      id: map['id'] ?? '',
      utilisateurId: map['utilisateur_id'] ?? '',
      categorieId: map['categorie_id'] ?? '',
      nom: map['nom'] ?? '',
      objectifDate: map['objectif_date'] != null ? DateTime.parse(map['objectif_date']) : null,
      frequenceObjectif: map['frequence_objectif'] ?? 'mensuel',
      compteProvenanceId: map['compte_provenance_id'] ?? '',
      ordre: map['ordre'],
      soldeEnveloppe: (map['solde_enveloppe'] ?? 0).toDouble(),
      depense: (map['depense'] ?? 0).toDouble(),
      estArchive: map['est_archive'] ?? false,
      objectifMontant: (map['objectif_montant'] ?? 0).toDouble(),
      moisObjectif: map['moisObjectif'] != null ? DateTime.parse(map['moisObjectif']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'utilisateur_id': utilisateurId,
      'categorie_id': categorieId,
      'nom': nom,
      'objectif_date': objectifDate?.toIso8601String(),
      'frequence_objectif': frequenceObjectif,
      'compte_provenance_id': compteProvenanceId,
      'ordre': ordre,
      'solde_enveloppe': soldeEnveloppe,
      'depense': depense,
      'est_archive': estArchive,
      'objectif_montant': objectifMontant,
      'moisObjectif': moisObjectif?.toIso8601String(),
    };
  }

  Enveloppe copyWith({
    String? id,
    String? utilisateurId,
    String? categorieId,
    String? nom,
    DateTime? objectifDate,
    String? frequenceObjectif,
    String? compteProvenanceId,
    int? ordre,
    double? soldeEnveloppe,
    double? depense,
    bool? estArchive,
    double? objectifMontant,
    DateTime? moisObjectif,
  }) {
    return Enveloppe(
      id: id ?? this.id,
      utilisateurId: utilisateurId ?? this.utilisateurId,
      categorieId: categorieId ?? this.categorieId,
      nom: nom ?? this.nom,
      objectifDate: objectifDate ?? this.objectifDate,
      frequenceObjectif: frequenceObjectif ?? this.frequenceObjectif,
      compteProvenanceId: compteProvenanceId ?? this.compteProvenanceId,
      ordre: ordre ?? this.ordre,
      soldeEnveloppe: soldeEnveloppe ?? this.soldeEnveloppe,
      depense: depense ?? this.depense,
      estArchive: estArchive ?? this.estArchive,
      objectifMontant: objectifMontant ?? this.objectifMontant,
      moisObjectif: moisObjectif ?? this.moisObjectif,
    );
  }

  @override
  String toString() {
    return 'Enveloppe{id: $id, nom: $nom, soldeEnveloppe: $soldeEnveloppe, objectifMontant: $objectifMontant, estArchive: $estArchive}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Enveloppe && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // Getters de compatibilité pour l'ancien code
  double get solde => soldeEnveloppe;
  double get objectif => objectifMontant;
  bool get archivee => estArchive;
  String get provenanceCompteId => compteProvenanceId;
}
