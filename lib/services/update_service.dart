import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:dio/dio.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  // Vérifier si une mise à jour est disponible
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;

      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(seconds: 0),
        ),
      );
      await remoteConfig.fetchAndActivate();

      final latestVersion = remoteConfig.getString('latest_version');
      final apkUrl = remoteConfig.getString('apk_url');
      final releaseNotes = remoteConfig.getString('release_notes');

      if (latestVersion.isNotEmpty &&
          apkUrl.isNotEmpty &&
          latestVersion.compareTo(currentVersion) > 0) {
        return UpdateInfo(
          currentVersion: currentVersion,
          latestVersion: latestVersion,
          apkUrl: apkUrl,
          releaseNotes: releaseNotes.isNotEmpty ? releaseNotes : null,
        );
      }
      return null;
    } catch (e) {
      print('Erreur lors de la vérification de mise à jour: $e');
      return null;
    }
  }

  // Proposer la mise à jour à l'utilisateur
  Future<bool> proposeUpdate(
    BuildContext context,
    UpdateInfo updateInfo,
  ) async {
    final shouldUpdate = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.system_update,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            const Text('Mise à jour disponible'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Une nouvelle version est disponible !',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Version actuelle: ${updateInfo.currentVersion}'),
            Text(
              'Nouvelle version: ${updateInfo.latestVersion}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (updateInfo.releaseNotes != null) ...[
              const SizedBox(height: 12),
              const Text(
                'Nouveautés:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                updateInfo.releaseNotes!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Voulez-vous installer cette mise à jour maintenant ?',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Plus tard'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.download),
            label: const Text('Installer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    return shouldUpdate ?? false;
  }

  // Télécharger et installer la mise à jour
  Future<void> downloadAndInstall(
    BuildContext context,
    UpdateInfo updateInfo,
  ) async {
    try {
      // Créer une clé globale pour accéder au dialogue de progression
      final progressKey = GlobalKey<_DownloadProgressDialogState>();

      // Afficher le dialogue de progression avec mise à jour en temps réel
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) =>
            _DownloadProgressDialog(key: progressKey, updateInfo: updateInfo),
      );

      // Télécharger l'APK avec mise à jour de la progression
      final tempDir = await getTemporaryDirectory();
      final savePath =
          "${tempDir.path}/mise_a_jour_${updateInfo.latestVersion}.apk";
      final dio = Dio();

      await dio.download(
        updateInfo.apkUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            // Mettre à jour la progression dans le dialogue
            progressKey.currentState?.updateProgress(
              progress,
              'Téléchargement en cours...',
            );
          }
        },
      );

      // Mettre à jour le statut final
      progressKey.currentState?.updateProgress(1.0, 'Téléchargement terminé !');

      // Attendre un peu pour que l'utilisateur voie la progression complète
      await Future.delayed(const Duration(milliseconds: 500));

      // Fermer le dialogue de progression
      Navigator.of(context).pop();

      // Afficher message de succès
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Ouverture de l\'installateur...'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // Ouvrir l'APK pour installation
      final result = await OpenFile.open(savePath);

      // Gérer le résultat
      if (result.type == ResultType.done) {
        _showInstallationInstructions(context);
      } else if (result.type == ResultType.noAppToOpen) {
        _showInstallationError(
          context,
          'Aucune application trouvée pour installer le fichier APK. Vérifiez que l\'installation depuis des sources inconnues est autorisée.',
        );
      } else if (result.type == ResultType.permissionDenied) {
        _showInstallationError(
          context,
          'Permission refusée. Allez dans Paramètres > Sécurité > Sources inconnues et autorisez l\'installation d\'applications.',
        );
      } else {
        _showInstallationError(
          context,
          'Erreur lors de l\'ouverture: ${result.message ?? "Erreur inconnue"}',
        );
      }
    } catch (e) {
      // Fermer le dialogue de progression s'il est encore ouvert
      Navigator.of(context).pop();

      String errorMessage = 'Erreur inconnue';
      if (e.toString().contains('SocketException')) {
        errorMessage = 'Erreur de connexion internet';
      } else if (e.toString().contains('HttpException')) {
        errorMessage = 'Erreur lors du téléchargement (serveur)';
      } else if (e.toString().contains('PathAccessException')) {
        errorMessage = 'Erreur d\'accès au stockage';
      } else {
        errorMessage = 'Erreur : ${e.toString()}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  // Workflow complet de mise à jour
  Future<void> checkAndProposeUpdate(BuildContext context) async {
    final updateInfo = await checkForUpdate();

    if (updateInfo != null) {
      final shouldUpdate = await proposeUpdate(context, updateInfo);

      if (shouldUpdate) {
        await downloadAndInstall(context, updateInfo);
      }
    }
  }

  void _showInstallationInstructions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Installation en cours'),
        content: const Text(
          'L\'installateur a été ouvert. Suivez les instructions à l\'écran pour terminer l\'installation de la mise à jour.\n\n'
          'Une fois l\'installation terminée, redémarrez l\'application.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showInstallationError(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erreur d\'installation'),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Méthode de test pour démontrer la barre de progression
  Future<void> testDownloadProgress(BuildContext context) async {
    final progressKey = GlobalKey<_DownloadProgressDialogState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => _DownloadProgressDialog(
        key: progressKey,
        updateInfo: UpdateInfo(
          currentVersion: "1.0.0",
          latestVersion: "1.0.1",
          apkUrl: "test",
          releaseNotes: "Version de test pour démontrer la progression",
        ),
      ),
    );

    // Simuler un téléchargement progressif
    for (int i = 0; i <= 100; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
      final progress = i / 100.0;

      String statusMessage;
      if (progress < 0.3) {
        statusMessage = 'Connexion au serveur...';
      } else if (progress < 0.7) {
        statusMessage = 'Téléchargement en cours...';
      } else if (progress < 0.95) {
        statusMessage = 'Finalisation...';
      } else {
        statusMessage = 'Téléchargement terminé !';
      }

      progressKey.currentState?.updateProgress(progress, statusMessage);
    }

    // Attendre un peu avant de fermer
    await Future.delayed(const Duration(seconds: 1));
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test de progression terminé !'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String apkUrl;
  final String? releaseNotes;

  UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.apkUrl,
    this.releaseNotes,
  });
}

class _DownloadProgressDialog extends StatefulWidget {
  final UpdateInfo updateInfo;

  const _DownloadProgressDialog({required this.updateInfo, Key? key})
    : super(key: key);

  @override
  State<_DownloadProgressDialog> createState() =>
      _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  double progress = 0.0;
  String statusMessage = 'Préparation du téléchargement...';

  void updateProgress(double newProgress, String newStatusMessage) {
    setState(() {
      progress = newProgress;
      statusMessage = newStatusMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.download, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Téléchargement en cours'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(statusMessage),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toStringAsFixed(0)}%',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Version ${widget.updateInfo.latestVersion}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
