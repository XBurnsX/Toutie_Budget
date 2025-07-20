# Guide de Configuration des Collections PocketBase

## 🎯 Objectif
Configurer les collections PocketBase selon la structure réelle de votre application.

## 📋 Collections à Créer

### 1. Collection `users` (déjà créée par défaut)
- **Type** : Auth collection
- **Champs** : email, password, name (par défaut)

### 2. Collection `comptes_cheques`
- **Type** : Base collection
- **Champs** :
  - `utilisateur_id` (relation users)
  - `nom` (text)
  - `solde` (number)
  - `pret_a_placer` (number)
  - `couleur` (text)
  - `ordre` (number)
  - `archive` (bool)

### 3. Collection `comptes_credits`
- **Type** : Base collection
- **Champs** :
  - `utilisateur_id` (relation users)
  - `nom` (text)
  - `limite_credit` (number)
  - `solde_utilise` (number)
  - `taux_interet` (number)
  - `couleur` (text)
  - `ordre` (number)
  - `archive` (bool)

### 4. Collection `comptes_dettes`
- **Type** : Base collection
- **Champs** :
  - `utilisateur_id` (relation users)
  - `nom` (text)
  - `solde_dette` (number)
  - `taux_interet` (number)
  - `montant_initial` (number)
  - `paiement_minimum` (number)
  - `ordre` (number)
  - `archive` (bool)

### 5. Collection `comptes_investissement`
- **Type** : Base collection
- **Champs** :
  - `utilisateur_id` (relation users)
  - `nom` (text)
  - `valeur_marche` (number)
  - `cout_base` (number)
  - `couleur` (text)
  - `ordre` (number)
  - `archive` (bool)

### 6. Collection `categories`
- **Type** : Base collection
- **Champs** :
  - `utilisateur_id` (relation users)
  - `nom` (text)
  - `ordre` (number)

### 7. Collection `enveloppes`
- **Type** : Base collection
- **Champs** :
  - `utilisateur_id` (relation users)
  - `categorie_id` (relation categories)
  - `nom` (text)
  - `objectif_date` (date)
  - `frequence_objectif` (select: Aucun, Mensuel, Bihebdomadaire)
  - `compte_provenance_id` (text)
  - `ordre` (number)
  - `solde_enveloppe` (number)
  - `depense` (number)
  - `est_archive` (bool)
  - `objectif_montant` (number)
  - `moisObjectif` (date)

### 8. Collection `transactions`
- **Type** : Base collection
- **Champs** :
  - `utilisateur_id` (relation users)
  - `type` (select: Depense, Revenu, Pret, Emprunt)
  - `montant` (number)
  - `date` (date)
  - `note` (text)
  - `compte_id` (text)
  - `collection_compte` (text)
  - `allocation_mensuelle_id` (relation allocations_mensuelles)
  - `tiers_id` (relation tiers)

### 9. Collection `allocations_mensuelles`
- **Type** : Base collection
- **Champs** :
  - `utilisateur_id` (relation users)
  - `enveloppe_id` (relation enveloppes)
  - `mois` (date)
  - `solde` (number)
  - `alloue` (number)
  - `depense` (number)
  - `compte_source_id` (text)
  - `collection_compte_source` (text)

### 10. Collection `tiers`
- **Type** : Base collection
- **Champs** :
  - `utilisateur_id` (relation users)
  - `nom` (text)

## 🔧 Étapes de Configuration

### 1. Démarrer PocketBase
```powershell
# Dans le répertoire du projet
.\scripts\start_pocketbase.ps1
```

### 2. Accéder à l'interface admin
- Ouvrir http://127.0.0.1:8090/_/
- Créer un compte admin

### 3. Créer les collections
- Aller dans "Collections" dans l'interface admin
- Créer chaque collection avec les champs spécifiés ci-dessus

### 4. Configurer les règles d'accès
Pour chaque collection, configurer :
- **List rule** : `@request.auth.id != "" && utilisateur_id = @request.auth.id`
- **View rule** : `@request.auth.id != "" && utilisateur_id = @request.auth.id`
- **Create rule** : `@request.auth.id != "" && utilisateur_id = @request.auth.id`
- **Update rule** : `@request.auth.id != "" && utilisateur_id = @request.auth.id`
- **Delete rule** : `@request.auth.id != "" && utilisateur_id = @request.auth.id`

