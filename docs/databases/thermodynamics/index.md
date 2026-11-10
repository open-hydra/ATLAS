# Thermodynamics Databases

GPB reads the thermodynamics of every phase from one source, selected by the key `thermo` of the phase section. The
source is a database file for the species of a gas or a condensed phase, the equation of state of a real fluid, or the
classes that you write in [`custom.py`](custom.md).

| `thermo` | Source | Format | Phase types | Temperature range | Origin |
|---|---|---|---|---|---|
| `NASA9` | `nasa9.yaml` | NASA 9-coefficient polynomials | gas, condensed | 200 – 20 000 K | NASA Glenn Research Center |
| `NASA7` | `nasa_gas.yaml`, `nasa_condensed.yaml` of Cantera | NASA 7-coefficient polynomials | gas, condensed | 200 – 6000 K | the NASA 7-coefficient database, shipped with Cantera (not a file of ATLAS) |
| `Burcat` | `burcat.yaml` | NASA 7-coefficient polynomials | gas, condensed | 200 – 6000 K | Burcat, Goos, Ruscic (ATcT); **not distributed**, see [below](#burcat-distribution) |
| `custom` | `custom.py` | Python classes | gas, condensed, real fluid | yours | your substances, see [Custom Substances](custom.md) |
| `constant` | the section of `input.ini` | `cp`, `rho`, `mu`, `k` (and `a`) | real fluid | — | your constants, see [Constant Properties](../../user-guide/gpb/real-fluid.md#constant-properties) |
| `coolprop` | CoolProp library | multiparameter EOS | real fluid | per fluid | CoolProp, 100+ fluids |
| `redlich-kwong`, `peng-robinson` | `redlich-kwong.yaml`, `peng-robinson.yaml` | cubic EOS | real fluid | — | critical constants, acentric factor |

What each kind of phase accepts:

| Phase `type` | `thermo` | Default |
|---|---|---|
| `ideal-gas`, `heavy-gas` | `NASA7`, `NASA9`, `Burcat`, `custom` | none: the species of a `reactions` file keep the records of the file, the others come from `NASA9` |
| `solid`, `solid-bulk`, `condensed-dispersed`, `liquid-dispersed`, `solid-dispersed` | `NASA7`, `NASA9`, `Burcat`, `custom` | `NASA9`, unless `cp` is given |
| `real-fluid` | `coolprop`, `redlich-kwong`, `peng-robinson`, `custom`, `constant` | `coolprop` |

---

## Burcat distribution

The Burcat database is free for non-commercial use with citation, and its authors forbid including it in commercial
software, databases or hardware without their written permission. ATLAS is released under the GPL, which does not allow
such a restriction on what it distributes, so it does not include `burcat.yaml`. A user who wants it downloads it from
its authors, converts it to Cantera YAML and puts it in `database/thermo/external/`, which git ignores:
the folder's `README.md` gives the authors' notice, the sources, the citation and what is known about the conversion.
Without the file, `thermo = Burcat` stops with an error that points there.

Everything else in the table is either shipped (`nasa9.yaml`, the two cubic EOS files) or comes with a library
(`NASA7` with Cantera, `coolprop` with CoolProp).

---
