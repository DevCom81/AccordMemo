const clientsPageTitle = 'Clients & Pianos';

const clientsSearchHint = 'Nom, prénom, ville ou e-mail';

const clientsSearchSemanticsLabel = 'Rechercher un client';

const clientsFilterActive = 'Actifs';

const clientsFilterArchived = 'Archivés';

const clientsEmptyActiveTitle = 'Aucun client actif.';

const clientsEmptyArchivedTitle = 'Aucun client archivé.';

const clientsEmptyActiveBody = 'Aucun client n’est enregistré pour le moment.';

const clientsEmptyArchivedBody = 'Aucun client n’est archivé.';

const clientsEmptySearchTitle = 'Aucun résultat.';

const clientsEmptySearchBody =
    'Aucun client ne correspond à cette recherche.';

const clientsLoadErrorMessage = 'Impossible de charger les clients.';

const clientsLoadingMessage = 'Chargement des clients';

const clientsPianosLoading = 'Chargement des pianos';

const clientsSelectPrompt = 'Sélectionnez un client dans la liste.';

const clientsArchivedBanner = 'Client archivé';

const clientsPianosSection = 'Pianos';

const clientsArchivedPianosSection = 'Pianos archivés';

const clientsNoPianoTitle = 'Aucun piano.';

const clientsNoPianoBody = 'Ce client n’a pas encore de piano enregistré.';

const clientsPianosLoadError = 'Impossible de charger les pianos.';

const clientsBackToList = 'Retour';

const clientsRemindersDisabled = 'Rappels désactivés';

const clientsPhoneLabel = 'Téléphone';

const clientsEmailLabel = 'E-mail';

const clientsNewCustomer = 'Nouveau client';

const clientsEditCustomer = 'Modifier';

const clientsSaveCustomer = 'Enregistrer';

const clientsCancel = 'Annuler';

const clientsCreateTitle = 'Nouveau client';

const clientsEditTitle = 'Modifier le client';

const clientsLastNameLabel = 'Nom';

const clientsFirstNameLabel = 'Prénom';

const clientsCivilityLabel = 'Civilité';

const clientsCivilityNone = 'Non renseignée';

const clientsCivilityMonsieur = 'Monsieur';

const clientsCivilityMadame = 'Madame';

const clientsAddressLabel = 'Adresse';

const clientsPostalCodeLabel = 'Code postal';

const clientsCityLabel = 'Ville';

const clientsLastNameRequired = 'Le nom est obligatoire.';

const clientsMutationGenericError = 'Impossible d’enregistrer le client.';

const clientsArchiveAction = 'Archiver';

const clientsArchiveTitle = 'Archiver ce client ?';

const clientsArchiveBody =
    'Le client ne sera plus modifiable tant qu’il n’aura pas été restauré. '
    'Ses pianos restent en place. Les relances planifiées de ses pianos seront '
    'annulées et les rappels désactivés. Restaurer le client ne réactivera pas '
    'automatiquement les rappels.';

const clientsArchiveConfirm = 'Archiver';

const clientsRestoreAction = 'Restaurer';

const clientsRestoreTitle = 'Restaurer ce client ?';

const clientsRestoreBody =
    'Le client redeviendra actif. Les rappels de ses pianos ne seront pas '
    'réactivés automatiquement.';

const clientsRestoreConfirm = 'Restaurer';

const clientsArchivedNotModifiable =
    'Ce client est archivé. Restaurez-le avant de le modifier.';

const clientsAlreadyArchived = 'Ce client est déjà archivé.';

const clientsNotArchived = 'Ce client n’est pas archivé.';

const clientsNotFound = 'Ce client est introuvable.';

String clientsReminderEveryMonths(int months) {
  return 'Rappel tous les $months mois';
}
