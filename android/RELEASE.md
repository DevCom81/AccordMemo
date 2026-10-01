# Livraison Android AccordMémo

Installation directe d'un APK, sans Play Store. Identité :
`fr.pianosoccitanie.accordmemo`, nom `AccordMémo`, version initiale `1.0.0+1`.
Les commandes ci-dessous sont à exécuter manuellement depuis la racine du dépôt.

## Clé permanente, hors dépôt

Créer une seule fois cette clé. Ne jamais la remplacer pour une mise à jour.
`keytool` demande les mots de passe interactivement ; ne pas les passer en
arguments et ne pas les transmettre à un tiers.

```bash
umask 077
mkdir -p "$HOME/secrets/accordmemo"
keytool -genkeypair -v -storetype JKS -keyalg RSA -keysize 3072 \
  -validity 10000 -alias accordmemo \
  -keystore "$HOME/secrets/accordmemo/accordmemo-release.jks"
```

Sauvegarder durablement et séparément le keystore et ses mots de passe.
Le certificat public et ses empreintes ne sont pas des secrets.

```bash
keytool -list -v -alias accordmemo \
  -keystore "$HOME/secrets/accordmemo/accordmemo-release.jks"
```

Relever SHA-1 et SHA-256. Préparer le fichier local ignoré par Git :

```bash
cp -n android/key.properties.example android/key.properties
chmod 600 android/key.properties
nano android/key.properties
```

Remplir `storeFile` avec le chemin absolu du fichier créé (par exemple
`/home/jey/secrets/accordmemo/accordmemo-release.jks`), `storePassword` avec le
mot de passe du keystore, `keyAlias=accordmemo`, et `keyPassword` avec celui de
la clé. Si la saisie keytool a réutilisé le mot de passe du keystore pour la
clé, les deux valeurs seront identiques. Aucun `~` ou `$HOME` n'est développé
dans un fichier Java Properties. Le fichier est lu en UTF-8 ; les antislashs
doivent être doublés et une espace initiale dans une valeur doit être échappée.

Ne jamais versionner le fichier rempli. Les règles `*.jks`, `*.keystore` et
`key.properties` sont déjà présentes dans `.gitignore`.

## Google Cloud

Dans le projet AccordMemo, créer manuellement un nouveau client OAuth Android :

- Package : `fr.pianosoccitanie.accordmemo`
- SHA-1 : empreinte du certificat Release obtenue ci-dessus.

Conserver le client Android Debug existant. Conserver aussi le Web serverClientId
existant, transmis par dart-define :
`414814841216-m8ot7e06nab7fvggahs563a3c2jngpj7.apps.googleusercontent.com`.
La différence Debug/Release porte sur le certificat du client Android, pas sur
le Web client du même projet. Aucun secret Web n'est embarqué.

## Contrôles et build

```bash
flutter analyze --no-pub
flutter test --no-pub
git diff --check
```

Pas de test de parsing du script Gradle : les contrôles de signature doivent
être vérifiés réellement. Sans `android/key.properties`, une build Debug doit
fonctionner et la commande Release ci-dessous doit échouer avec un message
`Signature Release AccordMémo`. Après configuration, elle doit réussir.

```bash
flutter build apk --debug \
  --dart-define="ACCORD_MEMO_GOOGLE_ANDROID_SERVER_CLIENT_ID=414814841216-m8ot7e06nab7fvggahs563a3c2jngpj7.apps.googleusercontent.com"

flutter build apk --release \
  --dart-define="ACCORD_MEMO_GOOGLE_ANDROID_SERVER_CLIENT_ID=414814841216-m8ot7e06nab7fvggahs563a3c2jngpj7.apps.googleusercontent.com"
```

Les mots de passe incorrects ou une clé absente du keystore sont refusés par
la validation de signature Android. Il n'existe aucun repli Release vers Debug.

Le launcher `@mipmap/accordmemo_launcher` est généré au build à partir de
`Assets/logoApp.png` (1254 × 1254, carré opaque). Les tailles mdpi, hdpi, xhdpi,
xxhdpi et xxxhdpi sont respectivement 48, 72, 96, 144 et 192 pixels. Le dessin
entier est redimensionné proportionnellement, sans recadrage ni modification
du logo. Les anciens bitmaps Flutter ne sont plus référencés par le manifeste.
Les sorties de génération restent dans `build/` et ne sont pas versionnées.
Pas d'icône adaptive artificiellement découpée : le PNG contient déjà son fond.

APK attendu : `build/app/outputs/flutter-apk/app-release.apk`.

Pour le SDK local actuellement installé :

```bash
/mnt/projets/.android-sdk/build-tools/36.0.0/apksigner verify --verbose --print-certs \
  build/app/outputs/flutter-apk/app-release.apk

/mnt/projets/.android-sdk/build-tools/36.0.0/aapt2 dump badging \
  build/app/outputs/flutter-apk/app-release.apk
```

Comparer les empreintes SHA-256 et SHA-1 du signataire de l'APK avec celles de
`keytool -list -v`. La seule mention « signature valide » ne suffit pas : il
faut le certificat Release attendu. Vérifier également package, label,
`versionCode='1'` et `versionName='1.0.0'` dans le résultat d'aapt2.
Sur un autre poste, adapter uniquement le chemin vers les Android Build Tools.

## Installation et recette

Une installation Debug portant le même package ne peut pas être mise à jour
directement par cet APK Release signé avec une autre clé. Avant sa
désinstallation, exporter via SAF les données à conserver vers un emplacement
extérieur au stockage privé de l'application. Installer ensuite la Release,
restaurer cette sauvegarde et reconnecter Google. La désinstallation supprime
les données privées ; Android Auto Backup reste désactivé.

Transférer l'APK par USB/fichier (une copie peut s'appeler
`AccordMemo-1.0.0.apk`). L'ouvrir sur la tablette, autoriser si nécessaire
« installer des applications inconnues » pour le gestionnaire de fichiers
utilisé, puis installer et lancer AccordMémo.

1. Vérifier nom et icône, puis créer des données TEST.
2. Connecter Google, envoyer un rappel et vérifier sa réception.
3. Fermer complètement l'application puis la relancer.
4. Envoyer un second rappel sans reconnexion et vérifier sa réception.
5. Exporter une sauvegarde via SAF, puis modifier les données TEST.
6. Restaurer la copie et vérifier le retour des données.
7. Fermer et relancer pour vérifier la persistance SQLite.
8. Vérifier portrait/paysage, icône et nom dans le launcher.

## Versions suivantes

Conserver le package et **exactement la même clé et le même certificat Release**
(donc le même keystore et alias). Augmenter le build number Flutter à chaque
livraison, par exemple `1.0.1+2`, et installer l'APK comme mise à jour, sans
désinstaller. Cela conserve le stockage privé SQLite ; ne jamais considérer le
keystore comme un fichier temporaire ou régénérable.
