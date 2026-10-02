# Till Next Level

Addon autonome pour **WoW Forever 1.60.1 (Interface 16001)**, inspiré du principe des barres d'XP de Luxthos. Aucune dépendance à WeakAuras.

- XP actuelle, XP requise et pourcentage du niveau.
- XP par heure et temps estimé avant le niveau suivant.
- Projection sur la barre : bleu = XP actuelle, vert = quêtes terminées prêtes à rendre, or = quêtes en cours.
- Détail des récompenses, XP reposée et temps estimé après remise des quêtes au survol.
- Position, échelle et visibilité enregistrées par personnage.

## Utilisation

Installer le dossier `TillNextLevel` dans `Interface/AddOns`, puis redémarrer le jeu ou faire `/reload` si l'addon était déjà détecté.

**Cliquer-glisser avec le bouton gauche** déplace la barre, sans touche supplémentaire. Si la position est verrouillée, utiliser `/tnl unlock`. La barre mesure 640 × 132, avec une jauge de 24 et des textes de 20 et 16 pour améliorer la lisibilité ; `/tnl scale` permet de l'agrandir davantage.

| Commande | Action |
| --- | --- |
| `/tnl` | Afficher les commandes |
| `/tnl show` / `/tnl hide` | Afficher / masquer |
| `/tnl lock` / `/tnl unlock` | Verrouiller / déverrouiller la position |
| `/tnl center` | Replacer la barre sous le centre de l'écran |
| `/tnl scale 1.2` | Régler l'échelle entre 0.5 et 2 |
| `/tnl reset` | Recommencer la mesure de la session |

## Calculs et limites

L'XP par heure est la moyenne depuis la connexion, le dernier `/reload` ou `/tnl reset`, pauses comprises. Les passages d'un niveau à l'autre sont pris en compte. Un saut de plusieurs niveaux réinitialise la mesure car les besoins des niveaux intermédiaires ne sont pas connus.

Les récompenses sont lues avec `GetQuestLogRewardXP(questID)` lorsque le client expose cette fonction. Une récompense indisponible est indiquée par `?` et le total est signalé comme partiel. Aucun montant n'est inventé. Les quêtes échouées et les entrées cachées sont exclues. La prévision n'inclut pas l'XP des monstres à tuer pour finir une quête ni d'éventuels bonus non inclus dans la récompense fournie par le client. Les projections visuelles s'arrêtent à la fin du niveau ; les totaux restent complets.

L'addon ne modifie pas la sélection du journal de quêtes. Les autres variantes de Classic ne sont pas couvertes par cette première version.

## Vérification

`tests/model.lua` et `tests/runtime.lua` vérifient les calculs et les événements avec des API simulées. Une validation en jeu reste nécessaire pour confirmer l'affichage et la disponibilité des récompenses sur la bêta Forever.
