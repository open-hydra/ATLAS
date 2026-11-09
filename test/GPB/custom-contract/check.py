"""Test custom-contract: the contract that custom_classes.py declares is the one that the code enforces and the docs state.

usage: python3 -B check.py <ATLAS dir>

 - every method of every category's `functions` and every attribute of `data` has a name, a unit and a meaning, and
   appears in docs/databases/thermodynamics/custom.md;
 - every material of database/thermo/custom.py is an instance of CondensedMaterial given the required outputs, and gives
   valid values on 1 K steps over 200-6000 K;
 - a substance that breaks the contract is refused: a bad value (naming the function and the temperature), a missing
   or unknown output, a bad name, a name made twice in one file.
Needs numpy; exits 77 without it.
"""
import os
import sys

try:
    import numpy as np
except ImportError:
    print("numpy is not installed: skipped")
    sys.exit(77)

atlas = os.path.abspath(sys.argv[1])
sys.path.insert(0, os.path.join(atlas, "database", "thermo"))
import custom_classes as cc            # noqa: E402
import custom_loader                   # noqa: E402

failures = []


def check(ok, text):
    print(("ok   " if ok else "FAIL ") + text)
    if not ok:
        failures.append(text)


docs = open(os.path.join(atlas, "docs", "databases", "thermodynamics", "custom.md"), encoding="utf-8").read()

for base in (cc.CondensedMaterial, cc.IdealGasSpecies, cc.RealFluid):
    names = [q.name for q in base.data]
    for fn in base.functions:
        names += [fn.name] + [q.name for q in fn.inputs + fn.outputs]
        for q in fn.inputs + fn.outputs + base.data:
            check(bool(q.name and q.unit and q.meaning), f"{base.__name__}.{fn.name}: {q.name} has a unit and a meaning")
    for name in sorted(set(names)):
        check(f"`{name}" in docs, f"{base.__name__}: `{name}` is in docs/databases/thermodynamics/custom.md")
for q in cc.RealFluid._state_required + (cc.RealFluid._state_optional,):
    check(f"| `{q.name}` |" in docs, f"RealFluid.state: key {q.name} has a row in the docs table")

# the shipped materials: instances of CondensedMaterial, each with its own data for the required outputs
lib = custom_loader.load()
T = np.arange(200.0, 6000.1, 1.0)
required = [fn.name for fn in cc.CondensedMaterial.functions if fn.required]
for name, material in lib.registry["condensed"].items():
    check(type(material) is cc.CondensedMaterial, f"{name} is an instance of CondensedMaterial")
    check(all(key in material._values for key in required), f"{name} is given {', '.join(required)}")
    p = material.properties(T)
    check(all(np.all(np.isfinite(p[k])) for k in ("cp", "rho", "k", "h")), f"{name}: finite cp, rho, k, h on 200-6000 K")
    check(np.all(p["cp"] > 0) and np.all(p["rho"] > 0) and np.all(p["k"] >= 0), f"{name}: cp, rho > 0 and k >= 0")


def refused(make, error, text, what):
    try:
        make()
        check(False, what)
    except error as e:
        check(text in str(e), f"{what}: {e}")


# a substance that breaks the contract
cc.Substance._made_in_file = set()
refused(lambda: cc.CondensedMaterial("Broken-contract-test", cp=lambda T: 100.0 - T / 10.0, rho=1000.0).properties(T),
        ValueError, "cp(1000 K) = 0 is not a valid value (positive)", "a cp that reaches zero is refused at 1000 K")
refused(lambda: cc.CondensedMaterial("NoRho-contract-test", cp=100.0), TypeError, "give rho(T)",
        "a missing rho is refused when the material is made")
refused(lambda: cc.CondensedMaterial("Typo-contract-test", cp=100.0, rho=1.0, kk=3.0), TypeError,
        "kk is not in the contract of CondensedMaterial", "an output the contract does not have is refused")
refused(lambda: cc.CondensedMaterial("two words", cp=100.0, rho=1.0), TypeError, "must be one word",
        "a name that is not one INI word is refused")
refused(lambda: cc.IdealGasSpecies("NoData-contract-test", composition={"N": 2}), TypeError,
        "give composition and nasa7, or species", "a gas species without nasa7 or species is refused")
refused(lambda: cc.RealFluid("NoState-contract-test", reference=lambda T, p: (0.0, 0.0)), TypeError,
        "give state(h, p)", "a real fluid without state is refused")
cc.CondensedMaterial("Twice-contract-test", cp=1.0, rho=1.0)
refused(lambda: cc.CondensedMaterial("Twice-contract-test", cp=1.0, rho=1.0), ValueError, "made twice in the same file",
        "a name made twice in one file is refused")

sys.exit(1 if failures else 0)
