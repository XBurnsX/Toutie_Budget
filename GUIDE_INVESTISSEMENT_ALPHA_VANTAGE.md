# Guide d'Investissement avec Alpha Vantage

## 🚀 Système de Batch Update Intelligent

Le système d'investissement utilise **Alpha Vantage** avec un batch update intelligent qui respecte les limites de l'API gratuite (500 requêtes/jour).

### ⚙️ Configuration

**API Key Alpha Vantage :** `BD4NV7ZVF2RBD59B`

### 🔄 Fonctionnement du Batch Update

1. **Toutes les 10 minutes** : Le système traite un batch de **5 actions**
2. **12 secondes entre chaque requête** : Respect de la limite de 5 req/min
3. **500 requêtes/jour maximum** : Reset automatique à minuit
4. **Queue intelligente** : Les actions sont ajoutées à une file d'attente

### 📊 Calculs de Performance

- **Valeur actuelle** = Quantité × Prix actuel
- **Gain/Perte** = Valeur actuelle - Valeur investie
- **Performance** = ((Prix actuel - Prix d'achat) / Prix d'achat) × 100

## 🎯 Utilisation

### 1. Ajouter une Action

1. Ouvrir la page d'investissement
2. Appuyer sur le bouton **+** (FAB)
3. Remplir :
   - **Symbole** : `AAPL`, `MSFT`, `RY.TO`, etc.
   - **Quantité** : Nombre d'actions
   - **Prix d'achat** : Prix par action

### 2. Vendre une Action

1. **Appuyer longuement** sur une action
2. Entrer le **prix de vente**
3. Confirmer la vente

### 3. Mise à Jour Manuelle

- Appuyer sur l'icône **🔄** dans l'AppBar
- Force une mise à jour immédiate du batch

## 📈 Fonctionnalités

### ✅ Actions Supportées

- **Actions US** : `AAPL`, `MSFT`, `GOOGL`, `TSLA`
- **Actions Canadiennes** : `RY.TO`, `TD.TO`, `SHOP.TO`
- **ETF** : `VFV.TO`, `QQC.TO`

### 📊 Affichage

- **Performance globale** du portefeuille
- **Gain/Perte** par action
- **Prix actuel** vs prix d'achat
- **Statistiques** Alpha Vantage (requêtes/jour)

### ⚠️ Limitations

- **Prix non disponible** : Affiché si l'API ne trouve pas le symbole
- **Limite quotidienne** : 500 requêtes maximum
- **Délai** : 10 minutes entre les mises à jour automatiques

## 🔧 Services

### AlphaVantageService

```dart
// Démarrer le batch update
AlphaVantageService().startBatchUpdate();

// Ajouter un symbole à la queue
AlphaVantageService().addSymbolToQueue('AAPL');

// Forcer une mise à jour
AlphaVantageService().forceUpdate();

// Obtenir les statistiques
final stats = AlphaVantageService().getStats();
```

### InvestissementService

```dart
// Ajouter une action
await InvestissementService().ajouterAction(
  compteId: 'compte_id',
  symbol: 'AAPL',
  quantite: 10,
  prixAchat: 150.0,
  dateAchat: DateTime.now(),
);

// Calculer la performance
final performance = await InvestissementService().calculerPerformanceCompte('compte_id');
```

## 📱 Interface Utilisateur

### Page d'Investissement

- **Carte de performance** : Valeur totale, gain/perte, performance
- **Liste des actions** : Prix actuel, performance par action
- **Bouton +** : Ajouter une nouvelle action
- **Long press** : Vendre une action
- **Pull to refresh** : Recharger les données

### Indicateurs Visuels

- 🟢 **Vert** : Performance positive
- 🔴 **Rouge** : Performance négative
- 🟠 **Orange** : Prix non disponible
- 🔄 **Timer** : Prochaine mise à jour

## 🧪 Test

### Actions de Test

```dart
// Ajouter des actions de test
await InvestissementService().ajouterActionsTest('compte_id');
```

Actions de test incluses :
- `AAPL` : 10 actions à $150
- `MSFT` : 5 actions à $300
- `GOOGL` : 2 actions à $2500
- `TSLA` : 3 actions à $800
- `RY.TO` : 20 actions à $120

## 🔍 Debug

### Logs Console

- `🔄 Batch update Alpha Vantage démarré`
- `📝 AAPL ajouté à la queue de mise à jour`
- `✅ Mise à jour AAPL (1/500 aujourd'hui)`
- `💾 Prix AAPL sauvegardé: $150.25`

### Statistiques

- **Requêtes aujourd'hui** : X/500
- **Actions en attente** : X
- **Prochaine mise à jour** : Xm Xs

## 🚨 Dépannage

### Prix non disponible

1. **Vérifier le symbole** : `AAPL` au lieu de `AAPL.US`
2. **Actions canadiennes** : `RY.TO` fonctionne
3. **Limite API** : Vérifier les requêtes/jour
4. **Connexion** : Vérifier l'accès internet

### Erreurs courantes

- **"Action non trouvée"** : L'action a été supprimée
- **"Montant insuffisant"** : Vérifier le solde du compte
- **"Erreur API"** : Problème temporaire Alpha Vantage

## 📋 Checklist de Déploiement

- [ ] API Key Alpha Vantage configurée
- [ ] Service démarré dans `main.dart`
- [ ] Page d'investissement accessible
- [ ] Test avec actions US et canadiennes
- [ ] Vérification des limites API
- [ ] Interface utilisateur testée

---

**Note :** Le système est conçu pour être robuste et respecter les limites des APIs gratuites tout en offrant une expérience utilisateur fluide. 