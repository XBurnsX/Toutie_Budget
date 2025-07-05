class ActionInvestissement {
  final String id;
  final String symbole;
  final int nombre;
  final double prixMoyen;
  final double prixActuel;
  final double valeurActuelle;
  final double variation; // en pourcentage
  final DateTime dateDerniereMiseAJour;
  final List<TransactionInvestissement> transactions;

  ActionInvestissement({
    required this.id,
    required this.symbole,
    required this.nombre,
    required this.prixMoyen,
    required this.prixActuel,
    required this.valeurActuelle,
    required this.variation,
    required this.dateDerniereMiseAJour,
    this.transactions = const [],
  });

  factory ActionInvestissement.fromMap(Map<String, dynamic> map) {
    return ActionInvestissement(
      id: map['id'] ?? '',
      symbole: map['symbole'] ?? '',
      nombre: map['nombre']?.toInt() ?? 0,
      prixMoyen: (map['prixMoyen'] ?? 0.0).toDouble(),
      prixActuel: (map['prixActuel'] ?? 0.0).toDouble(),
      valeurActuelle: (map['valeurActuelle'] ?? 0.0).toDouble(),
      variation: (map['variation'] ?? 0.0).toDouble(),
      dateDerniereMiseAJour: map['dateDerniereMiseAJour'] != null
          ? DateTime.parse(map['dateDerniereMiseAJour'])
          : DateTime.now(),
      transactions: (map['transactions'] as List<dynamic>?)
              ?.map((t) => TransactionInvestissement.fromMap(t))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'symbole': symbole,
      'nombre': nombre,
      'prixMoyen': prixMoyen,
      'prixActuel': prixActuel,
      'valeurActuelle': valeurActuelle,
      'variation': variation,
      'dateDerniereMiseAJour': dateDerniereMiseAJour.toIso8601String(),
      'transactions': transactions.map((t) => t.toMap()).toList(),
    };
  }

  ActionInvestissement copyWith({
    String? id,
    String? symbole,
    int? nombre,
    double? prixMoyen,
    double? prixActuel,
    double? valeurActuelle,
    double? variation,
    DateTime? dateDerniereMiseAJour,
    List<TransactionInvestissement>? transactions,
  }) {
    return ActionInvestissement(
      id: id ?? this.id,
      symbole: symbole ?? this.symbole,
      nombre: nombre ?? this.nombre,
      prixMoyen: prixMoyen ?? this.prixMoyen,
      prixActuel: prixActuel ?? this.prixActuel,
      valeurActuelle: valeurActuelle ?? this.valeurActuelle,
      variation: variation ?? this.variation,
      dateDerniereMiseAJour:
          dateDerniereMiseAJour ?? this.dateDerniereMiseAJour,
      transactions: transactions ?? this.transactions,
    );
  }
}

class TransactionInvestissement {
  final String id;
  final String type; // 'achat', 'vente', 'dividende'
  final int nombre;
  final double prix;
  final DateTime date;
  final String? notes;

  TransactionInvestissement({
    required this.id,
    required this.type,
    required this.nombre,
    required this.prix,
    required this.date,
    this.notes,
  });

  factory TransactionInvestissement.fromMap(Map<String, dynamic> map) {
    return TransactionInvestissement(
      id: map['id'] ?? '',
      type: map['type'] ?? '',
      nombre: map['nombre']?.toInt() ?? 0,
      prix: (map['prix'] ?? 0.0).toDouble(),
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'nombre': nombre,
      'prix': prix,
      'date': date.toIso8601String(),
      'notes': notes,
    };
  }
}
