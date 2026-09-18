# Installateur Windows — AccordMémo 1.0.0

Ces commandes s’exécutent **dans la VM Windows**, depuis la racine du dépôt
(`C:\dev\projects\AccordMemo`).

Le JSON OAuth Desktop reste hors Git et hors installateur :

`C:\dev\secrets\accordmemo.oauth.json`

## 1. Préparer les sources

```bat
git pull
flutter pub get
```

## 2. Build Release

Le fichier `--dart-define-from-file` injecte uniquement les identifiants
OAuth **application** (client ID / client secret Desktop). Il n’embarque
aucun refresh token utilisateur.

```bat
flutter build windows --release --dart-define-from-file=C:\dev\secrets\accordmemo.oauth.json
```

Bundle attendu :

```
build\windows\x64\runner\Release\
```

Vérifier que ce dossier contient au minimum `accord_memo.exe`,
`flutter_windows.dll` et `data\`. L’installateur copie **tout** ce dossier.

Si le chemin Release réel diffère, ajuster `BuildDir` dans
`installer\AccordMemo.iss`.

## 3. Compiler l’installateur

Inno Setup 6 doit être installé. Exemple :

```bat
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\AccordMemo.iss
```

Sortie :

```
dist\AccordMemo-Setup-1.0.0.exe
```

## 4. Ce que l’installateur ne fait pas

- il ne copie pas `C:\dev\secrets\`
- il ne supprime pas `%APPDATA%\AccordMemo\` à la désinstallation
- il n’installe pas Visual C++ Redistributable (décision reportée)
