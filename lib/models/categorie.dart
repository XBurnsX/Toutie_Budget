class Enveloppe {
  final String id;
  final String nom;
  final double solde;
  final double objectif;
  final String? objectifDate;
  final double? depense;
  final bool archivee;
  final String provenanceCompteId;
  final String frequenceObjectif;
  final DateTime? dateDernierAjout;
  final int? objectifJour;
  final Map<String, dynamic>? historique;
  final int? ordre;

  Enveloppe({
    required this.id,
    required this.nom,
    this.solde = 0.0,
    this.objectif = 0.0,
    this.objectifDate,
    this.depense,
    this.archivee = false,
    this.provenanceCompteId = '',
    this.frequenceObjectif = 'mensuel',
    this.dateDernierAjout,
    this.objectifJour,
    this.historique,
    this.ordre,
  });

  Enveloppe copyWith({
    String? id,
    String? nom,
    double? solde,
    double? objectif,
    String? objectifDate,
    double? depense,
    bool? archivee,
    String? provenanceCompteId,
    String? frequenceObjectif,
    DateTime? dateDernierAjout,
    int? objectifJour,
    Map<String, dynamic>? historique,
    int? ordre,
  }) {
    return Enveloppe(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      solde: solde ?? this.solde,
      objectif: objectif ?? this.objectif,
      objectifDate: objectifDate ?? this.objectifDate,
      depense: depense ?? this.depense,
      archivee: archivee ?? this.archivee,
      provenanceCompteId: provenanceCompteId ?? this.provenanceCompteId,
      frequenceObjectif: frequenceObjectif ?? this.frequenceObjectif,
      dateDernierAjout: dateDernierAjout ?? this.dateDernierAjout,
      objectifJour: objectifJour ?? this.objectifJour,
      historique: historique ?? this.historique,
      ordre: ordre ?? this.ordre,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'nom': nom,
        'solde': solde,
        'objectif': objectif,
        'objectif_date': objectifDate,
        'depense': depense,
        'archivee': archivee,
        'provenance_compte_id': provenanceCompteId,
        'frequence_objectif': frequenceObjectif,
        'date_dernier_ajout': dateDernierAjout?.toIso8601String(),
        'objectif_jour': objectifJour,
        'historique': historique,
        'ordre': ordre,
      };

  factory Enveloppe.fromMap(Map<String, dynamic> map) => Enveloppe(
        id: map['id'] ?? '',
        nom: map['nom'] ?? '',
        solde: (map['solde'] ?? 0.0).toDouble(),
        objectif: (map['objectif'] ?? 0.0).toDouble(),
        objectifDate: map['objectif_date'],
        depense: (map['depense'] ?? 0.0).toDouble(),
        archivee: map['archivee'] ?? false,
        provenanceCompteId: map['provenance_compte_id'] ?? '',
        frequenceObjectif: map['frequence_objectif'] ?? 'mensuel',
        dateDernierAjout: map['date_dernier_ajout'] != null
            ? DateTime.tryParse(map['date_dernier_ajout'])
            : null,
        objectifJour: map['objectif_jour'],
        historique: map['historique'] != null
            ? Map<String, dynamic>.from(map['historique'])
            : null,
        ordre: map['ordre'],
      );
}

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
