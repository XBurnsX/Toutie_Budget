enum TypeTransaction {
  depense,
  revenu,
}

extension TypeTransactionExtension on TypeTransaction {
  bool get estDepense => this == TypeTransaction.depense;
  bool get estRevenu => this == TypeTransaction.revenu;
}

enum TypeMouvementFinancier {
  depenseNormale,
  revenuNormal,
  pretAccorde,
  remboursementRecu,
  detteContractee,
  remboursementEffectue,
}

extension TypeMouvementFinancierExtension on TypeMouvementFinancier {
  bool get estDepense => this == TypeMouvementFinancier.depenseNormale || this == TypeMouvementFinancier.pretAccorde || this == TypeMouvementFinancier.remboursementEffectue;
  bool get estRevenu => this == TypeMouvementFinancier.revenuNormal || this == TypeMouvementFinancier.remboursementRecu || this == TypeMouvementFinancier.detteContractee;
}

class Transaction {
  final String id;
  final String? userId;
  final TypeTransaction type;
  final TypeMouvementFinancier typeMouvement;
  final double montant;
  final String? tiers;
  final String compteId;
  final String? compteDePassifAssocie;
  final DateTime date;
  final String? enveloppeId;
  final String? marqueur;
  final String? note;
  final bool estFractionnee;
  final String? transactionParenteId;
  final List<Map<String, dynamic>>? sousItems;

  Transaction({
    required this.id,
    this.userId,
    required this.type,
    required this.typeMouvement,
    required this.montant,
    required this.compteId,
    required this.date,
    this.tiers,
    this.compteDePassifAssocie,
    this.enveloppeId,
    this.marqueur,
    this.note,
    this.estFractionnee = false,
    this.transactionParenteId,
    this.sousItems,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'type': type.name,
    'typeMouvement': typeMouvement.name,
    'montant': montant,
    'tiers': tiers,
    'compteId': compteId,
    'compteDePassifAssocie': compteDePassifAssocie,
    'date': date.toIso8601String(),
    'enveloppeId': enveloppeId,
    'marqueur': marqueur,
    'note': note,
    'estFractionnee': estFractionnee,
    'transactionParenteId': transactionParenteId,
    'sousItems': sousItems,
  };

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      userId: json['userId'],
      type: TypeTransaction.values.byName(json['type']),
      typeMouvement: TypeMouvementFinancier.values.byName(json['typeMouvement']),
      montant: (json['montant'] as num).toDouble(),
      compteId: json['compteId'],
      date: DateTime.parse(json['date']),
      tiers: json['tiers'],
      compteDePassifAssocie: json['compteDePassifAssocie'],
      enveloppeId: json['enveloppeId'],
      marqueur: json['marqueur'],
      note: json['note'],
      estFractionnee: json['estFractionnee'] ?? false,
      transactionParenteId: json['transactionParenteId'],
      sousItems: json['sousItems'] != null
          ? List<Map<String, dynamic>>.from(json['sousItems'])
          : null,
    );
  }
}
