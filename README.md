# CompanionMount

Module AzerothCore (WoW 3.3.5a) : votre monture devient un compagnon qui marche à vos côtés,
combat, ramasse le butin, progresse, apprend des talents et suit les règles que vous lui donnez.

> **Travail en cours (WIP).** Le module tourne et se joue, mais il évolue encore beaucoup :
> équilibrage des talents, des soins et de l'énergie, interface, identifiants provisoires
> (voir plus bas). Attendez-vous à des changements de données et de comportement d'une version à
> l'autre, et faites une sauvegarde de vos bases avant d'installer.

## Ce que fait la monture-compagnon

### Sortir, suivre, se battre

- **Invocation** : `.companion summon` sur une monture que vous chevauchez (vous descendez, elle
  marche à côté), ou `.companion summon <sort>` pour une monture connue. Le choix est gardé en base.
- C'est un **gardien** (comme le loup du chaman), pas un familier : le familier du chasseur ou du
  démoniste reste là. Elle prend votre niveau (au plus) et les chiffres d'une créature de ce niveau,
  avec 22 % de votre puissance d'attaque.
- **Dehors seulement** : elle rentre dans les bâtiments, en donjon, en raid et en champ de bataille
  (réglable), en taxi, en véhicule, à votre mort, et quand vous montez n'importe quelle monture ;
  elle ressort d'elle-même ensuite. Tombée au combat, elle revient au bout de 60 s.
- **Clic droit** sur elle : vous la chevauchez, avec le temps d'incantation habituel et jamais en
  combat (instantané en option).
- **Ordres**, comme un familier : Attaquer, Suivre, Rester, et les attitudes Passive, Défensive
  (par défaut) et Agressive.

### Butin

- Hors combat, elle va fouiller pour vous les corps que vous avez le droit de piller (30 m autour de
  vous), par les chemins du core : objets de quête, « chacun le sien », partage de l'argent, etc.
  Elle ne prend que ce que votre fenêtre de butin vous laisserait prendre.
- Avec **mod-aoe-loot**, elle ramasse comme vous avec ce module (les corps autour, mêmes réglages),
  sans doublon. Ses coups comptent comme les vôtres pour le butin et les récompenses.

### Progression

- Chaque monture a son **niveau et son expérience** (5 % de ce qu'il vous faut, comme le familier
  du chasseur), sans dépasser le vôtre. Les montures restées à l'écurie en reçoivent 10 %.
- **Renommage** (règles des noms de familiers), un nom par monture.
- **Sacoches** : une seule paire par personnage, partagée par toutes ses montures, 50 places. Les
  objets gardent tout (enchantements, gemmes, liaison). Clic droit pour ranger ou reprendre.

### Talents

- Trois arbres propres aux montures, faits de sorts que le client connaît déjà : **Fureur** (DPS),
  **Rempart** (Tank), **Bienveillance** (Soin). 39 points au niveau 80 (1 au niveau 4, puis 1 tous
  les 2 niveaux), 5 points par rangée, tous les arbres à la fois (un seul en option).
- Dans chaque arbre, un **sort clé** qui dépend du type de monture (cheval, loup, félin, kodo,
  oiseau, dragon...) et un **ultime** : Tempête de lames, Cri de défi, Tranquillité.
- Les sorts sont lancés au rang que permet son niveau ; ses soins valent 40 % du sort (réglable).

### Énergie et Gambits

Spécification : `docs/energie-gambits.md`.

- **Énergie** : 100, rendue à +10 par seconde comme celle du voleur. Chaque sort en coûte : rapide
  25, fort ou de zone 40, défensif ou contrôle 50, sort clé 60, ultime 80.
- **Gambits** (comme Final Fantasy XII) : des règles « cible + condition → action » lues de haut en
  bas ; à chaque tour, la première qui s'applique est jouée. 3 emplacements au niveau 1, 10 au
  niveau 80. Ce sont **les gambits seuls** qui lancent ses sorts. La liste par défaut est tirée des
  sorts appris ; vous pouvez la modifier, la réinitialiser, et l'enregistrer en **presets**
  (`/compagnon preset <nom>` pour changer en un clic, par exemple dans une macro).

