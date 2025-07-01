# 📊 Guide d'Import CSV - Toutie Budget

## 🎯 **Nouveau Système Intelligent de Catégories**

Votre système d'import CSV a été amélioré ! Maintenant, il **crée automatiquement** les catégories et enveloppes manquantes au bon endroit.

## 📋 **Colonnes Supportées**

| Colonne | Obligatoire | Description | Exemple |
|---------|-------------|-------------|---------|
| **Date** | ✅ Oui | Date de la transaction | `01/12/2024` |
| **Montant** | ✅ Oui | Montant (négatif = dépense) | `-45.50` ou `2500.00` |
| **Compte** | ✅ Oui | Nom du compte existant | `Compte Courant` |
| **Type** | ⚪ Optionnel | Type de transaction | `depense` ou `revenu` |
| **Tiers** | ⚪ Optionnel | Qui/Où | `Restaurant Le Gourmet` |
| **Enveloppe** | ⚪ Optionnel | Nom de l'enveloppe | `Alimentation` |
| **Categorie** | ⚪ Optionnel | Nom de la catégorie | `Besoins essentiels` |
| **Note** | ⚪ Optionnel | Commentaire | `Déjeuner d'affaires` |
| **Marqueur** | ⚪ Optionnel | Tag personnel | `professionnel` |

## 🚀 **Fonctionnalités Intelligentes**

### ✅ **Création Automatique de Catégories**
- Si la catégorie n'existe pas → **Elle est créée automatiquement**
- L'enveloppe est placée dans la **bonne catégorie** directement
- Plus besoin de catégorie "Non classé" !

### ✅ **Détection Automatique**
- **Format de date** : `dd/MM/yyyy`, `yyyy-MM-dd`, `MM/dd/yyyy`, etc.
- **Délimiteur CSV** : `,`, `;`, ou `\t` (tabulation)
- **Type de transaction** : Déduit du montant si pas spécifié

### ✅ **Validation Intelligente**
- Vérifie que les comptes existent
- Nettoie automatiquement les montants (`€`, `$`, espaces)
- Gère les erreurs avec messages détaillés

## 📊 **Exemple d'Import**

```csv
Date,Montant,Type,Tiers,Compte,Enveloppe,Categorie,Note,Marqueur
01/12/2024,-45.50,depense,Restaurant,Compte Courant,Alimentation,Besoins essentiels,Déjeuner,professionnel
02/12/2024,2500.00,revenu,Employeur,Compte Courant,Salaire,Revenus,Salaire mensuel,
03/12/2024,-120.00,depense,Hydro-Québec,Compte Courant,Électricité,Factures,Facture décembre,
```

## 🎯 **Résultat Après Import**

Le système créera automatiquement :

📁 **Catégorie "Besoins essentiels"** 
   └── 💰 Enveloppe "Alimentation"

📁 **Catégorie "Revenus"**
   └── 💰 Enveloppe "Salaire"

📁 **Catégorie "Factures"**
   └── 💰 Enveloppe "Électricité"

## 🔧 **Comment Utiliser**

1. **Ouvrez l'app** → Budget → ⚙️ Paramètres
2. **Sélectionnez** "Importer des transactions"
3. **Choisissez votre fichier CSV**
4. **Mappez les colonnes** (détection automatique)
5. **Prévisualisez** les données
6. **Lancez l'import** !

## 💡 **Conseils Pro**

### 🎨 **Organisation Recommandée**
- **Revenus** : Salaire, Freelance, Investissements
- **Besoins essentiels** : Alimentation, Transport, Loyer
- **Factures** : Électricité, Internet, Téléphone
- **Loisirs** : Restaurants, Cinéma, Streaming
- **Santé** : Médicaments, Dentiste, Assurance

### ⚡ **Formats de Date Supportés**
- `01/12/2024` (DD/MM/YYYY)
- `2024-12-01` (YYYY-MM-DD)  
- `12/01/2024` (MM/DD/YYYY)
- `01-12-2024` (DD-MM-YYYY)

### 💰 **Formats de Montant Supportés**
- `-45.50` (négatif = dépense)
- `2500.00` (positif = revenu)
- `€ 45,50` (avec symbole et virgule)
- `$ 2,500.00` (avec espaces et virgules)

## 🎉 **Avantages du Nouveau Système**

✅ **Organisation automatique** des enveloppes  
✅ **Pas de catégorie "fourre-tout"**  
✅ **Structure logique** dès l'import  
✅ **Gain de temps énorme**  
✅ **Import en masse** possible  

**Votre budget est maintenant organisé intelligemment dès l'import !** 🚀 