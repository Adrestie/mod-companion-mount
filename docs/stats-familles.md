# Compagnon : statistiques par famille (proposition)

Proposition du 2026-10-23, en cours de validation par l'utilisateur. Pas encore implémentée.

Chaque famille de compagnon gagne, à chaque niveau, des montants fixes de statistiques. Elle a une
affinité par rôle (DPS, Tank, Soin) : forte, moyenne ou faible.

## Paquets par niveau (affinité moyenne ×1)

| Rôle | Gain par niveau | Effet |
|---|---|---|
| DPS | +2 Force, +1 Agilité, +2 Dégâts des sorts | puissance d'attaque, critique, force de ses sorts offensifs (Drain de vie, Souffle de feu...) |
| Tank | +3 Endurance, +12 Armure | PV, réduction des dégâts |
| Soin | +3 Puissance des soins | force de ses soins |

Multiplicateurs : fort ×1,5, moyen ×1, faible ×0,5 (79 niveaux de gains au niveau 80).

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
| Bête ailée | faible | moyen | fort |
| Oiseau | moyen | faible | fort |
| Dragon | fort | moyen | faible |

Dragon : DPS fort, Tank moyen, Soin faible (choix de l'utilisateur, 2026-10-24 ; la proposition
d'origine était DPS moyen, Tank faible, Soin fort).

Répartition qui en résulte : DPS fort dans 5 familles, moyen 3, faible 4 ; Tank fort 4, moyen 5,
faible 3 ; Soin fort 3, moyen 4, faible 5.

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
