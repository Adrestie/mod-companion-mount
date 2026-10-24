# Compagnon : statistiques par famille (proposition)

Proposition du 2026-10-23, en cours de validation par l'utilisateur. Pas encore implémentée.

Chaque famille de compagnon gagne, à chaque niveau, des montants fixes de statistiques. Elle a une
affinité par rôle (DPS, Tank, Soin) : forte, moyenne ou faible.

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

## DPS physique ou magique (proposition du 2026-10-24, à valider)

Le DPS est séparé en physique et magique (demande de l'utilisateur). Chaque famille a une **nature** :
son affinité DPS s'applique au DPS de cette nature, l'autre ne lui apporte rien (×0), pour que les
familles DPS ne gagnent pas plus de statistiques que les autres.

| Nature | Familles | Pourquoi |
|---|---|---|
| Magique | Mort-vivant, Dragon, Bête ailée, Oiseau | sorts clés Drain de vie, Souffle de feu ; créatures « arcaniques » |
| Physique | Loup, Raptor, Félin, Bête lourde, Machine, Ours, Insecte, Cheval | coups, piétinements, morsures |

## Affinités

| Famille | DPS | Tank | Soin |
|---|---|---|---|
| Loup | fort | moyen | faible |
| Raptor | fort | moyen | faible |
| Félin | fort | faible | moyen |
| Mort-vivant | fort | faible | moyen |
| Bête lourde | moyen | fort | faible |
| Machine | moyen | fort | faible |
| Ours | faible | fort | moyen |
| Insecte | faible | fort | moyen |
| Cheval | faible | moyen | fort |
| Bête ailée | moyen | faible | fort |
| Oiseau | moyen | faible | fort |
| Dragon | fort | moyen | faible |

Dragon : DPS fort, Tank moyen, Soin faible (choix de l'utilisateur, 2026-10-24 ; la proposition
d'origine était DPS moyen, Tank faible, Soin fort).

Bête ailée : DPS moyen, Tank faible, Soin fort (choix de l'utilisateur, 2026-10-24 ; à l'origine DPS
faible, Tank moyen, Soin fort).

Répartition qui en résulte : DPS fort dans 5 familles, moyen 4, faible 3 ; Tank fort 4, moyen 4,
faible 4 ; Soin fort 3, moyen 4, faible 5.

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
