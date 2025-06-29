import 'package:cloud_firestore/cloud_firestore.dart';

class MouvementDette {
  final String id;
  final DateTime date;
  final double montant;
  final String
  type; // 'pret', 'remboursement', 'dette', 'remboursement_effectue'
  final String? note;

  MouvementDette({
    required this.id,
    required this.date,
    required this.montant,
    required this.type,
    this.note,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': Timestamp.fromDate(date),
    'montant': montant,
    'type': type,
    'note': note,
  };

  factory MouvementDette.fromMap(Map<String, dynamic> map) => MouvementDette(
    id: map['id'],
    date: (map['date'] as Timestamp).toDate(),
    montant: (map['montant'] as num).toDouble(),
    type: map['type'],
    note: map['note'],
  );
}

class Dette {
  final String id;
  final String nomTiers;
  final double montantInitial;
  final double solde;
  final String type; // 'pret' ou 'dette'
  final List<MouvementDette> historique;
  final bool archive;
  final DateTime dateCreation;
  final DateTime? dateArchivage;
  final String userId;
  final bool estManuelle; // Indique si la dette a été créée manuellement

  // Nouveaux champs pour les paramètres d'intérêt
  final double? tauxInteret; // Taux d'intérêt annuel en pourcentage
  final DateTime? dateFinObjectif; // Date objectif de remboursement
  final double? montantMensuelCalcule; // Montant mensuel calculé avec intérêts

  // Champs supplémentaires pour les dettes manuelles
  final DateTime? dateFin; // Date de fin de remboursement
  final double? montantMensuel; // Montant mensuel fixe
  final double? prixAchat; // Prix d'achat initial
  final int? nombrePaiements; // Nombre total de paiements
  final DateTime? dateDebut; // Date de début du prêt
  final int? paiementsEffectues; // Nombre de paiements effectués

  Dette({
    required this.id,
    required this.nomTiers,
    required this.montantInitial,
    required this.solde,
    required this.type,
    required this.historique,
    required this.archive,
    required this.dateCreation,
    this.dateArchivage,
    required this.userId,
    this.estManuelle = false, // Par défaut false (créée automatiquement)
    this.tauxInteret,
    this.dateFinObjectif,
    this.montantMensuelCalcule,
    this.dateFin,
    this.montantMensuel,
    this.prixAchat,
    this.nombrePaiements,
    this.dateDebut,
    this.paiementsEffectues,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'nomTiers': nomTiers,
    'montantInitial': montantInitial,
    'solde': solde,
    'type': type,
    'historique': historique.map((m) => m.toMap()).toList(),
    'archive': archive,
    'dateCreation': Timestamp.fromDate(dateCreation),
    'dateArchivage': dateArchivage != null
        ? Timestamp.fromDate(dateArchivage!)
        : null,
    'userId': userId,
    'estManuelle': estManuelle,
    'tauxInteret': tauxInteret,
    'dateFinObjectif': dateFinObjectif != null
        ? Timestamp.fromDate(dateFinObjectif!)
        : null,
    'montantMensuelCalcule': montantMensuelCalcule,
    'dateFin': dateFin != null ? Timestamp.fromDate(dateFin!) : null,
    'montantMensuel': montantMensuel,
    'prixAchat': prixAchat,
    'nombrePaiements': nombrePaiements,
    'dateDebut': dateDebut != null ? Timestamp.fromDate(dateDebut!) : null,
    'paiementsEffectues': paiementsEffectues,
  };

  factory Dette.fromMap(Map<String, dynamic> map) => Dette(
    id: map['id'],
    nomTiers: map['nomTiers'],
    montantInitial: (map['montantInitial'] as num).toDouble(),
    solde: (map['solde'] as num).toDouble(),
    type: map['type'],
    historique: (map['historique'] as List<dynamic>)
        .map((h) => MouvementDette.fromMap(h))
        .toList(),
    archive: map['archive'] ?? false,
    dateCreation: (map['dateCreation'] as Timestamp).toDate(),
    dateArchivage: map['dateArchivage'] != null
        ? (map['dateArchivage'] as Timestamp).toDate()
        : null,
    userId: map['userId'] ?? '',
    estManuelle: map['estManuelle'] ?? false,
    tauxInteret: map['tauxInteret'] != null
        ? (map['tauxInteret'] as num).toDouble()
        : null,
    dateFinObjectif: map['dateFinObjectif'] != null
        ? (map['dateFinObjectif'] as Timestamp).toDate()
        : null,
    montantMensuelCalcule: map['montantMensuelCalcule'] != null
        ? (map['montantMensuelCalcule'] as num).toDouble()
        : null,
    dateFin: map['dateFin'] != null
        ? (map['dateFin'] as Timestamp).toDate()
        : null,
    montantMensuel: map['montantMensuel'] != null
        ? (map['montantMensuel'] as num).toDouble()
        : null,
    prixAchat: map['prixAchat'] != null
        ? (map['prixAchat'] as num).toDouble()
        : null,
    nombrePaiements: map['nombrePaiements'] != null
        ? (map['nombrePaiements'] as num).toInt()
        : null,
    dateDebut: map['dateDebut'] != null
        ? (map['dateDebut'] as Timestamp).toDate()
        : null,
    paiementsEffectues: map['paiementsEffectues'] != null
        ? (map['paiementsEffectues'] as num).toInt()
        : null,
  );

  Dette copyWith({
    String? id,
    String? nomTiers,
    double? montantInitial,
    double? solde,
    String? type,
    List<MouvementDette>? historique,
    bool? archive,
    DateTime? dateCreation,
    DateTime? dateArchivage,
    String? userId,
    bool? estManuelle,
    double? tauxInteret,
    DateTime? dateFinObjectif,
    double? montantMensuelCalcule,
    DateTime? dateFin,
    double? montantMensuel,
    double? prixAchat,
    int? nombrePaiements,
    DateTime? dateDebut,
    int? paiementsEffectues,
  }) {
    return Dette(
      id: id ?? this.id,
      nomTiers: nomTiers ?? this.nomTiers,
      montantInitial: montantInitial ?? this.montantInitial,
      solde: solde ?? this.solde,
      type: type ?? this.type,
      historique: historique ?? this.historique,
      archive: archive ?? this.archive,
      dateCreation: dateCreation ?? this.dateCreation,
      dateArchivage: dateArchivage ?? this.dateArchivage,
      userId: userId ?? this.userId,
      estManuelle: estManuelle ?? this.estManuelle,
      tauxInteret: tauxInteret ?? this.tauxInteret,
      dateFinObjectif: dateFinObjectif ?? this.dateFinObjectif,
      montantMensuelCalcule:
          montantMensuelCalcule ?? this.montantMensuelCalcule,
      dateFin: dateFin ?? this.dateFin,
      montantMensuel: montantMensuel ?? this.montantMensuel,
      prixAchat: prixAchat ?? this.prixAchat,
      nombrePaiements: nombrePaiements ?? this.nombrePaiements,
      dateDebut: dateDebut ?? this.dateDebut,
      paiementsEffectues: paiementsEffectues ?? this.paiementsEffectues,
    );
  }
}
