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
  - `couleur` (text)

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