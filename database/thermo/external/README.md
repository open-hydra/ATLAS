# External thermodynamic databases

This folder is for thermodynamic database files that ATLAS does not distribute. Git ignores everything in it except
this README. GPB looks here, as in `database/thermo/` and in the case directory, for the file of a database.

## Burcat

`thermo = Burcat` reads `burcat.yaml`, the Burcat database in Cantera format. ATLAS does not include it, because the
authors do not allow it to be included in software that can be used commercially, and ATLAS (GPL v3) can. The authors'
notice, from the current `BURCAT.THR` of the database (2023), reads:

> This database is provided free of charge for non commercial use, on condition that proper quotation will be included
> in the pertinent publications.
>
> IT IS STRICTLY FORBIDDEN TO INCLUDE THIS DATABASE AS IS OR PARTS OF IT IN ANY COMMERCIAL DATABASE, SOFTWARE, FIRMWARE
> OR HARDWARE AND ANY OTHER TYPE OF COMMERCIAL USE WITHOUT WRITTEN PERMISSION FROM THE AUTHORS.

For commercial use, ask the authors for their written permission (Elke Goos, `Elke.Goos@dlr.de`). Whoever puts the
file in this folder is responsible for its use. Publications that use it quote:

> Alexander Burcat and Branko Ruscic, "Third Millennium Ideal Gas and Condensed Phase Thermochemical Database for
> Combustion with updates from Active Thermochemical Tables", ANL-05/20 and TAE 960, Technion-IIT, Aerospace
> Engineering, and Argonne National Laboratory, Chemistry Division, September 2005,

or, for the extended database:

> Elke Goos, Alexander Burcat and Branko Ruscic, "Extended Third Millennium Ideal Gas Thermochemical Database with
> updates from Active Thermochemical Tables", <http://burcat.technion.ac.il/dir>.

### Getting the file

The authors distribute the database at <http://burcat.technion.ac.il/dir/>, with a daily mirror at
<https://respecth.elte.hu/burcat.php>. They publish it in their own formats (`BURCAT.THR`, and `THERM.DAT` in Chemkin
format), not in Cantera's. GPB needs a Cantera YAML file named `burcat.yaml` whose `species:` section holds the
species with NASA 7-coefficient thermo records; put it in this folder (or in the case directory).

Cantera's `ck2yaml` converts a Chemkin thermo file alone (`ck2yaml --thermo=THERM.DAT --output=burcat.yaml`), but the
`THERM.DAT` of the 2023 edition does not convert as it is: it has numbers with blanks in the exponent (`0.0       E 00`)
and entries whose mid temperature equals their lower bound (a single range given as two sets of coefficients), which
`ck2yaml` refuses even with `--permissive`. ATLAS has no conversion script yet.

### Without the file

GPB stops at `thermo = Burcat` with an error that points here. The test that reads `burcat.yaml`
(`IG-transport-CEA-aliases`) is disabled when it is absent. Its reference was computed with the 2016 edition of the file
converted for Cantera by J. Santner.
