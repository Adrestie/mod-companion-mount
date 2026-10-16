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

- **Le panneau Compagnon** (envoyé au client par AIO, rien à installer en plus d'AIO_Client), sa propre
  fenêtre à deux onglets : **Statistiques**, comme la feuille de personnage (la monture en 3D qu'on fait
  tourner en glissant, son nom, son niveau et son expérience, ses caractéristiques ; Renommer, Sacoches
  -- une icône qu'on peut glisser dans une barre d'action, la macro `/compagnon sacoches` -- et
  Talents) ; **Gambits**. Avec Forever UI, il prend son thème (dessiné à partir des textures qu'il
  installe) et s'ouvre par un micro-bouton de sa barre ; sans, le thème du jeu et un bouton au bord de
  la minimap. `/compagnon` l'ouvre, `/compagnon gambits` sur ses gambits, `/compagnon sacoches` les
  sacoches, `/compagnon talents` les talents.
- **La barre des ordres**, comme celle du familier : Appeler, Renvoyer, Attaquer, Suivre, Rester et
  les trois attitudes (ordre et attitude actifs allumés). Maj + glisser la déplace, `/compagnon barre`
  la masque ou la remontre.
- **Ses sorts** ont leur propre barre (au-dessus de celle des ordres, Maj + glisser la déplace) : les talents actifs appris et le sort clé, au rang qu'elle lance.
  Clic gauche : elle le lance tout de suite, sur sa cible habituelle. Clic droit : son lancement
  automatique se coupe ou revient, comme les techniques du familier du chasseur (même halo doré),
  gardé par monture. Au clavier : `.companion cast <sort>`, `.companion autocast <sort>`.
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

## Jalon 6 : les sacoches

- Une seule paire de sacoches par personnage, la même sur toutes ses montures (50 places, réglable),
  aux emplacements de la taille et de l'espacement des sacs (sprites de Forever UI s'il est installé).
  Fenêtre ouverte : clic droit sur un objet des sacs pour le ranger, clic droit dans les sacoches pour
  le reprendre.
  Bouton Sacoches de la barre : on peut aussi y glisser un objet de ses sacs.
  `.companion bag`, `.companion bag put <sac> <place>`, `.companion bag take <place>` au clavier.
- L'objet reste un objet : comme une pièce jointe de courrier, il quitte l'inventaire du joueur
  mais garde sa ligne d'`item_instance` (enchantements, gemmes, durabilité, liaison). Refusés :
  un sac non vide, un objet invoqué ou à durée. La monture doit être dehors, ou le joueur monté (réglable).
- Un personnage supprimé emporte ses montures et ce qu'elles portaient.

## Jalon 7 : les talents

- Trois arbres propres aux montures, faits de sorts que le client 3.3.5 connaît déjà (icônes,
  infobulles) : DPS « Fureur », Tank « Rempart », Soin « Bienveillance ». Passifs : talents de classe
  sans masque de classe (Cruauté, Précision, Robustesse, Anticipation, Divinité…), jusqu'à 5 rangs.
  Actifs : sorts de PNJ ou à rangs, lancés par l'IA de la monture (Rossée, Enchaînement, Provocation,
  Choc martial, Récupération et Salve de guérison sur le maître…). Liste complète dans
  `data/sql/world/companion_mount_12_new_talents.sql`.
- Les points se placent dans n'importe quel arbre (un seul arbre par monture en option : `Talent.OneTree`) ; 1 point au niveau 4 puis 1 tous les 2
  niveaux (39 au niveau 80), 5 points par rangée. La dernière rangée n'a qu'un talent, l'ultime.
- En haut de chaque arbre, le **sort clé**, selon le type de la monture (classé d'après le modèle de
  sa créature) et selon l'arbre : une attaque en Fureur, une défense en Rempart, un soin en
  Bienveillance (cheval : Piétinement / Intervention / Lumière sacrée ; kodo : Choc martial / Coup de
  tonnerre / Prière de soins…, table `mod_companion_mount_key_spell`). Et un **ultime** par arbre :
  Tempête de lames (Fureur), Cri de défi (Rempart), Tranquillité (Bienveillance).
