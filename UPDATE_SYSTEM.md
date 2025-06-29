# 🔄 Système de Mise à Jour Automatique

Ce document explique comment fonctionne le système de mise à jour automatique de l'application Toutie Budget.

## 📋 Vue d'ensemble

Le système combine **Firebase Remote Config** et **Firebase App Distribution** pour offrir une expérience de mise à jour fluide :

1. **Remote Config** détecte les nouvelles versions
2. **App Distribution** fournit les liens de téléchargement sécurisés
3. **L'application** propose automatiquement les mises à jour aux utilisateurs

## 🚀 Workflow de l'utilisateur

### 1. **Détection automatique**
- L'app vérifie les mises à jour au démarrage (après 2 secondes)
- Vérification via Firebase Remote Config

### 2. **Proposition de mise à jour**
- Si une nouvelle version est disponible, l'app affiche un dialogue
- L'utilisateur voit :
  - Version actuelle vs nouvelle version
  - Notes de version (si disponibles)
  - Boutons "Plus tard" ou "Installer"

### 3. **Téléchargement et installation**
- Si l'utilisateur accepte, l'app télécharge l'APK
- Barre de progression en temps réel
- Ouverture automatique de l'installateur Android
- L'utilisateur clique sur "Installer" dans la fenêtre système

## 🛠️ Configuration Firebase

### Remote Config
Configurez ces paramètres dans Firebase Console > Remote Config :

```json
{
  "latest_version": "1.0.2",
  "apk_url": "https://firebaseappdistribution.com/...",
  "release_notes": "Correction de bugs et améliorations"
}
```

### App Distribution
1. Ajoutez des testeurs dans Firebase Console > App Distribution
2. Configurez les groupes (ex: "testeurs", "developers")
3. Uploadez vos APK via la console ou Gradle

## 📦 Déploiement d'une nouvelle version

### Méthode automatique (recommandée)
Utilisez le script PowerShell :

```powershell
.\scripts\deploy_update.ps1 -version "1.0.2" -releaseNotes "Correction de bugs"
```

### Méthode manuelle
1. **Build de l'APK** :
   ```bash
   flutter build apk --release
   ```

2. **Upload vers App Distribution** :
   ```bash
   ./gradlew appDistributionUploadRelease
   ```

3. **Récupérer le lien** depuis la console Firebase App Distribution

4. **Mettre à jour Remote Config** avec :
   - `latest_version` : nouvelle version
   - `apk_url` : lien de téléchargement
   - `release_notes` : notes de version

## 🔧 Configuration Gradle

Le projet est configuré pour Firebase App Distribution :

### android/build.gradle.kts
```kotlin
classpath("com.google.firebase:firebase-appdistribution-gradle:4.2.0")
```

### android/app/build.gradle.kts
```kotlin
plugins {
    id("com.google.firebase.appdistribution")
}

buildTypes {
    release {
        firebaseAppDistribution {
            artifactType = "APK"
            releaseNotes = "Nouvelle version avec corrections de bugs"
            groups = "testeurs"
        }
    }
}
```

## 📱 Expérience utilisateur

### Avantages
- ✅ **Détection automatique** au démarrage
- ✅ **Interface claire** avec informations de version
- ✅ **Téléchargement sécurisé** via Firebase
- ✅ **Installation guidée** avec instructions
- ✅ **Gestion d'erreurs** complète

### Limitations Android
- L'utilisateur doit toujours accepter l'installation (sécurité Android)
- Impossible d'installer automatiquement sans intervention

## 🚨 Gestion d'erreurs

Le système gère automatiquement :
- Erreurs de connexion internet
- Erreurs de téléchargement
- Permissions manquantes
- APK corrompu
- Sources inconnues non autorisées

## 📊 Monitoring

### Logs utiles
- Vérification de mise à jour : `checkForUpdate()`
- Progression téléchargement : `onReceiveProgress`
- Erreurs d'installation : `ResultType`

### Métriques Firebase
- Utilisation de Remote Config
- Taux de téléchargement App Distribution
- Erreurs d'installation

## 🔒 Sécurité

- **APK signé** : Tous les builds sont signés
- **Lien sécurisé** : Firebase App Distribution fournit des liens sécurisés
- **Vérification** : L'app vérifie la version avant téléchargement
- **Permissions** : Gestion des permissions d'installation

## 📝 Notes importantes

1. **Testez toujours** sur un petit groupe avant diffusion large
2. **Vérifiez les permissions** d'installation sur les appareils de test
3. **Documentez les changements** dans les release notes
4. **Surveillez les erreurs** après déploiement

## 🆘 Dépannage

### Problèmes courants
- **APK non trouvé** : Vérifiez le chemin de build
- **Upload échoué** : Vérifiez les credentials Firebase
- **Lien invalide** : Régénérez le lien dans App Distribution
- **Installation échouée** : Vérifiez les sources inconnues

### Support
Pour toute question, consultez :
- [Firebase App Distribution Docs](https://firebase.google.com/docs/app-distribution)
- [Firebase Remote Config Docs](https://firebase.google.com/docs/remote-config) 