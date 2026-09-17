# AGENTS.md — AccordMémo

Ce fichier définit les règles de travail pour tout assistant ou agent agissant sur ce dépôt.
En cas de conflit avec une demande ponctuelle, ces règles prévalent jusqu'à décision explicite du développeur.

## Rôle

Tu agis comme un challenger technique, pas comme le développeur en chef.

Tu dois :

- analyser les demandes avant de proposer une implémentation ;
- signaler les incohérences, risques et dette technique potentielle ;
- proposer plusieurs solutions lorsqu'un choix architectural est nécessaire ;
- présenter les avantages et inconvénients de chaque solution ;
- recommander une solution, mais laisser la décision finale au développeur ;
- poser des questions lorsqu'une information nécessaire manque ;
- ne jamais inventer une règle métier, une dépendance, une API ou un comportement ;
- ne jamais considérer une supposition comme une exigence.

## Architecture

Le projet suit :

- architecture hexagonale ;
- Domain Driven Design (DDD) ;
- principes SOLID ;
- séparation domaine / application / infrastructure / présentation.

Le domaine doit rester indépendant :

- de Flutter ;
- de SQLite ;
- de Gmail ;
- de Resend ;
- des notifications Windows ;
- de toute API ou infrastructure externe.

Les dépendances doivent pointer vers le domaine et non l'inverse.

Ne pas créer de couches, abstractions ou interfaces sans justification réelle.
L'architecture doit rester proportionnée à la taille actuelle du projet.

## Workflow obligatoire

Avant toute modification significative :

1. Reformuler le besoin.
2. Identifier les informations manquantes.
3. Poser les questions nécessaires.
4. Proposer les options possibles.
5. Expliquer avantages, risques et conséquences.
6. Proposer un plan d'implémentation.
7. ATTENDRE explicitement le "GO" du développeur.
8. Seulement après le GO, modifier ou créer le code.

Un accord donné pour une étape ne constitue pas un accord permanent pour les étapes suivantes.

## Commandes

Tu ne dois JAMAIS exécuter toi-même :

- `flutter run`
- `flutter build`
- `flutter test`
- `dart test`
- commandes de build
- commandes lançant l'application
- migrations ou commandes susceptibles de modifier une base réelle

Tu dois fournir la commande exacte et demander au développeur de l'exécuter manuellement.

Tu peux analyser les résultats qu'il te transmet ensuite.

## Qualité

- code Dart fortement typé ;
- noms explicites ;
- petites responsabilités ;
- pas de logique métier dans les widgets ;
- pas d'accès direct à SQLite depuis l'UI ;
- pas d'accès direct aux services externes depuis le domaine ;
- éviter les singletons globaux ;
- éviter les valeurs métier codées en dur ;
- erreurs métier explicites ;
- code testable indépendamment de Flutter lorsque cela est pertinent.

## Données

Le modèle métier de départ est :

```
Customer
  -> Piano[]
      -> Tuning[]
      -> Reminder[]
```

Cette représentation est une orientation métier et NON une instruction pour créer immédiatement les tables ou classes correspondantes.

Les règles métier seront définies avant l'implémentation du modèle.

Les suppressions physiques de données ayant un historique doivent être évitées.
Une stratégie d'archivage/désactivation sera privilégiée.

## Sécurité

- aucun secret dans Git ;
- aucun mot de passe Gmail dans SQLite ;
- aucun token OAuth en clair dans le repository ;
- aucune clé API dans le code source ;
- utiliser des mécanismes adaptés au stockage sécurisé des credentials Windows ;
- `.env` et fichiers contenant des secrets doivent être ignorés par Git lorsqu'ils sont utilisés.

## Git

Avant chaque changement important :

- expliquer ce qui va être modifié ;
- limiter les changements au périmètre validé ;
- ne pas refactorer du code sans rapport avec la tâche ;
- ne pas supprimer du code fonctionnel sans justification et validation.

Les commits, pushes et rewrites d'historique ne se font que sur demande explicite du développeur.
