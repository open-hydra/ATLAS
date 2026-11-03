"""Tests of how the GUI reads back what GPB and BCB wrote (tables, bcfile),
the scales of its plots (plotview) and the cases it remembers (preferences).

usage: python3 -B GUI/tests/test_outputs.py [-v]

The tables: ASCII Tecplot as GPB writes them -- the 1-D zones of a gas, a
condensed or a solid phase (F=POINT), the (p, h) grid of a real fluid
(DATAPACKING=BLOCK, p fastest, and the POINT form of older files) -- read
into arrays the shape of their zones, the thermodynamics and the transport of
a gas drawn as one sheet, the reactions named from chemistry-info.txt, an
infinite rate (1e300) left out.  The boundary files: the BC id of every cell
of every face of every block, in arrays the shape of the face's cells (m
fastest, as BCB counts them), whatever the payload lines in between --
connections, chimera donors, inlet values, the repeated tables of a dispersed
phase --; the blocks of a phase placed on the mesh by the deck, or by size;
a multigrid level drawn on the cells of the mesh.  Then the tools: GPB writes
the cp Cantera has for O2 (when this Python has Cantera), and BCB on a deck
of the suite writes, face by face, the BC id the deck's section implies.
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
    print("numpy is not installed: GUI-outputs skipped")
    sys.exit(77)

from atlasgui import bcfile, runner, tables  # noqa: E402

try:
    from atlasgui import plotview  # noqa: E402
except ImportError:                     # no PyQt6: the plot scales are not tested
    plotview = None

ATLAS = runner.ATLAS_ROOT
BCB_TESTS = os.path.join(ATLAS, "test", "BCB")
HAS = {t: os.access(os.path.join(ATLAS, "bin", t), os.X_OK) for t in ("BCB", "ICB")}


class Case(unittest.TestCase):

    def setUp(self):
        self.case = tempfile.mkdtemp(prefix="atlas-outputs-")
        self.addCleanup(shutil.rmtree, self.case, True)

    def write(self, name, text, dedent=True):
        path = os.path.join(self.case, name)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as handle:
            handle.write(textwrap.dedent(text) if dedent else text)
        return path


# ------------------------------------------------------------------ tables
class TestTables(Case):

    def gas(self):
        out = "fromATLAStoSolver/"
        self.write(out + "gas-phase.txt", "ideal-gas phase\nO2 31.998\nH2 2.016\n")
        rows = lambda f: "".join(f"{t}.0 {f(t):.6f} 1.0 2.0 0.0\n" for t in range(300, 304))
        self.write(out + "gas-thermo.dat", 'TITLE = "Mass Thermodynamic Properties"\n'
                   'VARIABLES = "Temperature", "Cp", "Enthalpy", "Entropy", "dCp"\n'
                   'ZONE T="O2"\nI=4, F=POINT\n' + rows(lambda t: 900 + t / 100)
                   + 'ZONE T="H2"\nI=4, F=POINT\n' + rows(lambda t: 14000 + t), dedent=False)
        self.write(out + "gas-transport.dat", 'TITLE = "Transport Properties"\n'
                   'VARIABLES = "Temperature", "Viscosity", "Conductivity"\n'
                   + "".join(f'ZONE T="{s}"\nI=4, F=POINT\n'
                             + "".join(f"{t}.0 0.00002 0.03 \n" for t in range(300, 304))
                             for s in ("O2", "H2")), dedent=False)
        self.write(out + "gas-chemistry-Arrhenius.dat", 'TITLE = "Arrhenius data"\n'
                   'VARIABLES = "Temperature", "kf", "kb"\n'
                   'ZONE T="Reaction 1"\nI=2, F=POINT\n   300.000   1.0E+300   0.0E+00\n'
                   '   301.000   2.0E+05   0.0E+00\n'
                   'ZONE T="Reaction 2"\nI=2, F=POINT\n   300.000   1.0E+03   5.0E+01\n'
                   '   301.000   2.0E+03   6.0E+01\n', dedent=False)
        self.write(out + "gas-chemistry-info.txt", """\
            mech
            N.ro species = 2
            N.ro reactions = 3

            Reaction type
            1 Arrhenius
            2 falloff-Troe
            3 three-body-Arrhenius

            Reaction definition
            1 O2 0.5 0.0 0.0
            1 H2 1.0 0.0 0.0
            1 M 0.0 0.0 0.0
            2 O2 1.0 0.0 0.0
            2 H2 0.0 1.0 0.0
            2 M 1.0 1.0 0.0
            3 H2 1.0 0.0 0.0
            3 O2 0.0 2.0 0.0
            3 M 1.0 1.0 0.0
            """)

    def test_gas_sheets(self):
        self.gas()
        phases = tables.phase_outputs(self.case)
        self.assertEqual([(p.name, p.family, p.members) for p in phases],
                         [("gas", "gas", ["O2", "H2"])])
        gas = phases[0]
        self.assertEqual([k for k, _l in tables.sheets(gas)], ["thermo", "arrhenius"])
        sheet = tables.load_sheet(gas, "thermo")
        # the thermodynamics and the transport of the gas, one sheet
        self.assertEqual(sheet.quantities, ["Cp", "Enthalpy", "Entropy", "dCp", "Viscosity",
                                            "Conductivity"])
        self.assertEqual(sheet.series, [("O2", "O2"), ("H2", "H2")])
        np.testing.assert_allclose(sheet.values("H2", "Cp"), [14300, 14301, 14302, 14303])
        np.testing.assert_allclose(sheet.values("O2", "Viscosity"), 2e-5)
        rates = tables.load_sheet(gas, "arrhenius")
        self.assertTrue(rates.log)
        # zone n of the Arrhenius table is the n-th reaction that is not a fall-off
        self.assertEqual([label for _z, label in rates.series],
                         ["R1 · 0.5 O2 + H2 →", "R3 · H2 + M ⇌ 2 O2 + M"])
        self.assertTrue(np.isnan(rates.values("Reaction 1", "kf")[0]))     # 1e300
        self.assertEqual(rates.values("Reaction 1", "kf")[1], 2e5)
        reactions = tables.read_reactions(gas.files["reactions"])
        self.assertEqual(reactions[1], ("falloff-Troe", "O2 (+M) → H2 (+M)"))

    def test_real_fluid_grid(self):
        # 3 pressures (I, fastest) by 2 enthalpies (J), as GPB writes them
        p, h = [1e6, 2e6, 3e6], [0.0, 5e4]
        rows = [(pi, hj, 10 * i + j, 300 + 10 * i + 50 * j) for j, hj in enumerate(h)
                for i, pi in enumerate(p)]
        block = "".join(f"{row[c]}\n" for c in range(4) for row in rows)
        self.write("fromATLAStoSolver/co2-phase.txt", "real-fluid phase\nCO2\n")
        self.write("fromATLAStoSolver/co2-thermo.dat", 'TITLE = "x"\nVARIABLES = "Pressure", '
                   '"Enthalpy", "Density", "Temperature"\nZONE T=real-gas, I=3, J=2, K=1, '
                   'DATAPACKING=BLOCK, VARLOCATION=([1-4]=NODAL)\n' + block, dedent=False)
        # the transport table in the POINT form of older files
        point = "".join(f"{pi} {hj} {1e-5 * (i + 1)} 0.1\n" for j, hj in enumerate(h)
                        for i, pi in enumerate(p))
        self.write("fromATLAStoSolver/co2-transport.dat", 'VARIABLES = "Pressure", "Enthalpy", '
                   '"Viscosity", "Conductivity"\nZONE T=real-gas, I=3, J=2, K=1\n' + point,
                   dedent=False)
        fluid = tables.phase_outputs(self.case)[0]
        self.assertEqual(fluid.family, "real-fluid")
        self.assertEqual(tables.sheets(fluid), [("grid", "Property grid")])
        sheet = tables.load_sheet(fluid, "grid")
        self.assertEqual(sheet.form, "map")
        self.assertEqual(sheet.quantities[0], "Temperature")
        np.testing.assert_allclose(tables.axis(sheet, "Pressure"), p)
        np.testing.assert_allclose(tables.axis(sheet, "Enthalpy"), h)
        density = sheet.values("grid", "Density")
        self.assertEqual(density.shape, (3, 2))
        self.assertEqual((density[2, 0], density[1, 1]), (20, 11))
        np.testing.assert_allclose(sheet.values("grid", "Viscosity")[:, 1], [1e-5, 2e-5, 3e-5])

    def test_discovery(self):
        self.write("fromATLAStoSolver/phase.txt", "solid-bulk\nUC 1\n")
        self.write("fromATLAStoSolver/myphase.txt", "solid-bulk\nUC 1\n")      # not a GPB name
        self.write("drops-phase.txt", "condensed-dispersed\nAL2O3(L) 2\n")    # given by hand
        self.write("phase.txt", "ideal-gas phase\nN2 28\n")                  # GPB's comes first
        found = [(p.name, p.family, os.path.basename(p.directory)) for p in
                 tables.phase_outputs(self.case)]
        self.assertEqual(found, [("", "solid", "fromATLAStoSolver"),
                                 ("drops", "condensed", os.path.basename(self.case))])
        with self.assertRaisesRegex(tables.TableError, "values for"):
            tables.read_table(self.write("bad.dat", 'VARIABLES = "T", "Cp"\nZONE T="x"\n'
                                         'I=3, F=POINT\n1 2\n3 4\n'))


# ---------------------------------------------------------- boundary files
def record(block, i, j, k, face, bc_id):
    return f"{block:8d}{i:8d}{j:8d}{k:8d}{face:8d}{bc_id:8d}\n"


class TestBoundaryFiles(Case):

    def block_file(self, payload=lambda f, m, n: "", copies=1, nx=3, ny=2, nz=1, block=1):
        """The records of one block of nx × ny × nz cells, BCB's order."""
        text = ""
        for _copy in range(copies):
            for face in range(1, 7):
                mend, nend = {1: (ny, nz), 2: (ny, nz), 3: (nx, nz), 4: (nx, nz),
                              5: (nx, ny), 6: (nx, ny)}[face]
                for n in range(1, nend + 1):
                    for m in range(1, mend + 1):
                        i, j, k = {1: (1, m, n), 2: (nx, m, n), 3: (m, 1, n), 4: (m, ny, n),
                                   5: (m, n, 1), 6: (m, n, nz)}[face]
                        bc_id, lines = payload(face, m, n)
                        text += record(block, i, j, k, face, bc_id) + lines
        return text

    def test_records(self):
        def payload(face, m, n):
            if face == 1:
                return 101, f"{2:8d}{4:8d}{m:8d}{n:8d}{2:8d}{1:8d}{0:8d}{0:8d}{1:8d}\n"
            if face == 2:
                return 102, ("       1       1\n       2       1       1       1  1.0E+00\n"
                             "       2       2       1       1  1.0E+00\n")
            if face == 4 and m == 2:
                return 404, ("  3.0E+02,  1.2E+02,  normal,  normal,  1.0E+00,  1.0E-20,"
                             "  1.0E+00,  1.0E-06,\n")
            return (302, "  6.0E+02,  0.0E+00,  0.0E+00,\n") if face == 4 else (300, "")
        self.write("fromATLAStoSolver/gas-phase.txt", "ideal-gas phase\nO2 32\nN2 28\n")
        path = self.write("fromATLAStoSolver/gas-bc.txt", self.block_file(payload), dedent=False)
        result = bcfile.read_bc(path)
        self.assertEqual((result.phase, result.level, result.ndim, result.family),
                         ("gas", 1, 3, "gas"))
        part = result.blocks[1]
        self.assertEqual((part.dims, part.copies), ((3, 2, 1), 1))
        self.assertEqual(part.faces[1].ids.shape, (2, 1))           # j, k
        self.assertEqual(part.faces[4].ids[:, 0].tolist(), [302, 404, 302])
        self.assertEqual(result.counts(), {101: 2, 102: 2, 300: 15, 302: 2, 404: 1})
        lines = result.record(1, 4, 1, 0)
        self.assertEqual(len(lines), 2)
        self.assertEqual(bcfile.decode(result, 404, lines[1:]),
                         [("T", "300"), ("g", "120"), ("alpha", "normal"), ("beta", "normal"),
                          ("rf", "1"), ("Y(N2)", "1"), ("turbulence", "1e-06")])
        self.assertEqual(bcfile.decode(result, 101, result.record(1, 1, 1, 0)[1:])[:2],
                         [("to block", "2"), ("cell", "(4, 2, 1)")])
        self.assertEqual(len(result.record(1, 2, 0, 0)), 4)          # the chimera donors
        self.assertEqual(bcfile.describe_id(302)[0], "wall, temperature")
        self.assertEqual(bcfile.describe_id(401, "condensed")[1][0], "krho")

    def test_dispersed_copies(self):
        # the table of a dispersed phase, once per material and population
        text = "".join(self.block_file(lambda f, m, n, g=g: (402, f" {g} 2.0 0 0 300 1e-5 0 "
                                                             "Dirac 0\n") if f == 1
                                       else (300, "")) for g in ("1.0", "7.0"))
        result = bcfile.read_bc(self.write("fromATLAStoSolver/drop-bc.txt", text, dedent=False))
        self.assertEqual(result.blocks[1].copies, 2)
        self.assertEqual(result.counts()[402], 2)                    # one copy counted
        first, second = result.record(1, 1, 1, 0), result.record(1, 1, 1, 0, copy=1)
        self.assertEqual(second[0], first[0])
        self.assertEqual((first[1].split()[0], second[1].split()[0]), ("1.0", "7.0"))

    def test_blocks_and_levels(self):
        # two blocks of the phase: 4×2×1 and 2×2×1 cells
        text = self.block_file(lambda f, m, n: (300, ""), nx=4, ny=2) + \
            self.block_file(lambda f, m, n: (406, " 1e5, 1,\n"), nx=2, ny=2, block=2)
        result = bcfile.read_bc(self.write("solid-bc.txt", text, dedent=False))
        mesh = [(8, 8, 1), (4, 2, 1), (5, 5, 1), (2, 2, 1)]
        mapping, how, issues = bcfile.block_map(result, mesh)
        self.assertEqual((mapping, issues), ({1: 2, 2: 4}, []))
        self.assertIn("by size", how)
        mapping, how, issues = bcfile.block_map(result, mesh, phase_blocks=[1, 4])
        self.assertEqual(mapping, {2: 4})                            # block 1 does not fit 1
        self.assertIn("block 1 of the file (4×2×1 cells) is not mesh block 1", issues[0])
        # multigrid level 2: the file's blocks are the mesh's halved
        coarse = bcfile.read_bc(self.write("gas-bc2.txt", text, dedent=False))
        self.assertEqual(coarse.level, 2)
        mapping, _how, issues = bcfile.block_map(coarse, [(8, 4, 1), (4, 4, 1)])
        self.assertEqual((mapping, issues), ({1: 1, 2: 2}, []))
        ids, _ = bcfile.fine_ids(coarse.blocks[2].faces[3], (4, 1), 2)
        self.assertEqual(ids.tolist(), [[406]] * 4)
        with self.assertRaisesRegex(bcfile.BCFileError, "not a record"):
            bcfile.read_bc(self.write("x-bc.txt", "hello\n"))


