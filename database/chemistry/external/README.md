# External mechanisms

This folder is for chemical mechanisms that are not published with ATLAS. Git ignores everything in it except this README, so a mechanism put here never enters the repository.

Put the Cantera YAML files here, directly or in folders of any depth:

```
database/chemistry/external/MyMechanism.yaml
database/chemistry/external/MyFamily/MyMechanism/MyMechanism.yaml
```

GPB, KAnT and the GUI search this folder, and its folders that hold YAML files, after `database/chemistry/`: a
mechanism is named in the input by its file name without `.yaml`, as for the others (`reactions = MyMechanism`), and the GUI lists it.

A file name must be used once in the whole search path (`database/chemistry/`, this folder and its folders): if two
folders hold `MyMechanism.yaml`, which one Cantera would load depends on the order of the folders, so GPB stops with an
error that names both files, and the GUI marks the name as not usable. A `MyMechanism.yaml` in the case directory is
taken first, as for any mechanism.

The GUI reads this folder each time it needs it, so a file or a folder added while it is open is found without restarting it (the mechanism list refreshes when its editor is built again).

## TSR mechanisms

`TSR-CDF-13`, `TSR-GP-24`, `TSR-PSR-11`, `TSR-Rich-31` and `TSR-Rich-39` are not in the repository. They are
available on request to the authors of the paper that describes them (see the TSR section of
`docs/databases/chemistry/list.md`). Once obtained, put their YAML files here.
