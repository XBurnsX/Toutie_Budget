// 📁 Chemin : lib/models/compte.dart
// 🔗 Dépendances : aucune
// 📋 Description : Modèle de données pour un compte - Support 4 types PocketBase

// Modèle de données pour un compte bancaire, carte de crédit, dette ou investissement
class Compte {
  final String id;
  final String? userId; // Rendu optionnel
  final String nom;
  final String type; // "Chèque", "Carte de crédit", "Dette", "Investissement"
  final double solde;
  final int couleur; // Stocké en int (Color.value)
  final double pretAPlacer; // Seulement pour type "Chèque"
  final DateTime dateCreation;
  final bool estArchive;
  final DateTime? dateSuppression; // Date d'archivage/suppression
  final int? ordre;

  // Champs spécifiques aux cartes de crédit
  final double? limiteCredit;
  final double? tauxInteret;

  // Champs spécifiques aux dettes
  final String? nomTiers;
  final double? montantInitial;
  final double? paiementMinimum;

  // Champs spécifiques aux investissements
  final double? valeurMarche;
  final double? coutBase;

  Compte({
    required this.id,
    this.userId, // Rendu optionnel
    required this.nom,
    required this.type,
    required this.solde,
    required this.couleur,
    required this.pretAPlacer, // 0.0 pour les types autres que "Chèque"
    required this.dateCreation,
    required this.estArchive,
    this.dateSuppression,
    this.ordre,
    // Champs optionnels spécifiques
    this.limiteCredit,
    this.tauxInteret,
    this.nomTiers,
    this.montantInitial,
    this.paiementMinimum,
    this.valeurMarche,
    this.coutBase,
  });

  // Factory constructors pour chaque type de compte
  factory Compte.cheque({
    required String id,
    String? userId,
    required String nom,
    required double solde,
    required int couleur,
    required double pretAPlacer,
    required DateTime dateCreation,
    required bool estArchive,
    DateTime? dateSuppression,
    int? ordre,
  }) {
    return Compte(
      id: id,
      userId: userId,
      nom: nom,
      type: 'Chèque',
      solde: solde,
      couleur: couleur,
      pretAPlacer: pretAPlacer,
      dateCreation: dateCreation,
      estArchive: estArchive,
      dateSuppression: dateSuppression,
      ordre: ordre,
    );
  }

  factory Compte.carteCredit({
    required String id,
    String? userId,
    required String nom,
    required double soldeUtilise, // Montant utilisé (positif)
    required int couleur,
    required DateTime dateCreation,
    required bool estArchive,
    DateTime? dateSuppression,
    int? ordre,
    double? limiteCredit,
    double? tauxInteret,
  }) {
    return Compte(
      id: id,
      userId: userId,
      nom: nom,
      type: 'Carte de crédit',
      solde: -soldeUtilise, // Négatif car c'est une dette
      couleur: couleur,
      pretAPlacer: 0.0, // Pas applicable aux cartes de crédit
      dateCreation: dateCreation,
      estArchive: estArchive,
      dateSuppression: dateSuppression,
      ordre: ordre,
      limiteCredit: limiteCredit,
      tauxInteret: tauxInteret,
    );
  }

  factory Compte.dette({
    required String id,
    String? userId,
    required String nom,
    required double soldeDette, // Montant de la dette (positif)
    required DateTime dateCreation,
    required bool estArchive,
    DateTime? dateSuppression,
    int? ordre,
    String? nomTiers,
    double? montantInitial,
    double? tauxInteret,
    double? paiementMinimum,
  }) {
    return Compte(
      id: id,
      userId: userId,
      nom: nom,
      type: 'Dette',
      solde: -soldeDette, // Négatif car c'est une dette
      couleur: 0xFFD32F2F, // Rouge pour les dettes
      pretAPlacer: 0.0, // Pas applicable aux dettes
      dateCreation: dateCreation,
      estArchive: estArchive,
      dateSuppression: dateSuppression,
      ordre: ordre,
      nomTiers: nomTiers,
      montantInitial: montantInitial,
      tauxInteret: tauxInteret,
      paiementMinimum: paiementMinimum,
    );
  }

  factory Compte.investissement({
    required String id,
    String? userId,
    required String nom,
    required double valeurMarche,
    required int couleur,
    required DateTime dateCreation,
    required bool estArchive,
    DateTime? dateSuppression,
    int? ordre,
    double? coutBase,
  }) {
    return Compte(
      id: id,
      userId: userId,
      nom: nom,
      type: 'Investissement',
      solde: valeurMarche,
      couleur: couleur,
      pretAPlacer: 0.0, // Pas applicable aux investissements
      dateCreation: dateCreation,
      estArchive: estArchive,
      dateSuppression: dateSuppression,
      ordre: ordre,
      valeurMarche: valeurMarche,
      coutBase: coutBase,
    );
  }

  // Getters utiles pour le business logic
  bool get estComptePositif => type == 'Chèque' || type == 'Investissement';
  bool get estDette => type == 'Carte de crédit' || type == 'Dette';
  bool get peutAvoirPretAPlacer => type == 'Chèque';
  
  double get soldeAbsolu => solde.abs();
  
  // Pour les cartes de crédit : montant disponible
  double get creditDisponible {
    if (type != 'Carte de crédit' || limiteCredit == null) return 0.0;
    return limiteCredit! - soldeAbsolu;
  }

