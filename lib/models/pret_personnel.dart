enum TypePretPersonnel {
  pret,
  dette,
}

extension TypePretPersonnelExtension on TypePretPersonnel {
  String get nom {
    switch (this) {
      case TypePretPersonnel.pret:
        return 'pret';
      case TypePretPersonnel.dette:
        return 'dette';
    }
  }
  
  bool get estPret => this == TypePretPersonnel.pret;
  bool get estDette => this == TypePretPersonnel.dette;
}

class PretPersonnel {
  final String id;
  final String utilisateurId;
  final String nomTiers;
  final double montantInitial;
  final double solde;
  final TypePretPersonnel type;
  final bool archive;
  final DateTime dateCreation;
  final DateTime created;
  final DateTime updated;

  PretPersonnel({
    required this.id,
    required this.utilisateurId,
    required this.nomTiers,
    required this.montantInitial,
    required this.solde,
    required this.type,
    required this.archive,
    required this.dateCreation,
    required this.created,
    required this.updated,
  });

  factory PretPersonnel.fromMap(Map<String, dynamic> map) {
    return PretPersonnel(
      id: map['id'] ?? '',
      utilisateurId: map['utilisateur_id'] ?? '',
      nomTiers: map['nom_tiers'] ?? '',
      montantInitial: (map['montant_initial'] ?? 0).toDouble(),
      solde: (map['solde'] ?? 0).toDouble(),
      type: _parseType(map['type']),
      archive: map['archive'] ?? false,
      dateCreation: map['date_creation'] != null 
          ? DateTime.parse(map['date_creation']) 
          : DateTime.now(),
      created: map['created'] != null ? DateTime.parse(map['created']) : DateTime.now(),
      updated: map['updated'] != null ? DateTime.parse(map['updated']) : DateTime.now(),
    );
  }

  static TypePretPersonnel _parseType(dynamic value) {
    if (value == null) return TypePretPersonnel.dette;
    switch (value.toString().toLowerCase()) {
      case 'pret':
        return TypePretPersonnel.pret;
      case 'dette':
        return TypePretPersonnel.dette;
      default:
        return TypePretPersonnel.dette;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'utilisateur_id': utilisateurId,
      'nom_tiers': nomTiers,
      'montant_initial': montantInitial,
      'solde': solde,
      'type': type.nom,
      'archive': archive,
      'date_creation': dateCreation.toIso8601String(),
      'created': created.toIso8601String(),
      'updated': updated.toIso8601String(),
    };
  }

  PretPersonnel copyWith({
    String? id,
    String? utilisateurId,
    String? nomTiers,
    double? montantInitial,
    double? solde,
    TypePretPersonnel? type,
    bool? archive,
    DateTime? dateCreation,
    DateTime? created,
    DateTime? updated,
  }) {
    return PretPersonnel(
      id: id ?? this.id,
      utilisateurId: utilisateurId ?? this.utilisateurId,
      nomTiers: nomTiers ?? this.nomTiers,
      montantInitial: montantInitial ?? this.montantInitial,
      solde: solde ?? this.solde,
      type: type ?? this.type,
      archive: archive ?? this.archive,
      dateCreation: dateCreation ?? this.dateCreation,
      created: created ?? this.created,
      updated: updated ?? this.updated,
    );
  }

  @override
  String toString() {
    return 'PretPersonnel{id: $id, nomTiers: $nomTiers, type: ${type.nom}, solde: $solde, montantInitial: $montantInitial, statut: $statut}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PretPersonnel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // Getters utiles pour la logique métier
  bool get estActif => !archive;
  double get montantRembourse => montantInitial - solde;
  double get pourcentageRembourse => montantInitial > 0 ? (montantRembourse / montantInitial) * 100 : 0;
  bool get estEntierementRembourse => solde <= 0;
  bool get estPresqueRembourse => pourcentageRembourse >= 90;
  
  // Statut textuel
  String get statut {
    if (estEntierementRembourse) return 'Remboursé';
    if (estPresqueRembourse) return 'Presque remboursé';
    return 'En cours';
  }
  
  // Pour les prêts accordés : montant à récupérer
  // Pour les dettes contractées : montant à rembourser
  double get montantRestant => solde;
  
  // Impact sur le patrimoine (positif pour prêt accordé, négatif pour dette contractée)
  double get impactPatrimoine => type.estPret ? solde : -solde;
  
  // Getters de compatibilité pour l'ancien code
  String get userId => utilisateurId;
  bool get estArchive => archive;
  String get typeString => type.nom;
}
