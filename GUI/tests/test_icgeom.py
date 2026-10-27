"""Tests of where the GUI puts the zones of an ICB block on the mesh (icgeom).

usage: python3 -B GUI/tests/test_icgeom.py [-v]

The unit tests need numpy only.  The comparison with ICB writes zone decks
whose ranges leave gaps (and some that cover the block) on a pure 2-D, an
extruded 2-D and a 3-D mesh, along every letter, runs ICB on each and checks
that the GUI finds the cells ICB writes after each zone, the count of cells
no zone writes and the first of them; and, on the nozzle decks of the suite,
the plenum rows ICB reports writing over earlier zones; and that the cells of a
zone a profile table misses (icprofile) are those ICB stops on.  It is skipped
when ICB is not built.  Exit status 77 (skipped) without numpy.
"""

import os
import random
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(_HERE))

try:
    import numpy as np
except ImportError:                     # the GUI needs numpy; its tests say so
    print("numpy is not installed: GUI-icgeom skipped")
    sys.exit(77)

from atlasgui import icgeom, icmodel, mesh_io  # noqa: E402
from atlasgui.document import AtlasDocument  # noqa: E402

ATLAS = icmodel.ATLAS_ROOT
ICB_TESTS = os.path.join(ATLAS, "test", "ICB")
GAS = [os.path.join(ICB_TESTS, "IG-nozzle3D", f) for f in ("gas-phase.txt", "gas-thermo.dat")]
MESHES = {
    "pure 2-D": (os.path.join(ICB_TESTS, "IG-zone-unwritten-refused", "mesh.tec"),
                 ["x", "y", "r", "t", "i", "j", "xy", "rt", "yti"]),
    "extruded": (os.path.join(ICB_TESTS, "IG+DP", "mesh.tec"),
                 ["x", "z", "r", "t", "j", "xr", "ij"]),
    "3-D": (os.path.join(ICB_TESTS, "IG-interp-spherical-3D", "mesh.tec"),
            ["x", "y", "z", "r", "t", "k", "xyz", "ijk"]),
}


class Mesh:
    """A box of nx x ny x nz cells, unit spacing, from (x0, y0, z0)."""

    def __init__(self, nx, ny, nz, origin=(0.0, 0.0, 0.0)):
        x, y, z = np.meshgrid(np.arange(nx + 1) + origin[0], np.arange(ny + 1) + origin[1],
                              np.arange(nz + 1) + origin[2], indexing="ij")
        self.block = mesh_io.MeshBlock(x, y, z)


class Cells(unittest.TestCase):

    def test_centres_and_indices(self):
        cells = icgeom.BlockCells(Mesh(3, 2, 2).block)
        self.assertEqual(cells.shape, (3, 2, 2))
        self.assertEqual(list(cells.coordinate("x")[:, 0, 0]), [0.5, 1.5, 2.5])
        self.assertEqual(int(cells.coordinate("k")[0, 0, 1]), 2)
        self.assertEqual(cells.extent("i"), (1, 3))
        self.assertEqual(cells.extent("x"), (0.0, 3.0))

    def test_axis_of_r_and_t(self):
        # about x on a 3-D mesh: r from y and z
        cells = icgeom.BlockCells(Mesh(1, 1, 1, origin=(5.0, 3.0, 4.0)).block)
        self.assertAlmostEqual(float(cells.coordinate("r")[0, 0, 0]), np.hypot(3.5, 4.5))
        # in the x-y plane on a pure 2-D mesh (one node plane), its cells at z = 0.5
        x, y = np.meshgrid([3.0, 4.0], [4.0, 5.0], indexing="ij")
        flat = icgeom.BlockCells(mesh_io.MeshBlock(x[..., None], y[..., None],
                                                   np.zeros((2, 2, 1))))
        self.assertTrue(flat.pure_2d)
        self.assertAlmostEqual(float(flat.coordinate("r")[0, 0, 0]), np.hypot(3.5, 4.5))
        self.assertEqual(float(flat.coordinate("z")[0, 0, 0]), 0.5)

    def test_ranges(self):
        cells = icgeom.BlockCells(Mesh(4, 1, 1).block)
        self.assertEqual(int(icgeom.range_mask(cells, "x", [0.5, 1.5]).sum()), 2)  # limits included
        self.assertEqual(int(icgeom.range_mask(cells, "i", [1.5, 2.4]).sum()), 1)  # nint(1.5) = 2
        self.assertEqual(icgeom.fortran_nint(-2.5), -3.0)
        self.assertIsNone(icgeom.parse_range("0 1 2", "x"))
        self.assertEqual(icgeom.parse_range("0 1d0", "x"), [0.0, 1.0])

    def test_coverage(self):
        cells = icgeom.BlockCells(Mesh(4, 1, 1).block)
        doc = AtlasDocument.from_ini(
            "[ICB-Block1]\ndirection = x\nzone1 = a\nrange1 = 0 1.6\nzone2 = b\nrange2 = 1 2\n"
            "[a]\np = 1\nT = 1\n[b]\np = 1\nT = 1\n").icb
        cover = icgeom.BlockCoverage(cells, doc.block(1), doc.zones, {"IG"})
        self.assertEqual(cover.unwritten["IG"], (2, (3, 1, 1)))
        self.assertEqual([z.cells for z in cover.zones], [2, 1])
        self.assertEqual([z.kept for z in cover.zones], [1, 1])    # b writes cell 2 again
        self.assertEqual(cover.written_after, [2, 2])

    def test_outward_limits(self):
        for value in (0.12000000000000001, -3.3333333333, 1234567.891, 1e-7 / 3):
            self.assertGreaterEqual(float(icgeom.outward_limit(value, True)), value)
            self.assertLessEqual(float(icgeom.outward_limit(value, False)), value)
        self.assertEqual(icgeom.outward_limit(0.12000000000000001, True), "0.120001")


