"""Tests of the `thermo` key in the GUI's GPB model (no Qt needed).

usage: python3 -B GUI/tests/test_gpbthermo.py [-v]

`thermo` selects the source of the thermodynamics in the three kinds of phase (a database, custom.py, or the equation
of state of a real fluid). The model renames the former spellings GPB still accepts (`model` of a real fluid,
`SP-database`), says what each section means by `thermo`, drops a value that the new family cannot take after a change of
type, and lists the substances of custom.py for the pickers; GRI-Mech 3.0, which Cantera ships, is listed with the mechanisms of the database. Needs numpy (custom.py does); skipped (77) without it.
"""

import os
import sys
import tempfile
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(_HERE))

try:
    import numpy  # noqa: F401
except ImportError:                      # pragma: no cover
    print("numpy is not installed: skipped")
    sys.exit(77)

from atlasgui import database, gpbmodel  # noqa: E402
from atlasgui.gpbmodel import GPBPhase  # noqa: E402

CASE_CUSTOM = '''
from custom_classes import CondensedMaterial, IdealGasSpecies

Resin = CondensedMaterial("Resin", cp=1500.0, rho=1200.0)
Argon = IdealGasSpecies("Ar", composition={"Ar": 1},
                        nasa7={"Tmin": 200.0, "Tmid": 1000.0, "Tmax": 6000.0,
                               "low": [2.5, 0, 0, 0, 0, -745.375, 4.37967491],
                               "high": [2.5, 0, 0, 0, 0, -745.375, 4.37967491]})
'''


class FormerSpellings(unittest.TestCase):
    def test_model_of_a_real_fluid_is_thermo(self):
        phase = GPBPhase([("type", "real-fluid"), ("fluid", "CO2"), ("model", "redlich-kwong"), ("pmin", "1e6")])
        self.assertEqual(phase.get("thermo"), "redlich-kwong")
        self.assertFalse(phase.has("model"))
        self.assertEqual(list(phase.params), ["type", "fluid", "thermo", "pmin"])   # in place: the order is kept
        self.assertEqual(phase.summary(), "CO2 · redlich-kwong")
        self.assertEqual(len(phase.migrated), 1)

    def test_thermo_wins_over_model(self):
        phase = GPBPhase([("type", "real-fluid"), ("thermo", "coolprop"), ("model", "peng-robinson")])
        self.assertEqual(phase.get("thermo"), "coolprop")
        self.assertEqual(phase.migrated, [])

    def test_model_equal_to_thermo_is_removed(self):
        # kept, a later change of thermo would leave a model that differs, which GPB refuses
        phase = GPBPhase([("type", "real-fluid"), ("thermo", "coolprop"), ("model", "coolprop")])
        self.assertFalse(phase.has("model"))
        self.assertEqual(len(phase.migrated), 1)
        phase.set("thermo", "peng-robinson")
        self.assertEqual([k for k in phase.params if k in ("thermo", "model")], ["thermo"])

    def test_sp_database_is_custom(self):
        phase = GPBPhase([("type", "solid"), ("material", "UC"), ("thermo", "SP-database")])
        self.assertEqual(phase.get("thermo"), "custom")
        self.assertEqual(len(phase.migrated), 1)

    def test_model_of_a_gas_is_not_touched(self):
        phase = GPBPhase([("type", "ideal-gas"), ("model", "x")])
        self.assertTrue(phase.has("model"))
        self.assertEqual(phase.migrated, [])

    def test_the_migration_is_reported(self):
        doc = gpbmodel.GPBDocument.from_ini("[GPB-Phase1]\ntype = real-fluid\nfluid = CO2\nmodel = coolprop\n"
                                            "pmin = 1\npmax = 2\nTmin = 3\nTmax = 4\n")
        info = [m for level, _i, m in doc.validate() if level == "info" and "model" in m]
        self.assertEqual(len(info), 1, doc.validate())
        self.assertIn("thermo = coolprop", doc.to_ini())


