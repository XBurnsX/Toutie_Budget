class Enveloppe {
  final String id;
  final String nom;
  final double solde;
  final double objectif;
  final String? objectifDate;
  final double? depense;
  final bool archivee;
  final String provenanceCompteId;
  final String frequenceObjectif;
  final DateTime? dateDernierAjout;
  final int? objectifJour;
  final Map<String, dynamic>? historique;

  Enveloppe({
    required this.id,
    required this.nom,
    this.solde = 0.0,
    this.objectif = 0.0,
    this.objectifDate,
    this.depense,
    this.archivee = false,
    this.provenanceCompteId = '',
    this.frequenceObjectif = 'mensuel',
    this.dateDernierAjout,
    this.objectifJour,
    this.historique,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'nom': nom,
    'solde': solde,
    'objectif': objectif,
    'objectif_date': objectifDate,
    'depense': depense,
    'archivee': archivee,
    'provenance_compte_id': provenanceCompteId,
    'frequence_objectif': frequenceObjectif,
    'date_dernier_ajout': dateDernierAjout?.toIso8601String(),
    'objectif_jour': objectifJour,
    'historique': historique,
  };

  factory Enveloppe.fromMap(Map<String, dynamic> map) => Enveloppe(
    id: map['id'] ?? '',
    nom: map['nom'] ?? '',
    solde: (map['solde'] ?? 0.0).toDouble(),
    objectif: (map['objectif'] ?? 0.0).toDouble(),
    objectifDate: map['objectif_date'],
    depense: (map['depense'] ?? 0.0).toDouble(),
    archivee: map['archivee'] ?? false,
    provenanceCompteId: map['provenance_compte_id'] ?? '',
    frequenceObjectif: map['frequence_objectif'] ?? 'mensuel',
    dateDernierAjout: map['date_dernier_ajout'] != null ? DateTime.tryParse(map['date_dernier_ajout']) : null,
    objectifJour: map['objectif_jour'],
    historique: map['historique'] != null ? Map<String, dynamic>.from(map['historique']) : null,
  );
}

class Categorie {
  final String id;
  final String? userId; // Rendu optionnel
  final String nom;
  final List<Enveloppe> enveloppes;

  Categorie({
    required this.id,
    this.userId, // Rendu optionnel
    required this.nom,
    required this.enveloppes,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'nom': nom,
    'enveloppes': enveloppes.map((e) => e.toMap()).toList(),
  };

  factory Categorie.fromMap(Map<String, dynamic> map) => Categorie(
    id: map['id'] ?? '',
    userId: map['userId'], // Lecture du champ optionnel
    nom: map['nom'] ?? '',
    enveloppes: (map['enveloppes'] as List<dynamic>? ?? [])
        .map((e) => Enveloppe.fromMap(e as Map<String, dynamic>)).toList(),
  );
}
