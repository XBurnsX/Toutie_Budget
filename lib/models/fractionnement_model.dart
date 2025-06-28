class SousItemFractionnement {
  final String id;
  final String description;
  final double montant;
  final String enveloppeId;
  final String? transactionParenteId;

  SousItemFractionnement({
    required this.id,
    required this.description,
    required this.montant,
    required this.enveloppeId,
    this.transactionParenteId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'montant': montant,
    'enveloppeId': enveloppeId,
    'transactionParenteId': transactionParenteId,
  };

  factory SousItemFractionnement.fromJson(Map<String, dynamic> json) {
    return SousItemFractionnement(
      id: json['id'],
      description: json['description'],
      montant: (json['montant'] as num).toDouble(),
      enveloppeId: json['enveloppeId'],
      transactionParenteId: json['transactionParenteId'],
    );
  }

  SousItemFractionnement copyWith({
    String? id,
    String? description,
    double? montant,
    String? enveloppeId,
    String? transactionParenteId,
  }) {
    return SousItemFractionnement(
      id: id ?? this.id,
      description: description ?? this.description,
      montant: montant ?? this.montant,
      enveloppeId: enveloppeId ?? this.enveloppeId,
      transactionParenteId: transactionParenteId ?? this.transactionParenteId,
    );
  }
}

class TransactionFractionnee {
  final String transactionParenteId;
  final List<SousItemFractionnement> sousItems;
  final double montantTotal;

  TransactionFractionnee({
    required this.transactionParenteId,
    required this.sousItems,
    required this.montantTotal,
  });

  double get montantAlloue => sousItems.fold(0.0, (sum, item) => sum + item.montant);
  double get montantRestant => montantTotal - montantAlloue;
  bool get estValide => montantRestant == 0.0;

  Map<String, dynamic> toJson() => {
    'transactionParenteId': transactionParenteId,
    'sousItems': sousItems.map((item) => item.toJson()).toList(),
    'montantTotal': montantTotal,
  };

  factory TransactionFractionnee.fromJson(Map<String, dynamic> json) {
    return TransactionFractionnee(
      transactionParenteId: json['transactionParenteId'],
      sousItems: (json['sousItems'] as List)
          .map((item) => SousItemFractionnement.fromJson(item))
          .toList(),
      montantTotal: (json['montantTotal'] as num).toDouble(),
    );
  }
}