class SectionsOfThermo(unittest.TestCase):
    def test_each_family_has_its_own_description(self):
        gas = gpbmodel.describe("thermo", "gas")
        condensed = gpbmodel.describe("thermo", "condensed")
        real = gpbmodel.describe("thermo", "real-fluid")
        self.assertEqual(len({gas, condensed, real}), 3)
        self.assertIn("equation of state", real)
        self.assertIn("custom", condensed)
        self.assertEqual(gpbmodel.describe("thermo", "solid"), condensed)
        self.assertEqual(gpbmodel.default_of("thermo", "real-fluid"), "coolprop")
        self.assertEqual(gpbmodel.default_of("thermo", "condensed"), "NASA9")

    def test_without_a_family_the_first_section_answers(self):
        self.assertEqual(gpbmodel.describe("thermo"), gpbmodel.describe("thermo", "gas"))

    def test_custom_is_offered_everywhere(self):
        for values in (gpbmodel.THERMO_DATABASES, gpbmodel.CONDENSED_THERMO, gpbmodel.REAL_FLUID_THERMO):
            self.assertIn("custom", values)
        self.assertNotIn("SP-database", gpbmodel.CONDENSED_THERMO)

    def test_a_value_of_another_family_is_an_error(self):
        doc = gpbmodel.GPBDocument.from_ini("[GPB-Phase1]\ntype = real-fluid\nfluid = CO2\nthermo = NASA9\n"
                                            "pmin = 1\npmax = 2\nTmin = 3\nTmax = 4\n")
        self.assertTrue([m for level, _i, m in doc.validate() if level == "error" and "thermo = NASA9" in m])

    def test_change_of_type_drops_a_foreign_thermo(self):
        phase = GPBPhase([("type", "real-fluid"), ("thermo", "coolprop")])
        phase.set("type", "ideal-gas")
        phase.drop_foreign_thermo()
        self.assertFalse(phase.has("thermo"))
        phase = GPBPhase([("type", "ideal-gas"), ("thermo", "Burcat")])
        phase.set("type", "solid")
        phase.drop_foreign_thermo()
        self.assertEqual(phase.get("thermo"), "Burcat")          # a database of both families stays
        phase = GPBPhase([("type", "ideal-gas"), ("thermo", "custom")])
        phase.set("type", "real-fluid")
        phase.drop_foreign_thermo()
        self.assertEqual(phase.get("thermo"), "custom")


class CustomPickers(unittest.TestCase):
    def test_shipped_materials(self):
        names = database.species_of_database("custom", "solid")
        self.assertIn("UC", names)
        self.assertIn("Graphite", names)
        self.assertEqual(database.species_of_database("custom", "liquid-dispersed"), names)

    def test_a_gas_phase_lists_species_not_materials(self):
        self.assertEqual(database.species_of_database("custom", "ideal-gas"), [])

    def test_the_case_directory_adds_its_substances(self):
        with tempfile.TemporaryDirectory() as case:
            with open(os.path.join(case, "custom.py"), "w") as handle:
                handle.write(CASE_CUSTOM)
            self.assertIn("Resin", database.species_of_database("custom", "solid", case))
            self.assertIn("UC", database.species_of_database("custom", "solid", case))
            self.assertEqual(database.species_of_database("custom", "ideal-gas", case), ["Ar"])
        self.assertNotIn("Resin", database.species_of_database("custom", "solid"))

    def test_a_custom_py_that_fails_gives_nothing(self):
        with tempfile.TemporaryDirectory() as case:
            with open(os.path.join(case, "custom.py"), "w") as handle:
                handle.write("raise RuntimeError('no data yet')\n")
            self.assertEqual(database.species_of_database("custom", "solid", case), [])


class BurcatFile(unittest.TestCase):
    """burcat.yaml is searched as GPB searches it: the case directory first, then database/thermo/external and
    database/thermo; the picker lists the species of the file that GPB loads."""

    def test_the_case_directory_comes_first(self):
        with tempfile.TemporaryDirectory() as case:
            path = os.path.join(case, "burcat.yaml")
            with open(path, "w") as handle:
                handle.write("species:\n- name: CASE-ONLY\n")
            self.assertEqual(database.thermo_file("Burcat", case_dir=case), path)
            self.assertEqual(database.species_of_database("Burcat", "ideal-gas", case), ["CASE-ONLY"])
        self.assertNotIn("CASE-ONLY", database.species_of_database("Burcat", "ideal-gas"))


class CanteraMechanisms(unittest.TestCase):
    """GRI-Mech 3.0 is a mechanism of the database that Cantera ships: the pickers list it like the files of
    database/chemistry, and the species of the mechanism are shown."""

    def test_listed_with_the_database(self):
        names, local = database.mechanism_files()
        self.assertIn("gri30", names)
        self.assertIn("aramco30", names)
        self.assertNotIn("gri30", local)

    def test_a_case_directory_file_of_the_same_name_is_not_listed_twice(self):
        with tempfile.TemporaryDirectory() as case:
            open(os.path.join(case, "gri30.yaml"), "w").close()
            names, local = database.mechanism_files(case)
            self.assertIn("gri30", names)
            self.assertEqual(local, [])

    def test_its_species(self):
        if not database._cantera_data_dirs():
            self.skipTest("Cantera's data directory is not found from this Python")
        species = database.species_of_mechanism("gri30")
        self.assertEqual(len(species), 53)
        self.assertIn("CH4", species)


if __name__ == "__main__":
    unittest.main()