# ------------------------------------------------------------------ plots
@unittest.skipIf(plotview is None, "PyQt6 is not installed")
class TestPlotScales(unittest.TestCase):

    def test_ticks(self):
        self.assertEqual(plotview.nice_ticks(0, 5000, 6)[0], [0, 1000, 2000, 3000, 4000, 5000])
        values, labels, power = plotview.Scale(8e6, 1.5e7).ticks()
        self.assertEqual((labels, power), (["8", "10", "12", "14"], 6))
        self.assertEqual(plotview.axis_title("p · pressure", "Pa", power), "p · pressure [10⁶ Pa]")
        _v, labels, power = plotview.Scale(1.2e-5, 8.5e-5).ticks()
        self.assertEqual((labels[0], power), ("20", -6))
        _v, labels, _p = plotview.Scale(1e-9, 1e-3, log=True).ticks()
        self.assertEqual((labels[0], labels[-1]), ("10⁻⁹", "10⁻³"))

    def test_contours(self):
        x = np.linspace(-2, 2, 41)
        X, Y = np.meshgrid(x, x, indexing="ij")
        segments = plotview.contour_segments(X ** 2 + Y ** 2, 1.0)
        radius = np.hypot(np.interp(segments[..., 0], np.arange(41), x),
                          np.interp(segments[..., 1], np.arange(41), x))
        self.assertGreater(len(segments), 60)
        self.assertLess(np.max(np.abs(radius - 1.0)), 0.01)
        self.assertEqual(len(plotview.contour_segments(X, 5.0)), 0)    # out of range


