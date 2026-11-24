# Particle-combustion reactions

A file of this folder names what a burning condensed material becomes: the reactions that
`particle-mechanism = <stem>` of a dispersed `[GPB-Phase*]` section selects (`<stem>.yaml`, looked up in the case
directory first, then here; a name present in both stops GPB). GPB turns them into records of
`<name>products.txt`, which hydra-MI2 reads: the mass a solver's burning model takes from the material enters the gas
as these species, and the heat of reaction is the difference of their formation enthalpies. The burning RATE is the
solver's (`combustion = ...` of the same section), not this file's.

```yaml
name: <label printed in the file>
description: <one line>
reference: <where the reaction comes from>
reactions:
- equation: 2 AL(L) + 1.5 O2 => AL2O3
```

A material that burns (`combustion = Beckstead` or `direct` on its line) needs a reaction that consumes it: without
one GPB stops. A reaction is one of three kinds, told apart by its condensed species:

| kind | reaction | record |
|---|---|---|
| combustion | the material, with gas species, gives gas species only | `combustion` of the material |
| carry | the material, with gas species, gives one condensed product: the material that `carried =` names for it, a line of 0 groups of the same phase | `carry` of the material |
| release | a carried material, with gas species, gives gas species only | `release` of the carried material |

A material that carries another (`share` or `carry`, with `carried`) needs its combustion and its carry reaction;
`residue = off`, which hands the carried mass to the gas at burnout, needs the release reaction of the carried
material as well. The carry reaction also gives IGLOO its `yield`, the kg carried per kg burnt.

Rules, each checked by GPB:

- irreversible reactions, written with `=>`;
- exactly one condensed reactant per reaction, a material of the phase; a material is consumed by one reaction of
  each kind at most;
- a material is named as its species of the thermo database of the section (`thermo = NASA9` or `Burcat`), or it
  has constant properties (`rho`, `cp`) and gives `h0`, its enthalpy at 298.15 K on the gas's scale; the mass
  balance of the reaction then fixes its molar mass, and all the reactions that name it must agree;
- every gas species of a reaction is a species of the gas phase of the deck, with the same molar mass in the two
  files;
- element balance where every species is in the database, and mass coefficients that sum to 1;
- no thermodynamic data here: the formation enthalpies are those of the thermo database, or `h0`.

No reaction is distributed yet: the folder holds this page only.