  Map<String, dynamic> toMap() {
    final map = {
      'userId': userId,
      'nom': nom,
      'type': type,
      'solde': solde,
      'couleur': couleur,
      'pretAPlacer': pretAPlacer,
      'dateCreation': dateCreation.toIso8601String(),
      'estArchive': estArchive,
      'dateSuppression': dateSuppression?.toIso8601String(),
      'ordre': ordre,
    };

    // Ajouter les champs spécifiques selon le type
    if (type == 'Carte de crédit') {
      if (limiteCredit != null) map['limiteCredit'] = limiteCredit;
      if (tauxInteret != null) map['tauxInteret'] = tauxInteret;
    } else if (type == 'Dette') {
      if (nomTiers != null) map['nomTiers'] = nomTiers;
      if (montantInitial != null) map['montantInitial'] = montantInitial;
      if (tauxInteret != null) map['tauxInteret'] = tauxInteret;
      if (paiementMinimum != null) map['paiementMinimum'] = paiementMinimum;
    } else if (type == 'Investissement') {
      if (valeurMarche != null) map['valeurMarche'] = valeurMarche;
      if (coutBase != null) map['coutBase'] = coutBase;
    }

    return map;
  }

  factory Compte.fromMap(Map<String, dynamic> map, String id) {
    final type = map['type'] ?? 'Chèque';
    
    return Compte(
      id: id,
      userId: map['userId'],
      nom: map['nom'] ?? '',
      type: type,
      solde: (map['solde'] ?? 0).toDouble(),
      couleur: map['couleur'] ?? 0xFF2196F3,
      pretAPlacer: (map['pretAPlacer'] ?? 0).toDouble(),
      dateCreation: map['dateCreation'] != null
          ? DateTime.parse(map['dateCreation'])
          : DateTime.now(),
      estArchive: map['estArchive'] ?? false,
      dateSuppression: map['dateSuppression'] != null
          ? DateTime.parse(map['dateSuppression'])
          : null,
      ordre: map['ordre'],
      // Champs spécifiques
      limiteCredit: map['limiteCredit']?.toDouble(),
      tauxInteret: map['tauxInteret']?.toDouble(),
      nomTiers: map['nomTiers'],
      montantInitial: map['montantInitial']?.toDouble(),
      paiementMinimum: map['paiementMinimum']?.toDouble(),
      valeurMarche: map['valeurMarche']?.toDouble(),
      coutBase: map['coutBase']?.toDouble(),
    );
  }

  // Factory pour créer depuis les données PocketBase selon la collection
  factory Compte.fromPocketBase(Map<String, dynamic> data, String id, String typeCompte) {
    switch (typeCompte) {
      case 'Chèque':
        return Compte.cheque(
          id: id,
          userId: data['utilisateur_id'],
          nom: data['nom'] ?? '',
          solde: (data['solde'] ?? 0).toDouble(),
          couleur: _parseColor(data['couleur']),
          pretAPlacer: (data['pret_a_placer'] ?? 0).toDouble(),
          dateCreation: DateTime.now(),
          estArchive: data['archive'] ?? false,
          ordre: data['ordre'],
        );
        
      case 'Carte de crédit':
        return Compte.carteCredit(
          id: id,
          userId: data['utilisateur_id'],
          nom: data['nom'] ?? '',
          soldeUtilise: (data['solde_utilise'] ?? 0).toDouble(),
          couleur: _parseColor(data['couleur']),
          dateCreation: DateTime.now(),
          estArchive: data['archive'] ?? false,
          ordre: data['ordre'],
          limiteCredit: (data['limite_credit'] ?? 0).toDouble(),
          tauxInteret: (data['taux_interet'] ?? 0).toDouble(),
        );
        
      case 'Dette':
        return Compte.dette(
          id: id,
          userId: data['utilisateur_id'],
          nom: data['nom'] ?? '',
          soldeDette: (data['solde_dette'] ?? 0).toDouble(),
          dateCreation: DateTime.now(),
          estArchive: data['archive'] ?? false,
          ordre: data['ordre'],
          nomTiers: data['nom_tiers'],
          montantInitial: (data['montant_initial'] ?? 0).toDouble(),
          tauxInteret: (data['taux_interet'] ?? 0).toDouble(),
          paiementMinimum: (data['paiement_minimum'] ?? 0).toDouble(),
        );
        
      case 'Investissement':
        return Compte.investissement(
          id: id,
          userId: data['utilisateur_id'],
          nom: data['nom'] ?? '',
          valeurMarche: (data['valeur_marche'] ?? 0).toDouble(),
          couleur: _parseColor(data['couleur']),
          dateCreation: DateTime.now(),
          estArchive: data['archive'] ?? false,
          ordre: data['ordre'],
          coutBase: (data['cout_base'] ?? 0).toDouble(),
        );
        
      default:
        throw Exception('Type de compte non reconnu: $typeCompte');
    }
  }

  // Helper pour parser les couleurs
  static int _parseColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) {
      return 0xFF2196F3; // Bleu par défaut
    }
    
    try {
      String hex = colorString.replaceAll('#', '');
      if (hex.length == 6) {
        return int.parse('FF$hex', radix: 16);
      }
      return 0xFF2196F3;
    } catch (e) {
      return 0xFF2196F3;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Compte &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          nom == other.nom &&
          type == other.type &&
          solde == other.solde &&
          couleur == other.couleur &&
          pretAPlacer == other.pretAPlacer &&
          dateCreation == other.dateCreation &&
          estArchive == other.estArchive &&
          (dateSuppression?.hashCode ?? 0) ==
              (other.dateSuppression?.hashCode ?? 0) &&
          ordre == other.ordre;

  @override
  int get hashCode =>
      id.hashCode ^
      (userId?.hashCode ?? 0) ^
      nom.hashCode ^
      type.hashCode ^
      solde.hashCode ^
      couleur.hashCode ^
      pretAPlacer.hashCode ^
      dateCreation.hashCode ^
      estArchive.hashCode ^
      (dateSuppression?.hashCode ?? 0) ^
      (ordre?.hashCode ?? 0);
}