# ----------------------------------------------------------- recent cases
class TestRecentCases(Case):

    def test_list(self):
        try:
            from PyQt6.QtCore import QSettings
        except ImportError:
            self.skipTest("PyQt6 is not installed")
        from atlasgui import preferences
        store = QSettings(os.path.join(self.case, "settings.ini"), QSettings.Format.IniFormat)
        paths = [self.write(f"c{n}/input.ini", "") for n in range(10)]
        for path in paths:
            preferences.add_recent_case(path, store)
        preferences.add_recent_case(paths[3], store)                 # again: to the top
        recent = preferences.recent_cases(store)
        self.assertEqual(len(recent), preferences.RECENT_CASES)
        self.assertEqual(recent[:2], [paths[3], paths[9]])
        os.remove(paths[9])                                          # gone: not offered
        self.assertNotIn(paths[9], preferences.recent_cases(store))
        preferences.clear_recent_cases(store)
        self.assertEqual(preferences.recent_cases(store), [])


# -------------------------------------------------------------- the tools
class TestTools(Case):

    @unittest.skipUnless(runner.has_cantera(sys.executable), "this Python has no Cantera for GPB")
    def test_gpb_tables(self):
        self.write("input.ini", """\
            [GPB-Phase1]
            name = gas
            species = O2 CH4
            thermo = NASA9
            transport = cantera
            Tmax = 1500
            """)
        done = subprocess.run(["bash", runner.launcher(ATLAS), "GPB"], cwd=self.case,
                              capture_output=True, text=True, timeout=300,
                              env=runner.environment(ATLAS, sys.executable))
        self.assertEqual(done.returncode, 0, done.stdout[-2000:])
        gas = tables.phase_outputs(self.case)[0]
        sheet = tables.load_sheet(gas, "thermo")
        self.assertEqual(sorted(z for z, _l in sheet.series), ["CH4", "O2"])
        import cantera as ct
        oxygen = ct.Solution("gri30.yaml")
        oxygen.TPX = 1000.0, ct.one_atm, "O2:1"
        T = sheet.values("O2", "Temperature")
        cp = float(np.interp(1000.0, T, sheet.values("O2", "Cp")))
        self.assertAlmostEqual(cp / oxygen.cp_mass, 1.0, delta=0.01)
        self.assertIn("Viscosity", sheet.quantities)

    @unittest.skipUnless(HAS["BCB"], "BCB is not built")
    def test_bcb_faces(self):
        source = os.path.join(BCB_TESTS, "IG-basic")
        for name in ("mesh.tec", "phase.txt", "input.ini"):
            shutil.copy(os.path.join(source, name), self.case)
        done = subprocess.run(["bash", runner.launcher(ATLAS), "BCB"], cwd=self.case,
                              capture_output=True, text=True, timeout=300,
                              env=runner.environment(ATLAS))
        self.assertEqual(done.returncode, 0, done.stdout[-2000:])
        files = bcfile.bc_files(self.case)
        self.assertEqual([(f.phase, f.level) for f in files], [("", 1)])
        result = bcfile.read_bc(files[0].path)
        from atlasgui import mesh_io
        from atlasgui.document import AtlasDocument
        with open(os.path.join(self.case, "input.ini")) as handle:
            doc = AtlasDocument.from_ini(handle.read())
        mesh = mesh_io.read_mesh(os.path.join(self.case, "mesh.tec"))
        dims = [(b.ni - 1, b.nj - 1, b.nk - 1) for b in mesh]
        mapping, how, issues = bcfile.block_map(result, dims, list(range(1, len(mesh) + 1)))
        self.assertEqual((mapping, issues), ({1: 1, 2: 2, 3: 3}, []))
        # the id every face of the deck takes, from what its section sets --
        # but where another block meets the face: BCB connects the two there
        expected = {"adiabatic": 301, "isoth": 302, "out": 406, "injOX": 404, "injCH4": 404,
                    "symmetry": 300, "connection": 101}
        joined = 0
        for b in range(len(mesh)):
            for face in range(1, 5):
                section = doc.bcb.face_value(b, face)
                ids = result.blocks[b + 1].faces[face].ids
                found = set(ids.ravel().tolist())
                self.assertIn(expected[section], found, f"block {b + 1} face {face}")
                self.assertLessEqual(found, {expected[section], 101})
                if section != "connection":
                    joined += int((ids == 101).sum())
        # block 1's face 1 meets the connection faces of the two injector blocks
        self.assertEqual(joined, sum(result.blocks[b].faces[2].ids.size for b in (2, 3)))
        lines = result.record(3, 1, 0, 0)                            # injCH4
        values = dict(bcfile.decode(result, 404, lines[1:]))
        self.assertEqual((values["T"], values["g"], values["Y(CH4)"]), ("269", "1983.448", "1"))


if __name__ == "__main__":
    unittest.main()
