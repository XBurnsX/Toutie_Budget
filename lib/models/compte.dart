// Modèle de données pour un compte bancaire, carte de crédit, dette ou investissement
class Compte {
  final String id;
  final String? userId; // Rendu optionnel
  final String nom;
  final String type;
  final double solde;
  final int couleur; // Stocké en int (Color.value)
  final double pretAPlacer;
  final DateTime dateCreation;
  final bool estArchive;
  final DateTime? dateSuppression; // Date d'archivage/suppression
  final int? ordre;

  Compte({
    required this.id,
    this.userId, // Rendu optionnel
    required this.nom,
    required this.type,
    required this.solde,
    required this.couleur,
    required this.pretAPlacer,
    required this.dateCreation,
    required this.estArchive,
    this.dateSuppression,
    this.ordre,
  });

  Map<String, dynamic> toMap() {
    return {
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
  }

  factory Compte.fromMap(Map<String, dynamic> map, String id) {
    return Compte(
      id: id,
      userId: map['userId'], // Lecture du champ optionnel
      nom: map['nom'] ?? '',
      type: map['type'] ?? '',
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
    );
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
