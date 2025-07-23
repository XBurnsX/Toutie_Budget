enum TypeTransaction {
  depense,
  revenu,
  pret,
  emprunt,
}

extension TypeTransactionExtension on TypeTransaction {
  String get nom {
    switch (this) {
      case TypeTransaction.depense:
        return 'Depense';
      case TypeTransaction.revenu:
        return 'Revenu';
      case TypeTransaction.pret:
        return 'Pret';
      case TypeTransaction.emprunt:
        return 'Emprunt';
    }
  }
  
  bool get estDepense => this == TypeTransaction.depense;
  bool get estRevenu => this == TypeTransaction.revenu;
  bool get estPret => this == TypeTransaction.pret;
  bool get estEmprunt => this == TypeTransaction.emprunt;
  bool get estSortieArgent => estDepense || estPret;
  bool get estEntreeArgent => estRevenu || estEmprunt;
}

class SousItem {
  final String nom;
  final double montant;
  final String? note;

  SousItem({
    required this.nom,
    required this.montant,
    this.note,
  });

  factory SousItem.fromMap(Map<String, dynamic> map) {
    return SousItem(
      nom: map['nom'] ?? '',
      montant: (map['montant'] ?? 0).toDouble(),
      note: map['note'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nom': nom,
      'montant': montant,
      'note': note,
    };
  }
}

class Transaction {
  final String id;
  final String utilisateurId;
  final TypeTransaction type;
  final double montant;
  final DateTime date;
  final String? note;
  final String compteId;
  final String collectionCompte;
  final String? allocationMensuelleId;
  final String? tiersId;
  final bool estFractionnee;
  final String? transactionParenteId;
  final List<SousItem> sousItems;
  final String? marqueur;
  final String? comptePassifId;
  final DateTime created;
  final DateTime updated;

  Transaction({
    required this.id,
    required this.utilisateurId,
    required this.type,
    required this.montant,
    required this.date,
    this.note,
    required this.compteId,
    required this.collectionCompte,
    this.allocationMensuelleId,
    this.tiersId,
    required this.estFractionnee,
    this.transactionParenteId,
    required this.sousItems,
    this.marqueur,
    this.comptePassifId,
    required this.created,
    required this.updated,
  });

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] ?? '',
      utilisateurId: map['utilisateur_id'] ?? '',
      type: _parseType(map['type']),
      montant: (map['montant'] ?? 0).toDouble(),
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      note: map['note'],
      compteId: map['compte_id'] ?? '',
      collectionCompte: map['collection_compte'] ?? '',
      allocationMensuelleId: map['allocation_mensuelle_id'],
      tiersId: map['tiers_id'],
      estFractionnee: map['est_fractionnee'] ?? false,
      transactionParenteId: map['transaction_parente_id'],
      sousItems: _parseSousItems(map['sous_items']),
      marqueur: map['marqueur'],
      comptePassifId: map['compte_passif_id'],
      created: map['created'] != null ? DateTime.parse(map['created']) : DateTime.now(),
      updated: map['updated'] != null ? DateTime.parse(map['updated']) : DateTime.now(),
    );
  }

  static TypeTransaction _parseType(dynamic value) {
    if (value == null) return TypeTransaction.depense;
    switch (value.toString()) {
      case 'Depense':
        return TypeTransaction.depense;
      case 'Revenu':
        return TypeTransaction.revenu;
      case 'Pret':
        return TypeTransaction.pret;
      case 'Emprunt':
        return TypeTransaction.emprunt;
      default:
        return TypeTransaction.depense;
    }
  }

  static List<SousItem> _parseSousItems(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((item) => SousItem.fromMap(item)).toList();
    }
    return [];
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'utilisateur_id': utilisateurId,
      'type': type.nom,
      'montant': montant,
      'date': date.toIso8601String().split('T')[0], // Format date seulement
      'note': note,
      'compte_id': compteId,
      'collection_compte': collectionCompte,
      'allocation_mensuelle_id': allocationMensuelleId,
      'tiers_id': tiersId,
      'est_fractionnee': estFractionnee,
      'transaction_parente_id': transactionParenteId,
      'sous_items': sousItems.map((item) => item.toMap()).toList(),
      'marqueur': marqueur,
      'compte_passif_id': comptePassifId,
      'created': created.toIso8601String(),
      'updated': updated.toIso8601String(),
    };
  }

  Transaction copyWith({
    String? id,
    String? utilisateurId,
    TypeTransaction? type,
    double? montant,
    DateTime? date,
    String? note,
    String? compteId,
    String? collectionCompte,
    String? allocationMensuelleId,
    String? tiersId,
    bool? estFractionnee,
    String? transactionParenteId,
    List<SousItem>? sousItems,
    String? marqueur,
    String? comptePassifId,
    DateTime? created,
    DateTime? updated,
  }) {
    return Transaction(
      id: id ?? this.id,
      utilisateurId: utilisateurId ?? this.utilisateurId,
      type: type ?? this.type,
      montant: montant ?? this.montant,
      date: date ?? this.date,
      note: note ?? this.note,
      compteId: compteId ?? this.compteId,
      collectionCompte: collectionCompte ?? this.collectionCompte,
      allocationMensuelleId: allocationMensuelleId ?? this.allocationMensuelleId,
      tiersId: tiersId ?? this.tiersId,
      estFractionnee: estFractionnee ?? this.estFractionnee,
      transactionParenteId: transactionParenteId ?? this.transactionParenteId,
      sousItems: sousItems ?? this.sousItems,
      marqueur: marqueur ?? this.marqueur,
      comptePassifId: comptePassifId ?? this.comptePassifId,
      created: created ?? this.created,
      updated: updated ?? this.updated,
    );
  }

  @override
  String toString() {
    return 'Transaction{id: $id, type: ${type.nom}, montant: $montant, date: $date, note: $note}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Transaction && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // Getters utiles pour la logique métier
  bool get aDesNotes => note != null && note!.trim().isNotEmpty;
  bool get aDesSousItems => sousItems.isNotEmpty;
  bool get aUnTiers => tiersId != null && tiersId!.isNotEmpty;
  bool get aUnMarqueur => marqueur != null && marqueur!.isNotEmpty;
  bool get estTransfert => comptePassifId != null && comptePassifId!.isNotEmpty;
  bool get estTransactionParente => estFractionnee && transactionParenteId == null;
  bool get estSousTransaction => transactionParenteId != null && transactionParenteId!.isNotEmpty;
  
  // Montant avec signe selon le type
  double get montantAvecSigne {
    return type.estSortieArgent ? -montant : montant;
  }
  
  // Description pour affichage
  String get description => note ?? 'Transaction sans description';
  
  // Getters de compatibilité pour l'ancien code
  String get userId => utilisateurId;
  String? get enveloppeId => allocationMensuelleId;
  bool get estReconciliee => false; // À adapter selon la logique métier
  DateTime get dateCreation => created;
  DateTime? get dateModification => updated;
  
  // Ancien enum pour compatibilité
  TypeMouvementFinancier get typeMouvement {
    switch (type) {
      case TypeTransaction.depense:
        return TypeMouvementFinancier.depense;
      case TypeTransaction.revenu:
        return TypeMouvementFinancier.revenu;
      case TypeTransaction.pret:
      case TypeTransaction.emprunt:
        return TypeMouvementFinancier.transfert;
    }
  }
}

// Enum de compatibilité pour l'ancien code
enum TypeMouvementFinancier {
  depense,
  revenu,
  transfert,
  remboursement,
  assignation,
  retrait,
}
