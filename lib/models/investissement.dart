class ActionInvestissement {
  final String id;
  final String symbole;
  final String nom;
  final int quantite;
  final double prixAchat;
  final DateTime dateAchat;
  final String compteId;
  final String userId;

  ActionInvestissement({
    required this.id,
    required this.symbole,
    required this.nom,
    required this.quantite,
    required this.prixAchat,
    required this.dateAchat,
    required this.compteId,
    required this.userId,
  });

  factory ActionInvestissement.fromMap(Map<String, dynamic> map) {
    return ActionInvestissement(
      id: map['id'] ?? '',
      symbole: map['symbole'] ?? '',
      nom: map['nom'] ?? '',
      quantite: map['quantite'] ?? 0,
      prixAchat: (map['prixAchat'] ?? 0).toDouble(),
      dateAchat: DateTime.parse(map['dateAchat'] ?? DateTime.now().toIso8601String()),
      compteId: map['compteId'] ?? '',
      userId: map['userId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'symbole': symbole,
      'nom': nom,
      'quantite': quantite,
      'prixAchat': prixAchat,
      'dateAchat': dateAchat.toIso8601String(),
      'compteId': compteId,
      'userId': userId,
    };
  }
}
