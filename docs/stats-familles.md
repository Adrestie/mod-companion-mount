# Compagnon : statistiques par famille (proposition)

Proposition du 2026-10-23, en cours de validation par l'utilisateur. Pas encore implémentée.

Chaque famille de compagnon gagne, à chaque niveau, des montants fixes de statistiques, propres à
la famille (tableau ci-dessous). Le premier jet (paquets par rôle, affinités forte / moyenne /
faible, nature physique ou magique) est remplacé par ce tableau.

## Gains par niveau, par famille (décision de l'utilisateur, 2026-10-24)

Chaque famille a ses propres gains à chaque montée de niveau ; ils remplacent les paquets par rôle
et les multiplicateurs d'affinité. Une fourchette (« 1 à 2 ») n'est **pas aléatoire** : elle est
déterminée par le niveau. Le gain alterne entre les deux valeurs, la valeur haute aux niveaux pairs.
Le total au niveau N vaut donc la moyenne de la fourchette × (N - 1), arrondie à l'inférieur.

| Famille | Rôle | Gain par niveau | Total au niveau 80 (79 gains) |
|---|---|---|---|
| Loup, Raptor | DPS physique | +3 Force, +2 Agilité, +1 à 2 Endurance | 237 Force, 158 Agilité, 118 Endurance |
| Félin | DPS physique | +3 Force, +1 Agilité, +1 Endurance, +2 Puissance des soins | 237 Force, 79 Agilité, 79 Endurance, 158 Puissance des soins |
| Bête lourde, Machine | Tank | +3 Force, +3 à 4 Endurance | 237 Force, 276 Endurance |
| Ours, Insecte | Tank | +2 Force, +3 Endurance, +2 Puissance des soins | 158 Force, 237 Endurance, 158 Puissance des soins |
| Dragon | DPS magique | +2 Endurance, +4 à 5 Dégâts des sorts | 158 Endurance, 355 Dégâts des sorts |
| Mort-vivant | DPS magique | +1 Endurance, +3 à 4 Dégâts des sorts, +1 à 2 Puissance des soins | 79 Endurance, 276 Dégâts des sorts, 118 Puissance des soins |
| Cheval | Soin | +2 Endurance, +2 Force, +4 à 5 Puissance des soins | 158 Endurance, 158 Force, 355 Puissance des soins |
| Bête ailée, Oiseau | Soin | +1 Endurance, +2 Dégâts des sorts, +3 à 4 Puissance des soins | 79 Endurance, 158 Dégâts des sorts, 276 Puissance des soins |

Les rôles donnent l'arbre de talents affiché en premier : Fureur pour le DPS physique, l'arbre de
dégâts magiques pour le DPS magique (Tank et Soin : à préciser, Fureur par défaut).

## Ce qui vient du joueur

- Part de la puissance d'attaque du maître : **0 %** (décision de l'utilisateur, 2026-10-24 : le compagnon
  aura son propre équipement, la part du maître le rendrait surpuissant). 22 % aujourd'hui.
- Soins : **rien du maître** non plus (décision de l'utilisateur, 2026-10-24). Ses soins valent le sort au
  rang de son niveau, multiplié par `CompanionMount.HealingRate` (**33 %**, réglable dans la conf ; décision du 2026-10-24),
  plus sa propre Puissance des soins (famille, puis équipement).

## Mise en œuvre prévue

- Table `mod_companion_mount_kind_stats` (famille → affinité DPS / Tank / Soin), paquets et
  multiplicateurs dans la conf.
- Appliqué avec les statistiques de son niveau (`ApplyStats`).
- Fiche : Force, Agilité, Endurance dans « Caractéristiques principales » ; la catégorie « Sorts »
  affiche les **Dégâts des sorts** et la **Puissance des soins** (demande de l'utilisateur, 2026-10-24).