### 5. Tester la configuration
- Utiliser la page de test dans l'application
- Vérifier que les données peuvent être créées et récupérées

## ⚠️ Points d'Attention

1. **Relations** : Assurez-vous que les relations sont correctement configurées
2. **Types de données** : Vérifiez que les types correspondent à ceux utilisés dans l'application
3. **Règles d'accès** : Les règles doivent permettre l'accès uniquement aux données de l'utilisateur connecté
4. **Index** : Ajouter des index sur les champs fréquemment utilisés pour les requêtes

## 🚀 Prochaines Étapes

1. **Créer les collections** selon ce guide
2. **Tester la configuration** avec l'application
3. **Migrer les données existantes** de Firebase vers PocketBase
4. **Adapter les pages** pour utiliser PocketBase

---

*Guide créé le ${DateTime.now().toString().substring(0, 10)}* 

## Collection: comptes_dettes

Cette collection gère les dettes qui apparaissent dans la page comptes.

### Types de dettes dans cette collection:

1. **Dettes manuelles** → Page paramètres dettes
2. **Dettes contractées** (`type: 'dette'`) → Page comptes

### Champs requis:

| Nom du champ | Type | Description | Requis |
|--------------|------|-------------|--------|
| `nom_tiers` | Text | Nom du tiers (personne/entité) | ✅ |
| `montant_initial` | Number | Montant initial du prêt/dette | ✅ |
| `solde` | Number | Solde actuel restant | ✅ |
| `type` | Select | Type: 'dette' | ✅ |
| `archive` | Bool | Si la dette est archivée | ✅ |
| `date_creation` | Date | Date de création | ✅ |
| `utilisateur_id` | Relation | Référence vers users | ✅ |

### Champs optionnels:

| Nom du champ | Type | Description | Requis |
|--------------|------|-------------|--------|
| `note` | Text | Note optionnelle | ❌ |
| `historique` | Json | Liste des mouvements | ❌ |

### Note:
- **Couleur** : Les dettes sont automatiquement affichées en rouge
- **Pas de champ couleur** nécessaire
- **Pas de champ `est_manuel`** : Cette collection est pour toutes les dettes

### Règles d'accès:

```javascript
// Lecture: Utilisateur connecté peut lire ses propres dettes
@request.auth.id != "" && utilisateur_id = @request.auth.id

// Création: Utilisateur connecté peut créer ses propres dettes
@request.auth.id != "" && utilisateur_id = @request.auth.id

// Modification: Utilisateur connecté peut modifier ses propres dettes
@request.auth.id != "" && utilisateur_id = @request.auth.id

// Suppression: Utilisateur connecté peut supprimer ses propres dettes
@request.auth.id != "" && utilisateur_id = @request.auth.id
```

### Index recommandés:

- `utilisateur_id` (pour les requêtes par utilisateur)
- `archive` (pour filtrer actives/archivées)
- `type` (pour filtrer dettes)
- `nom_tiers` (pour rechercher par tiers)

## Collection `pret_personnel`

**Description :** Prêts accordés à d'autres personnes (n'apparaissent PAS dans les comptes)

### Champs :
- `nom_tiers` (text, required) - Nom de la personne qui a emprunté
- `montant_initial` (number, required) - Montant initial du prêt
- `solde` (number, required) - Solde restant à rembourser
- `type` (text, required) - Type de prêt (ex: "pret")
- `archive` (bool, default: false) - Si le prêt est archivé
- `date_creation` (date, required) - Date de création du prêt
- `utilisateur_id` (relation, required) - Référence vers l'utilisateur
- `note` (text, optional) - Notes sur le prêt
- `historique` (json, optional) - Historique des paiements

### Règles d'accès :
- **Liste :** `@request.auth.id != ""` (utilisateur connecté)
- **Voir :** `@request.auth.id = utilisateur_id` (propriétaire)
- **Créer :** `@request.auth.id != ""` (utilisateur connecté)
- **Modifier :** `@request.auth.id = utilisateur_id` (propriétaire)
- **Supprimer :** `@request.auth.id = utilisateur_id` (propriétaire)

### Notes :
- Cette collection est pour les prêts accordés à d'autres personnes
- Ne pas confondre avec les dettes contractées (dans `comptes_dettes`)
- Les prêts accordés n'apparaissent PAS dans la liste des comptes