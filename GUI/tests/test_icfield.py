"""Tests of how the GUI reads back the initial field ICB wrote (icfield) and
the colour scales it is shown on (fieldcolors).

usage: python3 -B GUI/tests/test_icfield.py [-v]

The scales need numpy only: one hue for a magnitude, its lightness running
one way (light to dark, dark to light on a dark background); a signed
quantity in two arms of the same lightness step for step about the neutral
grey; a value that is not a number in the colour of no data.  The fields are
the ones ICB writes today: it runs on decks of the suite, in a temporary
directory, and the GUI must find the field files, read them as ASCII Tecplot
and as VTK alike (the VTK one when pyvista is there), put every zone on its
mesh block, and give back what the deck set -- the pressure, the temperature
ICB derived from total conditions, the Mach number under a variable cp, the
mass fractions -- with the gas constant from the phase file and cp from
thermo.dat, as ICB computes them.  Skipped when ICB is not built.
Exit status 77 (skipped) without numpy.
"""

import os
import shutil
import subprocess
import sys
import tempfile
import textwrap
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(_HERE))

try:
    import numpy as np
except ImportError:                     # the GUI needs numpy; its tests say so
    print("numpy is not installed: GUI-icfield skipped")
    sys.exit(77)

from atlasgui import fieldcolors, icfield, runner  # noqa: E402

ATLAS = runner.ATLAS_ROOT
ICB_TESTS = os.path.join(ATLAS, "test", "ICB")
HAS_ICB = os.access(os.path.join(ATLAS, "bin", "ICB"), os.X_OK)
try:
    import pyvista  # noqa: F401
    HAS_PYVISTA = True
except ImportError:
    HAS_PYVISTA = False