## L'interface (ALE + AIO, sans patch client)

- **Le panneau Compagnon** : onglet **Statistiques** au format de la feuille de personnage (monture
  en 3D, niveau et expérience, caractéristiques avec un menu Mêlée / Sorts / Défense / Divers,
  Renommer, Sacoches, Talents) et onglet **Gambits**. Avec **Forever UI**, il prend son thème et
  s'ouvre par un micro-bouton de sa barre ; sans, le thème du jeu et un bouton au bord de la
  minimap.
- **La barre des ordres** : Appeler, Renvoyer, Attaquer, Suivre, Rester et les trois attitudes.
- **Le portrait** du compagnon : nom, niveau, PV et énergie ; un clic le cible.
- Barre et portrait se masquent en donjon, en raid et en champ de bataille.
- Textes de l'interface : français et anglais ; les nouveautés (énergie, portrait, gambits) aussi en
  allemand, espagnol et russe.

## Commandes

| Commande | Effet |
|---|---|
| `/compagnon` (ou `/companion`) | ouvre le panneau |
| `/compagnon gambits`, `talents`, `sacoches`, `barre` | ouvre les gambits, les talents, les sacoches ; masque la barre |
| `/compagnon preset <nom>` | charge un preset de gambits |
| `.companion summon [sort]`, `dismiss`, `info` | sortir, renvoyer, état |
| `.companion attack`, `follow`, `stay`, `passive`, `defensive`, `aggressive` | ordres |
| `.companion rename <nom>` | renommer |
| `.companion bag [put <sac> <place> \| take <place>]` | sacoches |
| `.companion talent [learn <id> \| reset]` | talents |
| `.companion gambit [save ... \| reset]`, `.companion cast <sort>` | gambits, lancer un sort |
| `.companion setlevel <n>`, `debug` (MJ) ; `.companion reload` (admin) | tests ; relire talents et sorts clés |

## Installation

**Prérequis** : AzerothCore WotLK, **mod-ale** avec **AIO** (côté serveur dans `lua_scripts`, et
l'addon AIO côté client). Facultatifs : **Forever UI** (thème et micro-bouton), **mod-aoe-loot**.

- **Avec l'installeur WoW-mods** : `installer.json` décrit le module (sources, configuration, Lua,
  tables et lignes en base). Il copie le module dans `modules/`, la conf dans `configs/modules`, le
  Lua dans `lua_scripts/CompanionMount` ; recompilez ensuite le serveur.
- **À la main** : le dossier dans `modules/` du core, relancer CMake et recompiler, copier
  `conf/mod-companion-mount.conf.dist` en `mod-companion-mount.conf` dans `configs/modules`, copier
  `data/lua/CompanionMount` dans `lua_scripts`. Le SQL de `data/sql/world` et `data/sql/characters`
  est appliqué par le core au démarrage.

Tous les réglages sont dans `conf/mod-companion-mount.conf.dist` (zones autorisées, butin, niveaux,
sacoches, talents, soins, énergie, gambits).

> **Désinstallation** : retirer le module supprime ses tables, y compris les sacoches. Videz-les
> avant (les objets qui y sont restent sinon sans propriétaire).

## Identifiants provisoires

La tranche 91 (`91000-91999`) est libre dans `ID_RANGES.md` mais **pas encore attribuée** : le
module y prend provisoirement la créature `91000` et le sort serveur `91000` (jamais lancé, il sert
au clic droit). Ils changeront quand la plage sera décidée.

## Reste à faire

- Équilibrage en jeu : talents, sorts clés, soins, coûts d'énergie, gambits par défaut.
- Catégorie « Sorts » des statistiques (vide pour l'instant).
- Équipement des montures (via DynamicLoot).
- Identifiants définitifs.
