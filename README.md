# CompanionMount
AzerothCore Mount mod

# L'idée 
- Avoir sa monture qui se déplace et combat avec le joueur quand il est en exterieur
- la monture va looter les cadavres automatiquement comme si le joueur le faisait lui-même
- la monture gagne de l'xp et monte de niveau
- chaque monture a un arbre de talents DPS / Tank / Heal
- les arbres de talents ont un sort "Clé" en fonction du type de monture
- les autres montures non utilisée gagnent un % de l'xp de la monture utilisée
- utilisable en même temps que le pet du joueur
- clic droit sur la monture permet de grimper dessus normalement
- la monture possède son inventaire dédié
- la monture possède des sorts ou compétences selon son archétype
- la monture est renommable
- nice to have : la monture possède son équipement -> ajout de loot en donjons et dans le monde, faisable via https://github.com/Adrestie/WoW-mods-dynamicloot

# Où on en est

## Jalon 1 : la monture marche, combat, et se chevauche

- **Invocation** : `.companion summon` sur une monture que l'on chevauche (on descend, elle marche à côté),
  ou `.companion summon <sort>` (id ou lien d'un sort de monture connu). Le choix est gardé en base et
  survit à la déconnexion.
- **Suivi et combat** : c'est un *gardien* (comme le loup fantôme du chaman), pas un familier : le
  familier du chasseur ou du démoniste reste là. Elle prend le niveau du joueur et les chiffres d'une
  créature de ce niveau. Défensive : elle frappe la cible du joueur, ce qui l'attaque, ou ce qui
  l'attaque elle ; à plus de 40 m du joueur, elle revient.
- **Dehors seulement** : elle rentre à l'intérieur des bâtiments, en donjon et en champ de bataille
  (réglable), en vol de taxi, en véhicule, à la mort du joueur ; elle ressort d'elle-même ensuite.
  Tombée au combat, elle revient au bout de 60 s (réglable).
- **Clic droit** : on la chevauche — le sort de monture correspondant est lancé sur le joueur comme
  depuis son grimoire (temps d'incantation, impossible en combat ; instantané en option). Les refus
  habituels du sort s'affichent et elle reste là.
- **Monter renvoie le compagnon**, quelle que soit la monture (clic droit, grimoire, objet) ; pied
  à terre, il revient.
- `.companion dismiss` la renvoie à l'écurie, `.companion info` dit où elle en est.

## Jalon 2 : les ordres, comme un familier

- **Barre de la monture** (envoyée au client par AIO, rien à installer en plus d'AIO_Client) :
  Appeler, Renvoyer, Attaquer, Suivre, Rester, Agressive, Défensive, Passive — les icônes de la
  barre du familier. L'ordre et l'attitude en cours sont allumés. Maj + glisser déplace la barre
  (gardée par personnage), `/companion` ou `/compagnon` la cache ou la montre.
- **Mêmes ordres au clavier** : `.companion attack | follow | stay | passive | defensive | aggressive`.
  Passive : n'attaque que sur ordre. Défensive (défaut) : votre cible, ce qui vous attaque, ce qui
  l'attaque. Agressive : en plus, tout ennemi à 20 m. Rester : garde sa place et y revient après un
  combat ; à plus de 100 m du joueur elle revient et suit de nouveau.
- L'attitude est gardée en base ; une connexion repart toujours sur « suivre ».
- La partie ALE (`data/lua/CompanionMount`) ne décide rien : chaque bouton lance la commande
  `.companion` correspondante au nom du joueur et renvoie l'état à la barre.
- `.companion debug` (MJ) : ce que le serveur sait de la bête (PV, cible, mouvement), pour les tests.

## Jalon 3 : le butin, comme le joueur

- Hors combat, quand elle suit, la monture va au corps le plus proche (30 m autour du joueur,
  réglable) que le joueur a le droit de fouiller, et le butin passe dans ses sacs par les chemins
  du core : objets de quête, « chacun le sien », conditions, hauts faits, partage de l'argent avec
  le groupe. Elle ne prend que ce que la fenêtre de butin laisserait prendre au joueur (rien en
  jet de dés, réservé au maître du butin ou au tour d'un autre) ; le reste reste sur le corps.
- Avec mod-aoe-loot, elle ramasse comme le joueur avec ce module : arrivée à un corps, elle
  fouille aussi les autres corps à portée, avec les réglages de mod-aoe-loot (`AoeLoot.Enable`,
  `Range`, `MaxCorpses`, `LineOfSight`, lus dans sa conf ; mod-aoe-loot n'est pas modifié).
- Pas de doublon avec mod-aoe-loot : même objet `loot` du core, et elle ne touche à rien tant que
  le joueur a une fenêtre de butin ouverte. Sacs pleins : elle laisse l'objet et le dit (une fois
  par minute).
- Ses coups comptent comme ceux du joueur pour le butin et les récompenses
  (`CompanionMount.KillsRewardOwner`) : sans cela, le core ne donne rien d'un monstre tué par
  un familier seul.

## Jalon 4 : l'expérience et les niveaux

- Chaque monture a sa progression (par personnage et par sort de monture). Celle qui est dehors
  gagne de l'expérience à chaque monstre que le joueur ou elle achève : la formule du core,
  calculée à son niveau, doublée pour un élite. Il lui faut 5 % de ce qu'il faut au joueur pour un
  niveau (comme le familier du chasseur), et elle ne dépasse pas le niveau du joueur. Ses PV et
  ses dégâts suivent son niveau.
- Les montures restées à l'écurie reçoivent 10 % de cette expérience, même celles jamais sorties
  (un pot commun par personnage, versé à la sortie).
- `.companion info` donne niveau et expérience, la barre affiche le niveau.
- Réglages : `CompanionMount.Level.Enable`, `Start` (1), `CapToOwner` (1), `XpNeedRate` (0.05),
  `XpKillRate` (1.0), `SharedPercent` (10).

## Jalon 5 : le renommage

- `.companion rename <nom>` (ou le bouton Renommer de la barre) nomme la monture choisie ; chaque
  monture garde son nom, en base. Sans nom, elle reprend celui de toutes les montures-compagnons.
- Le nom suit les règles des noms de familiers (12 lettres au plus, un seul alphabet, noms
  réservés et grossiers refusés) ; un refus s'affiche avec le message du jeu.
- Il s'affiche au-dessus d'elle par le chemin des noms de familiers (numéro de familier et
  demande de nom), puisque toutes partagent le même modèle de créature.

## Identifiants provisoires

La tranche 91 (`91000-91999`) est libre dans `ID_RANGES.md` mais **pas encore attribuée** :
le module y prend provisoirement la créature `91000` et le sort serveur `91000` (jamais lancé,
il sert à la ligne de `npc_spellclick_spells`). À changer dans `src/CompanionMount.h` et
`data/sql/world/` quand la plage sera décidée.

## Ce qui vient ensuite

Talents DPS / Tank / Heal, inventaire — interface par
patch client et addon.

# Installation (développement)

Le dossier du module dans `modules/` du core (copie ou jonction), recompiler, copier
`conf/mod-companion-mount.conf.dist` en `mod-companion-mount.conf` dans `configs/modules`. Le SQL de
`data/sql/world` et `data/sql/characters` est appliqué par le core au démarrage. Le dossier
`data/lua/CompanionMount` va dans `lua_scripts` (ALE + AIO).
