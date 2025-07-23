class CompteInvestissement {
  final String id;
  final String utilisateurId;
  final String nom;
  final double valeurMarche;
  final double coutBase;
  final String couleur;
  final String symbole;
  final double nombreActions;
  final double prixMoyenAchat;
  final double prixActuel;
  final double variationPourcentage;
  final DateTime dateDerniereMaj;
  final Map<String, dynamic>? transactionsDetails;
  final int? ordre;
  final bool archive;
  final DateTime created;
  final DateTime updated;

  CompteInvestissement({
    required this.id,
    required this.utilisateurId,
    required this.nom,
    required this.valeurMarche,
    required this.coutBase,
    required this.couleur,
    required this.symbole,
    required this.nombreActions,
    required this.prixMoyenAchat,
    required this.prixActuel,
    required this.variationPourcentage,
    required this.dateDerniereMaj,
    this.transactionsDetails,
    this.ordre,
    required this.archive,
    required this.created,
    required this.updated,
  });

  factory CompteInvestissement.fromMap(Map<String, dynamic> map) {
    return CompteInvestissement(
      id: map['id'] ?? '',
      utilisateurId: map['utilisateur_id'] ?? '',
      nom: map['nom'] ?? '',
      valeurMarche: (map['valeur_marche'] ?? 0).toDouble(),
      coutBase: (map['cout_base'] ?? 0).toDouble(),
      couleur: map['couleur'] ?? '',
      symbole: map['symbole'] ?? '',
      nombreActions: (map['nombre_actions'] ?? 0).toDouble(),
      prixMoyenAchat: (map['prix_moyen_achat'] ?? 0).toDouble(),
      prixActuel: (map['prix_actuel'] ?? 0).toDouble(),
      variationPourcentage: (map['variation_pourcentage'] ?? 0).toDouble(),
      dateDerniereMaj: map['date_derniere_maj'] != null 
          ? DateTime.parse(map['date_derniere_maj']) 
          : DateTime.now(),
      transactionsDetails: map['transactions_details'] as Map<String, dynamic>?,
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
      'valeur_marche': valeurMarche,
      'cout_base': coutBase,
      'couleur': couleur,
      'symbole': symbole,
      'nombre_actions': nombreActions,
      'prix_moyen_achat': prixMoyenAchat,
      'prix_actuel': prixActuel,
      'variation_pourcentage': variationPourcentage,
      'date_derniere_maj': dateDerniereMaj.toIso8601String(),
      'transactions_details': transactionsDetails,
      'ordre': ordre,
      'archive': archive,
      'created': created.toIso8601String(),
      'updated': updated.toIso8601String(),
    };
  }

  CompteInvestissement copyWith({
    String? id,
    String? utilisateurId,
    String? nom,
    double? valeurMarche,
    double? coutBase,
    String? couleur,
    String? symbole,
    double? nombreActions,
    double? prixMoyenAchat,
    double? prixActuel,
    double? variationPourcentage,
    DateTime? dateDerniereMaj,
    Map<String, dynamic>? transactionsDetails,
    int? ordre,
    bool? archive,
    DateTime? created,
    DateTime? updated,
  }) {
    return CompteInvestissement(
      id: id ?? this.id,
      utilisateurId: utilisateurId ?? this.utilisateurId,
      nom: nom ?? this.nom,
      valeurMarche: valeurMarche ?? this.valeurMarche,
      coutBase: coutBase ?? this.coutBase,
      couleur: couleur ?? this.couleur,
      symbole: symbole ?? this.symbole,
      nombreActions: nombreActions ?? this.nombreActions,
      prixMoyenAchat: prixMoyenAchat ?? this.prixMoyenAchat,
      prixActuel: prixActuel ?? this.prixActuel,
      variationPourcentage: variationPourcentage ?? this.variationPourcentage,
      dateDerniereMaj: dateDerniereMaj ?? this.dateDerniereMaj,
      transactionsDetails: transactionsDetails ?? this.transactionsDetails,
      ordre: ordre ?? this.ordre,
      archive: archive ?? this.archive,
      created: created ?? this.created,
      updated: updated ?? this.updated,
    );
  }

  @override
  String toString() {
    return 'CompteInvestissement{id: $id, nom: $nom, symbole: $symbole, valeurMarche: $valeurMarche, gainPerte: ${gainPerte.toStringAsFixed(2)}, rendement: ${rendementPourcentage.toStringAsFixed(2)}%}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CompteInvestissement && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // Getters utiles pour la logique métier
  bool get estActif => !archive;
  double get gainPerte => valeurMarche - coutBase;
  double get rendementPourcentage => coutBase > 0 ? (gainPerte / coutBase) * 100 : 0;
  bool get estEnGain => gainPerte > 0;
  bool get estEnPerte => gainPerte < 0;
  bool get estStable => gainPerte.abs() < (coutBase * 0.01); // Moins de 1% de variation
  
  // Valeur par action
  double get valeurParAction => nombreActions > 0 ? valeurMarche / nombreActions : 0;
  
  // Performance depuis l'achat
  double get performanceDepuisAchat => prixMoyenAchat > 0 ? ((prixActuel - prixMoyenAchat) / prixMoyenAchat) * 100 : 0;
  
  // Indicateurs de fraîcheur des données
  bool get donneesRecentes => DateTime.now().difference(dateDerniereMaj).inHours < 24;
  bool get donneesObsoletes => DateTime.now().difference(dateDerniereMaj).inDays > 7;
  
  // Getters de compatibilité pour l'ancien code
  String get userId => utilisateurId;
  String get type => 'Investissement';
  bool get estArchive => archive;
  DateTime get dateCreation => created;
  double get solde => valeurMarche; // Positif car c'est un actif
}