- Les sorts actifs sont lancés au rang que permet le niveau de la monture, et l'infobulle de la fenêtre montre ce rang-là. Ses soins valent 40 % du sort (`CompanionMount.HealingRate`, 0.4).
- Fenêtre Talents (bouton de la barre), à l'image de celle du jeu. `.companion talent`,
  `.companion talent learn <id>`, `.companion talent reset`, `.companion setlevel <n>` (MJ).

## Jalon 8 : l'énergie et les Gambits

Spécification : `docs/energie-gambits.md`.

- **L'énergie** : 100, rendue comme celle du voleur (+10 par seconde). Chaque sort en coûte selon sa
  classe (`mod_companion_mount_talent.energy`) : attaque ou soin rapide 25, soin ou attaque forte et
  sort de zone 40, défensif ou contrôle 50, sort clé 60, ultime 80 (qui garde sa recharge). Elle
  remplace les délais entre deux lancers. Réglages `CompanionMount.Energy.*`.
- **Le portrait** : le jeu n'en montre pas pour un gardien ; l'interface en ajoute un (modèle, nom,
  niveau, PV, énergie en jaune dessous), nourri par un message d'addon (`CMPF`). Un clic cible le
  compagnon ; Maj + glisser le déplace. Sur la barre, un sort que l'énergie ne paie pas est grisé
  de bleu, et son infobulle donne son coût.
- **Les Gambits** (comme Final Fantasy XII) : des règles « cible + condition → action » lues de
  haut en bas ; à chaque tour, la première dont la condition est vraie et l'action possible (sort
  prêt, énergie, portée) est jouée. 3 emplacements au niveau 1, 10 au niveau 80. Conditions : toi
  (PV, attaqué, poison, maladie, magie, malédiction), le compagnon (PV, énergie), ennemi (ta cible,
  sa cible, le plus proche, celui qui t'attaque, PV, incante, élite ou boss), groupe (un membre
  < 50 %, 3 membres < 70 %), combat (2/3/5 ennemis autour, dès que prêt). Actions : ses sorts,
  Attaquer, Revenir près de toi. Passive, elle ne s'en prend à personne, gambit ou pas.
- La liste **par défaut** est tirée des sorts appris (ultime, secours, soins, purifications,
  provocation, attaques, puis « ta cible → Attaquer ») et suit les talents tant que le joueur n'y
  touche pas ; la sienne est gardée par monture. Réinitialiser y revient. Un sort en lancement
  automatique qu'aucun gambit ne nomme sert de dernier recours.
- **L'onglet Gambits** du panneau Compagnon (Réinitialiser en bas) ; `/compagnon gambits` l'ouvre ;
  **presets** : « Enregistrer sous... » garde la liste sous un nom (par personnage, pour toutes ses
  montures), le menu Presets en charge un ou en supprime ; `/compagnon preset <nom>` le charge (macro) ; case à cocher, menu cible et
  condition, action (icône du sort), flèches ; emplacements fermés grisés avec leur niveau. Textes en
  anglais, français, allemand, espagnol et russe. Au clavier : `.companion gambit [save|reset]`.

## Identifiants provisoires

La tranche 91 (`91000-91999`) est libre dans `ID_RANGES.md` mais **pas encore attribuée** :
le module y prend provisoirement la créature `91000` et le sort serveur `91000` (jamais lancé,
il sert à la ligne de `npc_spellclick_spells`). À changer dans `src/CompanionMount.h` et
`data/sql/world/` quand la plage sera décidée.

## Ce qui vient ensuite

Réglage fin des talents et des sorts selon les retours en jeu ; équipement des montures (DynamicLoot).

# Installation (développement)

Le dossier du module dans `modules/` du core (copie ou jonction), recompiler, copier
`conf/mod-companion-mount.conf.dist` en `mod-companion-mount.conf` dans `configs/modules`. Le SQL de
`data/sql/world` et `data/sql/characters` est appliqué par le core au démarrage. Le dossier
`data/lua/CompanionMount` va dans `lua_scripts` (ALE + AIO).
