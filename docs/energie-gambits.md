# Compagnon : énergie et Gambits

Spécification validée par l'utilisateur le 2026-10-16. Tout se fait côté serveur (C++ et ALE/AIO), sans patch client.

## Énergie

- La barre d'énergie va jusqu'à 100. Elle se recharge comme celle du voleur : +10 par seconde, en combat comme hors combat.
- Chaque sort du compagnon coûte de l'énergie, qui remplace la limite actuelle par délai :

| Type de sort | Coût |
|---|---|
| Attaque ou soin rapide | 25 |
| Soin ou attaque forte, sort de zone | 40 |
| Sort défensif ou de contrôle | 50 |
| Sort clé de la monture | 60 |
| Ultime | 80, avec sa recharge propre |

- La barre jaune s'affiche simplement sous le portrait du compagnon, comme pour toute unité qui a une ressource (décision de l'utilisateur). Le compagnon est un gardien, et le jeu ne lui affiche pas de portrait : il faut donc lui ajouter un portrait, comme celui d'un familier, avec son nom, son niveau, ses PV et son énergie dessous. On le cible d'un clic.
- Les coûts sont réglables dans la conf.

## Gambits (IA réglée par le joueur, comme FFXII)

Un gambit est une règle : **cible + condition → action**. Le compagnon lit la liste de haut en bas. À chaque tour, il exécute la première règle dont la condition est vraie et dont l'action est possible (assez d'énergie, sort prêt, à portée). Sinon, il passe à la suivante.

### Emplacements
- 12 emplacements, comme dans FFXII. Il y en a 3 au niveau 1, puis +1 tous les 9 niveaux, soit 12 au niveau 80.
- Chaque règle s'active ou se coupe d'une case à cocher, et se déplace avec des flèches haut et bas.
- Les gambits sont gardés pour chaque monture.

### Conditions proposées

| Cible | Conditions |
|---|---|
| Toi (le joueur) | PV < 30/50/70/90 %, subit une attaque, porte un effet néfaste (poison, maladie, magie, malédiction) |
| Le compagnon | PV < 30/50/70 %, énergie ≥ 40/60/80 |
| Ennemi | Ta cible, sa cible, le plus proche, celui qui t'attaque, PV < 20/35/50 %, PV ≥ 90 %, en train d'incanter, élite ou boss |
| Groupe | Un membre à PV < 50 %, au moins 3 membres à PV < 70 % |
| Combat | 2/3/5 ennemis ou plus autour, toujours |

### Actions
- Tout sort appris par le compagnon (talents actifs, sort clé, ultime).
- Les ordres : Attaquer, Revenir près de toi.

### Gambits par défaut
- Chaque arbre fournit sa liste de départ, qui reproduit l'IA actuelle. Par exemple pour Bienveillance : « Toi : PV < 50 % → Lumière sacrée », « Groupe : 3 membres < 70 % → Prière de soins », « Ennemi : ta cible → Attaquer ».
- Un bouton Réinitialiser remet la liste par défaut.

### Lancement automatique
- Le clic droit sur un sort de la barre reste disponible.
- Un sort en lancement automatique sans gambit est lancé en dernier recours, quand aucune règle ne s'applique.

### Interface
- Une fenêtre Gambits s'ouvre depuis un bouton de la fiche et avec `/compagnon gambits`.
- Chaque ligne contient : une case à cocher, un menu de cible et condition, un bouton d'action avec l'icône du sort, et des flèches.
- Les emplacements verrouillés sont grisés, avec le niveau requis.
- Toutes les chaînes dans les 5 langues (enUS, frFR, deDE, esES, ruRU).
