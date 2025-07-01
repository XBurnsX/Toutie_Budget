# 🎯 Guide Import YNAB → Toutie Budget

## 📊 **Mapping des Colonnes YNAB**

Votre fichier CSV YNAB a cette structure particulière. Voici comment bien mapper vos colonnes :

### 🔗 **Correspondances Exactes :**

| **Champ Toutie Budget** | **Colonne YNAB** | **Explication** |
|-------------------------|------------------|-----------------|
| **Date** ✅ | `Date` | Date de la transaction |
| **Compte** ✅ | `Account` | Votre compte (ex: "WealthSimple Cash") |
| **Tiers** | `Payee` | Qui/Où (ex: "Microsoft", "Shell") |
| **Categorie** | `Category Group` | 📁 Catégorie (ex: "Dépense Obligatoire") |
| **Enveloppe** | `Category` | 💰 Enveloppe (ex: "Épicerie", "Essence") |
| **Note** | `Memo` | Description/Commentaire |
| **Outflow** | `Outflow` | 💸 Montant des dépenses |
| **Inflow** | `Inflow` | 💰 Montant des revenus |

### ⚠️ **IMPORTANT - Colonnes YNAB à IGNORER :**

- ❌ **"Category Group/Category"** → Ne pas mapper (c'est une combinaison)
- ❌ **"Flag"** → Pas nécessaire
- ❌ **"Cleared"** → Pas nécessaire

## 🎯 **Résultat de l'Import :**

Avec votre CSV YNAB, le système va créer automatiquement :

📁 **Catégorie "Dépense Obligatoire"**
   ├── 💰 Épicerie
   ├── 💰 Loyer  
   └── 💰 Cellulaire

📁 **Catégorie "Abonnement"**
   ├── 💰 YouTube
   ├── 💰 Adobe Creative
   └── 💰 YNAB

📁 **Catégorie "Inflow"** 
   └── 💰 Ready to Assign

## 🚀 **Étapes d'Import :**

1. **Exportez** vos données depuis YNAB (format CSV)
2. **Ouvrez** Toutie Budget → Paramètres → Import CSV
3. **Sélectionnez** votre fichier YNAB
4. **Mappez** selon le tableau ci-dessus :
   - Date → `Date`
   - Compte → `Account` 
   - Tiers → `Payee`
   - Categorie → `Category Group`
   - Enveloppe → `Category`
   - Outflow → `Outflow`
   - Inflow → `Inflow`
   - Note → `Memo`
5. **Prévisualisez** et importez !

## 💡 **Conseils YNAB :**

### ✅ **Avant l'Export YNAB :**
- Assurez-vous d'avoir les **mêmes noms de comptes** dans Toutie Budget
- Exportez sur une **période définie** (ex: 1 mois)
- Vérifiez que vos **catégories sont bien organisées**

### 🎨 **Organisation Recommandée :**
Vos catégories YNAB seront importées telles quelles :
- **"Dépense Obligatoire"** → Besoins essentiels
- **"Dépense Non Obligatoire"** → Loisirs et extras  
- **"Abonnement"** → Services récurrents
- **"Inflow"** → Tous vos revenus

### ⚡ **Format Automatique :**
- **Outflow** (17.24$) → Dépense de 17,24€
- **Inflow** (1011.88$) → Revenu de 1011,88€
- Les **symboles monétaires** sont automatiquement nettoyés

## 🎉 **Avantages :**

✅ **Import direct** depuis YNAB  
✅ **Conservation** de votre organisation existante  
✅ **Création automatique** des catégories/enveloppes  
✅ **Pas de manipulation** de fichier nécessaire  
✅ **Gestion intelligente** Outflow/Inflow  

**Votre budget YNAB est maintenant dans Toutie Budget !** 🚀

---

## 📝 **Exemple de Mapping Visual :**

```
YNAB Column          →  Toutie Budget Field
─────────────────────────────────────────────
Account              →  Compte
Date                 →  Date  
Payee                →  Tiers
Category Group       →  Categorie
Category             →  Enveloppe
Memo                 →  Note
Outflow              →  Outflow (dépenses)
Inflow               →  Inflow (revenus)
```

Voilà ! Plus de confusion avec les colonnes doublées. 😊 