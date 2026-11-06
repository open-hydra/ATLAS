# External mechanisms

This folder is for chemical mechanisms that are not published with ATLAS. Git ignores everything in it except this README, so a mechanism put here never enters the repository.

Put the Cantera YAML files here, directly or in folders of any depth:

```
database/chemistry/external/MyMechanism.yaml
database/chemistry/external/MyFamily/MyMechanism/MyMechanism.yaml
```

GPB, KAnT and the GUI search this folder, and its folders that hold YAML files, after `database/chemistry/`: a
mechanism is named in the input by its file name without `.yaml`, as for the others (`reactions = MyMechanism`), and the GUI lists it. Give a mechanism a file name that `database/chemistry/` does not use already.

A folder with YAML files added while the GUI is open is found at its next start; a file put directly in this folder
is found at once.

## TSR mechanisms

`TSR-CDF-13`, `TSR-GP-24`, `TSR-PSR-11`, `TSR-Rich-31` and `TSR-Rich-39` are not in the repository. They are
available on request to the authors of the paper that describes them (see the TSR section of
`docs/databases/chemistry/list.md`). Once obtained, put their YAML files here.
