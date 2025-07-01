# 🧪 Guide : Bouton Test Import CSV (Émulateur)

## 🎯 **Problème Résolu**

**Avant :** Impossible de tester l'import CSV sur l'émulateur (pas de fichiers accessibles)  
**Maintenant :** Bouton de test intégré avec données YNAB pré-chargées !

## 🚀 **Nouvelle Fonctionnalité**

### 📍 **Localisation :**
**Paramètres** → **🧪 Test Import CSV (Émulateur)**

### ✨ **Ce qui se passe automatiquement :**

1. **Navigation** → Page Import CSV s'ouvre
2. **Mode Test activé** → Badge orange "🧪 TEST" dans l'AppBar  
3. **Chargement automatique** → 10 transactions YNAB d'exemple
4. **Mapping automatique** → Colonnes YNAB pré-configurées
5. **Prêt à tester** → Validation des comptes et import !

## 📊 **Données de Test Incluses :**

```csv
Account              | Date        | Payee            | Category Group        | Category           | Outflow  | Inflow
WealthSimple Cash    | 22/06/2025  | Microsoft        | Dépense Irrégulière   | Autre Non Credit   | 17.24$   | 0.00$
WealthSimple Cash    | 21/06/2025  | Emby             | Dépense Irrégulière   | Autre Non Credit   | 7.15$    | 0.00$
WealthSimple Cash    | 20/06/2025  | Maxi Port Cartier| Dépense Obligatoire   | Épicerie           | 26.03$   | 0.00$
WealthSimple Cash    | 19/06/2025  | Paye Arbec       | Inflow                | Ready to Assign    | 0.00$    | 1011.88$
WealthSimple Cash    | 17/06/2025  | Shell            | Dépense Non Obligatoire| Cigarette         | 148.62$  | 0.00$
WealthSimple Cash    | 16/06/2025  | Udemy            | Dépense Irrégulière   | Formation          | 25.28$   | 0.00$
WealthSimple Cash    | 15/06/2025  | Adobe            | Abonnement            | Adobe Creative     | 22.98$   | 0.00$
WealthSimple Cash    | 12/06/2025  | Paye Arbec       | Inflow                | Ready to Assign    | 0.00$    | 871.88$
WealthSimple Cash    | 10/06/2025  | YouTube Premium  | Abonnement            | YouTube            | 14.94$   | 0.00$
WealthSimple Cash    | 09/06/2025  | Irving           | Dépense Non Obligatoire| Essence           | 97.82$   | 0.00$
```

## 🎯 **Étapes de Test Complètes :**

### **1️⃣ Accès au Test**
```
Paramètres → 🧪 Test Import CSV (Émulateur)
```

### **2️⃣ Vérification Automatique**
✅ **Fichier chargé** → 10 transactions  
✅ **Mapping YNAB** → Toutes colonnes assignées  
✅ **Mode Test** → Badge orange visible  

### **3️⃣ Prévisualisation**
- Voir les 5 premières transactions
- Vérifier le mapping automatique
- Toutes les colonnes YNAB sont correctes

### **4️⃣ Test de l'Import**
1. **Cliquer "Commencer l'import"**
2. **Modal de validation s'ouvre** → WealthSimple Cash
3. **Choisir votre compte** → Dropdown avec vos comptes
4. **Confirmer** → Import automatique
5. **Succès !** → Transactions dans votre budget

## 🔧 **Fonctionnalités du Mode Test :**

### **🎨 Interface Spéciale :**
- **AppBar** → Badge "🧪 TEST" orange
- **Section fichier** → Bandeau orange explicatif
- **Chip compteur** → Orange au lieu de bleu
- **Messages** → Indiquent clairement le mode test

### **🧠 Intelligence :**
- **Chargement instantané** → Pas de sélection de fichier
- **Mapping automatique** → Toutes colonnes YNAB assignées
- **Données réalistes** → Vraies transactions YNAB
- **Gestion complète** → Outflow, Inflow, Ready to Assign

### **✅ Tests Complets :**
- **Types de transactions** → Dépenses et revenus
- **Catégories variées** → Obligatoire, Abonnement, Inflow
- **Montants réalistes** → De 7$ à 1011$
- **Validation comptes** → WealthSimple Cash mapping

## 🎉 **Avantages pour les Développeurs :**

### **🚀 Tests Rapides :**
- **0 seconde** → Setup du fichier CSV
- **1 clic** → Accès au test complet
- **Reproductible** → Toujours les mêmes données
- **Complet** → Toutes les fonctionnalités testées

### **🛠️ Débogage Facile :**
- **Données contrôlées** → Pas de surprise dans le CSV
- **Mapping garanti** → Toujours les bonnes colonnes
- **Isolation** → Test sans dépendances externes
- **Validation complète** → Modal de comptes inclus

## 📱 **Utilisation Émulateur :**

**Parfait pour :**
- ✅ **Tests de développement**
- ✅ **Démonstrations clients**
- ✅ **Validation des fonctionnalités**
- ✅ **Formation utilisateurs**

**Ne remplace pas :**
- ❌ **Import de vrais fichiers** (utilisez le bouton normal)
- ❌ **Tests de performance** (données limitées)

## 🎯 **Résultat Attendu :**

Après le test, vous devriez avoir dans votre budget :

📁 **Nouvelles Catégories :**
- **Dépense Obligatoire** → Épicerie
- **Dépense Non Obligatoire** → Cigarette, Essence  
- **Abonnement** → Adobe Creative, YouTube
- **Dépense Irrégulière** → Formation, Autre Non Credit

💰 **Transactions importées :** 10 transactions avec montants corrects  
🏦 **Compte utilisé :** Celui que vous avez choisi dans la validation  

**Le test complet de votre système d'import YNAB en 1 clic !** 🚀

---

## 💡 **Conseil :**

Utilisez ce bouton pour :
1. **Tester** vos modifications d'import
2. **Démontrer** la fonctionnalité aux utilisateurs  
3. **Valider** le mapping automatique YNAB
4. **Former** quelqu'un sur l'import CSV

**Développement et tests facilités !** 😊 