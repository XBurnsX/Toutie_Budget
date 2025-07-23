class AllocationMensuelle {
  final String id;
  final String utilisateurId;
  final String enveloppeId;
  final DateTime mois;
  final double solde;
  final double alloue;
  final double depense;
  final String compteSourceId;
  final String collectionCompteSource;

  AllocationMensuelle({
    required this.id,
    required this.utilisateurId,
    required this.enveloppeId,
    required this.mois,
    required this.solde,
    required this.alloue,
    required this.depense,
    required this.compteSourceId,
    required this.collectionCompteSource,
  });

  factory AllocationMensuelle.fromMap(Map<String, dynamic> map) {
    return AllocationMensuelle(
      id: map['id'] ?? '',
      utilisateurId: map['utilisateur_id'] ?? '',
      enveloppeId: map['enveloppe_id'] ?? '',
      mois: map['mois'] != null ? DateTime.parse(map['mois']) : DateTime.now(),
      solde: (map['solde'] ?? 0).toDouble(),
      alloue: (map['alloue'] ?? 0).toDouble(),
      depense: (map['depense'] ?? 0).toDouble(),
      compteSourceId: map['compte_source_id'] ?? '',
      collectionCompteSource: map['collection_compte_source'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'utilisateur_id': utilisateurId,
      'enveloppe_id': enveloppeId,
      'mois': mois.toIso8601String(),
      'solde': solde,
      'alloue': alloue,
      'depense': depense,
      'compte_source_id': compteSourceId,
      'collection_compte_source': collectionCompteSource,
    };
  }

  AllocationMensuelle copyWith({
    String? id,
    String? utilisateurId,
    String? enveloppeId,
    DateTime? mois,
    double? solde,
    double? alloue,
    double? depense,
    String? compteSourceId,
    String? collectionCompteSource,
  }) {
    return AllocationMensuelle(
      id: id ?? this.id,
      utilisateurId: utilisateurId ?? this.utilisateurId,
      enveloppeId: enveloppeId ?? this.enveloppeId,
      mois: mois ?? this.mois,
      solde: solde ?? this.solde,
      alloue: alloue ?? this.alloue,
      depense: depense ?? this.depense,
      compteSourceId: compteSourceId ?? this.compteSourceId,
      collectionCompteSource: collectionCompteSource ?? this.collectionCompteSource,
    );
  }

  @override
  String toString() {
    return 'AllocationMensuelle{id: $id, enveloppeId: $enveloppeId, mois: $mois, alloue: $alloue, solde: $solde}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AllocationMensuelle && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // Getters utiles pour la logique métier
  double get montantDisponible => solde - depense;
  bool get estEpuise => montantDisponible <= 0;
  double get pourcentageUtilise => solde > 0 ? (depense / solde) * 100 : 0;
}
