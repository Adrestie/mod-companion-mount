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
- **Clic droit** : on la chevauche — le sort de monture correspondant est lancé sur le joueur
  (instantané par défaut, réglable) et elle disparaît comme un familier renvoyé. Pied à terre : elle
  revient. Les refus habituels du sort (combat, intérieur…) s'affichent et elle reste là.
- `.companion dismiss` la renvoie à l'écurie, `.companion info` dit où elle en est.

## Identifiants provisoires

La tranche 91 (`91000-91999`) est libre dans `ID_RANGES.md` mais **pas encore attribuée** :
le module y prend provisoirement la créature `91000` et le sort serveur `91000` (jamais lancé,
il sert à la ligne de `npc_spellclick_spells`). À changer dans `src/CompanionMount.h` et
`data/sql/world/` quand la plage sera décidée.

## Ce qui vient ensuite

Contrôle de la monture par l'interface (ALE : attaquer, suivre, rester, passif), loot comme le
joueur, expérience et niveaux, talents DPS / Tank / Heal, inventaire, renommage — interface par
patch client et addon.

# Installation (développement)

Le dossier du module dans `modules/` du core (copie ou jonction), recompiler, copier
`conf/mod-companion-mount.conf.dist` en `mod-companion-mount.conf` dans `configs/modules`. Le SQL de
`data/sql/world` et `data/sql/characters` est appliqué par le core au démarrage.