class TestScales(unittest.TestCase):

    def test_sequential_one_way(self):
        for dark in (False, True):
            table = fieldcolors.sequential(dark)
            steps = np.diff(fieldcolors.lightness(table))
            # low to high: lighter to darker on a light background, the other way on a dark one
            self.assertTrue(np.all(steps >= -1e-9) if dark else np.all(steps <= 1e-9), dark)
            hue = fieldcolors.to_oklab(table / 255.0)[:, 1:]
            angles = np.degrees(np.arctan2(hue[:, 1], hue[:, 0]))
            self.assertLess(np.ptp(angles), 25.0)              # one hue (blue)

    def test_diverging_arms(self):
        for dark in (False, True):
            table = fieldcolors.diverging(dark)
            light = fieldcolors.lightness(table)
            half = len(table) // 2
            left, right = light[:half][::-1], light[half:]       # each from the middle out
            self.assertLess(np.max(np.abs(left - right)), 0.01, dark)
            out = np.diff(right)
            # the ends away from the grey: darker on a light background, lighter on a dark one
            self.assertTrue(np.all(out >= -1e-9) if dark else np.all(out <= 1e-9), dark)
            grey = fieldcolors.lightness(np.array([fieldcolors.hex_rgb(
                fieldcolors.MIDPOINT[dark])]))[0]
            self.assertAlmostEqual(light[half], grey, delta=0.01)
            ends = fieldcolors.to_oklab(table[[0, -1]] / 255.0)
            self.assertLess(ends[0, 2], 0)                       # blue below zero ...
            self.assertGreater(ends[1, 1], 0)                    # ... red above

    def test_colours(self):
        table = fieldcolors.sequential(False)
        out = fieldcolors.colours([0.0, 5.0, 10.0, np.nan], 0.0, 10.0, table, missing=(1, 2, 3))
        self.assertEqual(out[0].tolist(), table[0].tolist())
        self.assertEqual(out[2].tolist(), table[-1].tolist())
        self.assertEqual(out[3].tolist(), [1, 2, 3])
        signed = fieldcolors.diverging(False)
        out = fieldcolors.colours([-1.0, 0.0, 4.0], -1.0, 4.0, signed, diverging_scale=True)
        self.assertEqual(out[1].tolist(), signed[len(signed) // 2].tolist())  # zero is grey
        self.assertEqual(out[2].tolist(), signed[-1].tolist())
        flat = fieldcolors.colours([7.0, 7.0], 7.0, 7.0, table)          # a uniform field
        self.assertEqual(flat[0].tolist(), table[len(table) // 2].tolist())
        self.assertTrue(fieldcolors.is_signed(-1, 2))
        self.assertFalse(fieldcolors.is_signed(0, 2))


class TestReading(unittest.TestCase):

    def setUp(self):
        self.case = tempfile.mkdtemp(prefix="atlas-field-")
        self.addCleanup(shutil.rmtree, self.case, True)

    def write(self, name, text):
        path = os.path.join(self.case, name)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as handle:
            handle.write(textwrap.dedent(text))
        return path

    def test_files_and_refusals(self):
        self.write("fromATLAStoSolver/gas-ic.tec", "x")
        self.write("fromATLAStoSolver/ic.vtm", "x")
        self.write("fromATLAStoSolver/solid-ic.szplt", "x")
        self.write("fromATLAStoSolver/myic.tec", "x")            # not an ICB name
        self.write("fromATLAStoSolver/bc.txt", "x")
        found = [(f.phase, f.format) for f in icfield.field_files(self.case)]
        self.assertEqual(found, [("gas", "tec"), ("", "vtk"), ("solid", "szplt")])
        with self.assertRaisesRegex(icfield.FieldError, "IC-format = tec or vtk"):
            icfield.read_field(os.path.join(self.case, "fromATLAStoSolver/solid-ic.szplt"))
        nodal = self.write("nodal-ic.tec", """\
            VARIABLES = x y T
            ZONE T = B1-SP, I=2, J=2, K=1, DATAPACKING=BLOCK
            0 1 0 1 0 0 1 1 300 300 300 300
            """)
        with self.assertRaisesRegex(icfield.FieldError, "nodal"):
            icfield.read_field(nodal)

    def test_small_tec(self):
        path = self.write("drop-ic.tec", """\
            VARIABLES = x y "T" "matID"
            ZONE  T = B2-SP, I=3, J=2, K=1, DATAPACKING=BLOCK, VARLOCATION=([1-2]=NODAL,[3-4]=CELLCENTERED)
            0 1 2 0 1 2
            0 0 0 1 1 1
            300 310
            1 2
            """)
        field = icfield.derive(icfield.read_field(path), self.case)
        self.assertEqual((field.phase, field.kind, list(field.blocks)), ("drop", "SP", [2]))
        self.assertEqual(field.blocks[2].shape, (2, 1, 1))
        self.assertEqual(field.names, ["T", "matID"])
        self.assertEqual(icfield.value_range(field, "T"), (300.0, 310.0))
        fits, issues = icfield.fit_issues(field, [(4, 4, 1), (2, 1, 1)])
        self.assertEqual((fits, issues), ({2}, []))
        fits, issues = icfield.fit_issues(field, [(2, 1, 1), (3, 1, 1)])
        self.assertEqual(fits, set())
        self.assertIn("2×1×1 cells in the field, 3×1×1 in the mesh", issues[0])
        self.assertIn("block 2", icfield.fit_issues(field, [(2, 1, 1)])[1][0])


@unittest.skipUnless(HAS_ICB, "ICB is not built")
class TestIcbFields(unittest.TestCase):
    """The fields ICB writes, read back."""

    def run_icb(self, files, deck, source=None):
        case = tempfile.mkdtemp(prefix="atlas-field-")
        self.addCleanup(shutil.rmtree, case, True)
        for name in files:
            shutil.copy(os.path.join(source, name), case)
        with open(os.path.join(case, "input.ini"), "w") as handle:
            handle.write(textwrap.dedent(deck))
        done = subprocess.run(["bash", runner.launcher(ATLAS), "ICB"], cwd=case,
                              capture_output=True, text=True, env=runner.environment(ATLAS),
                              timeout=120)
        self.assertEqual(done.returncode, 0, done.stdout[-2000:])
        return case

    def fields(self, case):
        return {f.phase: icfield.derive(icfield.read_field(f.path), case)
                for f in icfield.field_files(case)}

    def assertUniform(self, field, name, value, places=7):
        low, high = icfield.value_range(field, name)
        self.assertAlmostEqual(low / value, 1.0, places=places, msg=name)
        self.assertAlmostEqual(high / value, 1.0, places=places, msg=name)

    def test_species_mach_and_formats(self):
        source = os.path.join(ICB_TESTS, "ICB-type-refused")    # H2, O2, N2; a pure 2-D mesh
        deck = """\
            [ATLAS-Parameters]
            IC-format = {fmt}

            [ICB-Block1]
            p = 2e5
            T = 400
            mach = 0.5
            yO2 = 0.25
            yN2 = 0.75
            """
        case = self.run_icb(["mesh.tec", "phase.txt", "thermo.dat"], deck.format(fmt="tec"), source)
        field = self.fields(case)[""]
        self.assertEqual((field.kind, list(field.blocks), field.blocks[1].shape), ("IG", [1], (8, 4, 1)))
        self.assertEqual(field.names[:5], ["p", "T", "Mach", "speed", "rho"])
        self.assertIn("Y_O2", field.names)
        self.assertNotIn("w", field.names)                       # a pure 2-D mesh
        self.assertUniform(field, "p", 2e5)
        self.assertUniform(field, "T", 400.0)
        self.assertUniform(field, "Mach", 0.5)
        self.assertUniform(field, "Y_O2", 0.25)
        self.assertLess(icfield.value_range(field, "Y_H2")[1], 1e-12)   # ICB's floor, 1e-20
        self.assertEqual(field.notes, [])
        if not HAS_PYVISTA:
            return
        vtk = self.run_icb(["mesh.tec", "phase.txt", "thermo.dat"], deck.format(fmt="vtk"), source)
        other = self.fields(vtk)[""]
        self.assertEqual(other.names, field.names)
        for name in field.names:
            np.testing.assert_allclose(other.values(1, name), field.values(1, name), rtol=1e-12)

    def test_total_conditions_and_a_solid(self):
        # IG+SP: the gas of block 1 from p0, T0 and mach = 2.8 (T comes from ICB's
        # expansion under the cp of gas-thermo.dat), a solid in block 2
        source = os.path.join(ICB_TESTS, "IG+SP")
        with open(os.path.join(source, "input.ini")) as handle:
            deck = handle.read()
        case = self.run_icb(["mesh.tec", "gas-phase.txt", "gas-thermo.dat", "solid-phase.txt"],
                            deck, source)
        fields = self.fields(case)
        gas, solid = fields["gas"], fields["solid"]
        self.assertEqual((list(gas.blocks), list(solid.blocks)), ([1], [2]))
        self.assertUniform(gas, "Mach", 2.8)
        temperature = icfield.value_range(gas, "T")[0]
        self.assertTrue(300 < temperature < 3800, temperature)   # expanded from T0
        self.assertEqual((solid.kind, solid.names), ("SP", ["T", "matID"]))
        self.assertUniform(solid, "T", 313.0)
        # without thermo.dat the Mach number cannot be had, and the field says so
        os.remove(os.path.join(case, "gas-thermo.dat"))
        bare = self.fields(case)["gas"]
        self.assertNotIn("Mach", bare.names)
        self.assertIn("T", bare.names)
        self.assertTrue(any("gas-thermo.dat" in note for note in bare.notes), bare.notes)


if __name__ == "__main__":
    unittest.main()
