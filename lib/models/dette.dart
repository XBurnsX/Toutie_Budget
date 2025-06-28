import 'package:cloud_firestore/cloud_firestore.dart';

class MouvementDette {
  final String id;
  final DateTime date;
  final double montant;
  final String type; // 'pret', 'remboursement', 'dette', 'remboursement_effectue'
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
  final String? compteAssocie; // ID du compte associé
  final bool? compteAutoCreated; // Indique si le compte associé a été créé automatiquement

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
    this.compteAssocie,
    this.compteAutoCreated,
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
        'dateArchivage': dateArchivage != null ? Timestamp.fromDate(dateArchivage!) : null,
        'userId': userId,
        'compteAssocie': compteAssocie,
        'compteAutoCreated': compteAutoCreated,
      };

  factory Dette.fromMap(Map<String, dynamic> map) => Dette(
        id: map['id'],
        nomTiers: map['nomTiers'],
        montantInitial: (map['montantInitial'] as num).toDouble(),
        solde: (map['solde'] as num).toDouble(),
        type: map['type'],
        historique: (map['historique'] as List<dynamic>).map((h) => MouvementDette.fromMap(h)).toList(),
        archive: map['archive'] ?? false,
        dateCreation: (map['dateCreation'] as Timestamp).toDate(),
        dateArchivage: map['dateArchivage'] != null ? (map['dateArchivage'] as Timestamp).toDate() : null,
        userId: map['userId'] ?? '',
        compteAssocie: map['compteAssocie'],
        compteAutoCreated: map['compteAutoCreated'],
      );
}