def _icb_built():
    return os.path.exists(os.path.join(ATLAS, "bin", "ICB"))


@unittest.skipUnless(_icb_built(), "ICB is not built")
class AgainstICB(unittest.TestCase):

    def run_icb(self, directory, deck):
        with open(os.path.join(directory, "input.ini"), "w") as handle:
            handle.write(deck)
        shutil.rmtree(os.path.join(directory, "fromATLAStoSolver"), ignore_errors=True)
        proc = subprocess.run(["bash", "-c", f"cd '{directory}' && '{ATLAS}/ATLAS.sh' ICB < /dev/null"],
                              capture_output=True, text=True,
                              env=dict(os.environ, OMP_NUM_THREADS="1"))
        return proc.returncode, proc.stdout + proc.stderr

    def test_random_zones(self):
        rng = random.Random(2026)
        compared = 0
        with tempfile.TemporaryDirectory() as work:
            for name, (mesh_path, directions) in MESHES.items():
                directory = os.path.join(work, name.replace(" ", ""))
                os.makedirs(directory)
                shutil.copy(mesh_path, os.path.join(directory, "mesh.tec"))
                for f in GAS:
                    shutil.copy(f, directory)
                cells = icgeom.BlockCells(mesh_io.read_mesh(mesh_path)[0])
                for direction in directions:
                    for trial in range(3):
                        lines = ["[ICB-Block1]", f"direction = {direction}"]
                        states = []
                        for n in range(1, rng.choice([1, 2, 3]) + 1):
                            values = []
                            for letter in direction:
                                low, high = cells.extent(letter)
                                if trial == 2 and n == 1:       # the first zone covers it all
                                    a, b = low, high
                                elif letter in "ijk":
                                    a, b = sorted(rng.randint(int(low), int(high)) for _ in range(2))
                                else:
                                    a, b = sorted(round(rng.uniform(low, high), 6) for _ in range(2))
                                values += ([str(int(a)), str(int(b))] if letter in "ijk"
                                           else [repr(float(a)), repr(float(b))])
                            lines += [f"zone{n} = z{n}", f"range{n} = " + " ".join(values)]
                            states.append(f"[z{n}]\np = {1e5 * n}\nT = {300 + 10 * n}")
                        deck = "\n".join(lines) + "\n\n" + "\n\n".join(states) + "\n"
                        rc, out = self.run_icb(directory, deck)
                        doc = AtlasDocument.from_ini(deck).icb
                        cover = icgeom.BlockCoverage(cells, doc.block(1), doc.zones, {"IG"})
                        compared += 1
                        with self.subTest(mesh=name, deck=deck):
                            if rc == 0:
                                self.assertTrue(cover.complete)
                                continue
                            found = re.search(r"(\d+) of \d+ cells are initialised by no zone "
                                              r"\(first cell \((\d+),(\d+),(\d+)\)\)", out)
                            self.assertIsNotNone(found, out[-600:])
                            count = int(found.group(1))
                            first = tuple(int(found.group(i)) for i in (2, 3, 4))
                            self.assertEqual(cover.unwritten.get("IG"), (count, first))
                            after = [int(m) for m in re.findall(
                                r"after \[z\d+\]: gas \(IG\) (\d+) of", out)]
                            self.assertEqual(cover.written_after, after)
        self.assertEqual(compared, 72)

    def test_profile_tables(self):
        """The cells of a zone a T table misses: those ICB stops on."""
        from atlasgui import icprofile
        rng = random.Random(77)
        compared = stopped = 0
        with tempfile.TemporaryDirectory() as work:
            for name, (mesh_path, _directions) in MESHES.items():
                directory = os.path.join(work, name.replace(" ", ""))
                os.makedirs(directory)
                shutil.copy(mesh_path, os.path.join(directory, "mesh.tec"))
                for f in GAS:
                    shutil.copy(f, directory)
                cells = icgeom.BlockCells(mesh_io.read_mesh(mesh_path)[0])
                for letter in ("x", "y", "r", "t"):
                    for trial in range(3):
                        cut_lo, cut_hi = cells.extent("x")
                        cut = round(rng.uniform(cut_lo, cut_hi), 6)
                        low, high = cells.extent(letter)
                        a, b = sorted(round(rng.uniform(low, high), 6) for _ in range(2))
                        if trial == 2:
                            a, b = low - 1.0, high + 1.0          # the whole extent
                        with open(os.path.join(directory, "T.dat"), "w") as handle:
                            handle.write(f"{a!r} 400.0\n{b!r} 500.0\n")
                        deck = (f"[ICB-Block1]\ndirection = x\nzone1 = z1\nrange1 = {cut_lo!r} {cut!r}\n"
                                f"zone2 = z2\nrange2 = {cut!r} {cut_hi!r}\n\n"
                                f"[z1]\np = 1e5\nT-file = T.dat\nT-direction = {letter}\n\n"
                                "[z2]\np = 1e5\nT = 300\n")
                        rc, out = self.run_icb(directory, deck)
                        doc = AtlasDocument.from_ini(deck).icb
                        mask = icgeom.range_mask(cells, "x", [cut_lo, cut])
                        table = icprofile.parse_table(f"{a!r} 400\n{b!r} 500\n")
                        count, first = icprofile.table_outside(cells, mask, letter, table)
                        compared += 1
                        with self.subTest(mesh=name, letter=letter, table=(a, b), cut=cut):
                            found = re.search(r"the centre of cell \((\d+),(\d+),(\d+)\), "
                                              r"\w+ = +\S+, and (\d+) more cells", out)
                            if rc == 0:
                                self.assertEqual(count, 0)
                            else:
                                stopped += 1
                                self.assertIsNotNone(found, out[-500:])
                                self.assertEqual((count, first), (
                                    int(found.group(4)) + 1,
                                    tuple(int(found.group(i)) for i in (1, 2, 3))))
                        self.assertIsNotNone(doc.zones.get("z1"))
        self.assertEqual(compared, 36)
        self.assertGreater(stopped, 12)          # the tables that miss cells are compared too

    def test_nozzle_plenum(self):
        source = os.path.join(ICB_TESTS, "IG-nozzle-plenum-order")
        with tempfile.TemporaryDirectory() as work:
            for f in ("mesh.tec", "phase.txt", "thermo.dat"):
                shutil.copy(os.path.join(source, f), work)
            cells = icgeom.BlockCells(mesh_io.read_mesh(os.path.join(source, "mesh.tec"))[0])
            for deck_name in ("input.ini", "reverse.ini"):
                with open(os.path.join(source, deck_name)) as handle:
                    deck = handle.read()
                rc, out = self.run_icb(work, deck)
                self.assertEqual(rc, 0, out[-400:])
                doc = AtlasDocument.from_ini(deck).icb
                cover = icgeom.BlockCoverage(cells, doc.block(1), doc.zones, {"IG"})
                with self.subTest(deck=deck_name):
                    self.assertTrue(cover.complete)
                    icb = sorted(int(n) for n in re.findall(
                        r"overwrite[s]? (\d+) cells", out))
                    gui = sorted(n for _zone, n, _what in cover.plenum_overwrites)
                    self.assertEqual(gui, icb)


if __name__ == "__main__":
    unittest.main()
