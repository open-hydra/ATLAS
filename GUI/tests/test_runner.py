"""Tests of how the GUI runs the tools (runner).

usage: python3 -B GUI/tests/test_runner.py [-v]

The checks before a run need the standard library only: the mesh BCB and
ICB read and the link the run makes to the mesh on the screen, the phase
files they read and the hand-off of GPB's tables, a filelist.txt kept as it
is, a tool not built, the GUI's own errors in the stage of a tool, what each
tool has to build, and the environment of the tools.  The runs need PyQt6
(QtCore): a chain stops at the tool that fails and skips the others; Stop
ends the tool a launcher started, not only the launcher, and removes the
filelist.txt the launcher made; the hand-off copies GPB's phase tables (and
only them) before BCB, after the mesh is linked; ICB runs through ATLAS.sh on
a deck of the suite and writes what ATLAS ICB typed in a shell writes
(skipped when ICB is not built) and, when this Python has
Cantera, GPB and ICB run as a chain, ICB reading the phase GPB has just built.
"""

import os
import shutil
import stat
import subprocess
import sys
import tempfile
import textwrap
import time
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(_HERE))

from atlasgui import runner  # noqa: E402
from atlasgui.document import AtlasDocument  # noqa: E402

ATLAS = runner.ATLAS_ROOT
SP_BASIC = os.path.join(ATLAS, "test", "ICB", "SP-basic")
IG_2D = os.path.join(ATLAS, "test", "ICB", "IG-2D")

try:
    from PyQt6.QtCore import QCoreApplication, QEventLoop, QTimer
    APP = QCoreApplication.instance() or QCoreApplication([])
except ImportError:                     # the runs need Qt; the checks do not
    APP = None


def doc_of(text):
    return AtlasDocument.from_ini(textwrap.dedent(text))


GAS_AND_DROP = """
    [GPB-Phase1]
    name = gas
    mixture-name = air
    mixture = {N2: 75.4} {O2: 23.3} {Ar: 1.3}

    [GPB-Phase2]
    name = drop
    type = condensed-dispersed

    [BCB-Block1]
    face1 = wall
    face2 = wall
    face3 = wall
    face4 = wall

    [wall]
    type = wall

    [ICB-Block*]
    p = 1e5
    T = 300
"""


class CaseDir(unittest.TestCase):
    """A fresh case directory per test."""

    def setUp(self):
        self.case = tempfile.mkdtemp(prefix="atlas-run-")
        self.addCleanup(shutil.rmtree, self.case, True)

    def touch(self, *names, text="x"):
        for name in names:
            path = os.path.join(self.case, name)
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w") as handle:
                handle.write(text)


class TestFiles(CaseDir):

    def test_line_level(self):
        self.assertEqual(runner.line_level("[ERROR] key g of section [in]: no"), "error")
        self.assertEqual(runner.line_level(" [WARNING] mesh.p3d is read"), "warning")
        self.assertEqual(runner.line_level("ERROR: ATLASDIR is not set."), "error")
        self.assertEqual(runner.line_level("Traceback (most recent call last):"), "error")
        self.assertIsNone(runner.line_level("  - Writing tec-fomat file"))
        self.assertIsNone(runner.line_level("  errors: none"))

    def test_written(self):
        out = os.path.join(self.case, "out")
        self.touch("out/a.txt", "out/b.txt")
        before = runner.snapshot(out)
        time.sleep(0.01)
        self.touch("out/b.txt", text="changed")
        self.touch("out/c.txt")
        self.assertEqual(runner.written(before, runner.snapshot(out)), ["b.txt", "c.txt"])
        self.assertEqual(runner.snapshot(os.path.join(self.case, "none")), {})

    def test_ini_argument(self):
        ini = os.path.join(self.case, "input.ini")
        self.assertEqual(runner.ini_argument(ini, self.case), "input.ini")
        elsewhere = os.path.join(tempfile.gettempdir(), "deck.ini")
        self.assertEqual(runner.ini_argument(elsewhere, self.case), elsewhere)
        self.assertEqual(runner.command_line("BCB", "input.ini"), "ATLAS BCB --input input.ini")


class TestMeshPlan(CaseDir):

    def test_no_mesh(self):
        plan = runner.mesh_plan(self.case)
        self.assertEqual(plan.level, "error")
        self.assertIn("load one", plan.text)

    def test_default_mesh_read(self):
        self.touch("mesh.p3d")
        plan = runner.mesh_plan(self.case)
        self.assertEqual((plan.level, os.path.basename(plan.reads)), ("ok", "mesh.p3d"))

    def test_loaded_mesh_linked(self):
        self.touch("chamber.p3d")
        loaded = os.path.join(self.case, "chamber.p3d")
        plan = runner.mesh_plan(self.case, loaded)
        self.assertEqual((plan.level, plan.link), ("action", "mesh.p3d"))
        what = runner.link_mesh(self.case, plan.link, loaded)
        self.assertIn("mesh.p3d", what)
        again = runner.mesh_plan(self.case, loaded)
        self.assertEqual(again.level, "ok")       # the tools now read the loaded file

    def test_tecplot_extensions(self):
        for ext, link in ((".dat", "mesh.tec"), (".plt", "mesh.tec"), (".xyz", "mesh.p3d"),
                          (".g", "mesh.p3d"), (".szplt", "mesh.szplt")):
            self.touch("grid" + ext)
            plan = runner.mesh_plan(self.case, os.path.join(self.case, "grid" + ext))
            self.assertEqual(plan.link, link, ext)

    def test_other_default_mesh_first(self):
        # mesh.tec is read before mesh.p3d: it hides the mesh on the screen
        self.touch("mesh.tec", "chamber.p3d")
        plan = runner.mesh_plan(self.case, os.path.join(self.case, "chamber.p3d"))
        self.assertEqual(plan.level, "warning")
        self.assertIn("mesh.tec", plan.text)
        self.assertEqual(plan.link, "")

    def test_format_not_read(self):
        self.touch("grid.cgns")
        plan = runner.mesh_plan(self.case, os.path.join(self.case, "grid.cgns"))
        self.assertEqual(plan.level, "error")


class TestPreflight(CaseDir):

    def checks(self, doc, selected, **kw):
        kw.setdefault("ini_path", os.path.join(self.case, "input.ini"))
        kw.setdefault("python", sys.executable)
        kw.setdefault("python_how", "test")
        kw.setdefault("root", ATLAS)
        return runner.preflight(doc, self.case, selected, **kw)

    def texts(self, checks, level):
        return [c.text for c in checks if c.level == level]

    def test_handoff_names_the_tables(self):
        self.touch("mesh.tec")
        checks = self.checks(doc_of(GAS_AND_DROP), ["GPB", "BCB", "ICB"])
        action = " ".join(self.texts(checks, "action"))
        self.assertIn("drop-phase.txt, gas-phase.txt", action)
        self.assertIn("BCB and ICB read them", action)

    def test_no_handoff_warns(self):
        self.touch("mesh.tec")
        checks = self.checks(doc_of(GAS_AND_DROP), ["GPB", "ICB"], handoff=False)
        self.assertTrue(any("not those GPB writes" in t and "one ideal gas" in t
                            for t in self.texts(checks, "warning")))

    def test_stale_phase_file(self):
        self.touch("mesh.tec", "gas-phase.txt", "old-phase.txt")
        checks = self.checks(doc_of(GAS_AND_DROP), ["BCB"])
        warnings = " ".join(self.texts(checks, "warning"))
        self.assertIn("old-phase.txt, which no phase of the deck writes", warnings)
        self.assertNotIn("gas-phase.txt, which", warnings)

    def test_no_phase_file_without_gpb(self):
        self.touch("mesh.tec")
        checks = self.checks(doc_of(GAS_AND_DROP), ["ICB"])
        self.assertTrue(any("assume one ideal gas" in t and "run GPB" in t
                            for t in self.texts(checks, "warning")))

    def test_phase_file_older_than_gpb(self):
        self.touch("mesh.tec", "gas-phase.txt")
        old = time.time() - 3600
        os.utime(os.path.join(self.case, "gas-phase.txt"), (old, old))
        self.touch(f"{runner.OUTPUT_DIR}/gas-phase.txt")
        checks = self.checks(doc_of(GAS_AND_DROP), ["ICB"])
        self.assertTrue(any("older than the one GPB wrote" in t
                            for t in self.texts(checks, "warning")))

    def test_filelist_kept(self):
        self.touch("mesh.tec", "gas-phase.txt")
        self.touch("filelist.txt", text="gas-phase.txt\n")
        checks = self.checks(doc_of(GAS_AND_DROP), ["BCB"])
        self.assertTrue(any("filelist.txt" in t and "(gas-phase.txt)" in t
                            for t in self.texts(checks, "warning")))

    def test_tools_not_built(self):
        root = os.path.join(self.case, "atlas")
        os.makedirs(os.path.join(root, "bin"))
        self.touch("atlas/ATLAS.sh", "mesh.tec")
        exe = os.path.join(root, "bin", "BCB")
        self.touch("atlas/bin/BCB")
        os.chmod(exe, os.stat(exe).st_mode | stat.S_IXUSR)
        checks = self.checks(doc_of(GAS_AND_DROP), ["BCB", "ICB"], root=root)
        errors = [(c.tool, c.text) for c in checks if c.level == "error"]
        self.assertEqual([t for t, _ in errors], ["ICB"])
        nowhere = self.checks(doc_of(GAS_AND_DROP), ["ICB"], root=self.case)
        self.assertTrue(any("no ATLAS.sh" in t for t in self.texts(nowhere, "error")))

    def test_python_without_cantera(self):
        if runner.has_cantera(sys.executable):
            fake = os.path.join(self.case, "python")
            self.touch("python", text="#!/bin/sh\nexit 1\n")
            os.chmod(fake, 0o755)
            checks = self.checks(doc_of(GAS_AND_DROP), ["GPB"], python=fake)
        else:
            checks = self.checks(doc_of(GAS_AND_DROP), ["GPB"])
        self.assertTrue(any("does not import Cantera" in t for t in self.texts(checks, "error")))

    def test_gui_errors_by_stage(self):
        self.touch("mesh.tec", "gas-phase.txt", "drop-phase.txt")
        issues = [("error", ("bcb", None), "a"), ("error", ("bcb", "wall"), "b"),
                  ("warning", ("icb", 1), "c"), ("error", ("gpb", 0), "d")]
        checks = self.checks(doc_of(GAS_AND_DROP), ["BCB", "ICB"], issues=issues)
        mine = [(c.tool, c.text) for c in checks if "the checks find" in c.text]
        self.assertEqual(len(mine), 1)                 # GPB does not run; ICB has a warning only
        self.assertEqual(mine[0][0], "BCB")
        self.assertIn("2 errors in Boundaries", mine[0][1])

    def test_unsaved(self):
        self.touch("mesh.tec")
        checks = self.checks(doc_of(GAS_AND_DROP), ["ICB"], ini_path=None)
        self.assertTrue(any("not written to an INI file yet" in t
                            for t in self.texts(checks, "action")))
        checks = self.checks(doc_of(GAS_AND_DROP), ["ICB"], dirty=True)
        self.assertTrue(any("the run saves it first" in t for t in self.texts(checks, "action")))

    def test_readiness(self):
        ready = runner.readiness(doc_of(GAS_AND_DROP))
        self.assertEqual(ready["GPB"], (True, "2 phases: gas, drop"))
        self.assertEqual(ready["BCB"], (True, "1 block, 1 boundary condition"))
        self.assertEqual(ready["ICB"], (True, "All blocks"))
        empty = runner.readiness(AtlasDocument())
        self.assertEqual([v[0] for v in empty.values()], [False, False, False])

    def test_environment(self):
        root = os.path.join(self.case, "atlas")
        self.touch("atlas/build/thermo.lib")
        env = runner.environment(root, "/opt/py", 4, base={"PATH": "/bin"})
        self.assertEqual(env["ATLASDIR"], root)
        self.assertEqual(env["CEA_DATA_DIR"], os.path.join(root, "build"))
        self.assertEqual((env["ATLAS_PYTHON"], env["OMP_NUM_THREADS"]), ("/opt/py", "4"))
        self.assertEqual(env["PYTHONUNBUFFERED"], "1")
        mine = runner.environment(root, None, 0, base={"CEA_DATA_DIR": "/cea"})
        self.assertEqual(mine["CEA_DATA_DIR"], "/cea")
        self.assertNotIn("ATLAS_PYTHON", mine)
        self.assertNotIn("OMP_NUM_THREADS", mine)
        self.assertEqual(runner.gpb_python("/my/python"), ("/my/python", "set in Settings"))


# ----------------------------------------------------------------- runs
FAKE = """#!/bin/bash
# a stand-in for ATLAS.sh: $1 is the tool
tool=$1
echo "fake $tool"
case "$tool" in
  GPB)
    mkdir -p fromATLAStoSolver
    for f in gas-phase.txt gas-thermo.dat gas-transport.dat drop-properties.dat; do
      echo "$tool" > fromATLAStoSolver/$f
    done
    echo "[WARNING] GPB: a warning" ;;
  BCB)
    test -L mesh.p3d && echo "linked $(readlink mesh.p3d)"
    test -f gas-phase.txt && echo "BCB sees gas-phase.txt"
    test -f gas-transport.dat && echo "BCB sees gas-transport.dat"
    {bcb} ;;
  ICB)
    mkdir -p fromATLAStoSolver; echo ic > fromATLAStoSolver/ic.tec ;;
esac
"""


@unittest.skipIf(APP is None, "PyQt6 is not installed")
class TestRuns(CaseDir):

    def fake(self, bcb="exit 0"):
        path = os.path.join(self.case, "fake-atlas.sh")
        with open(path, "w") as handle:
            handle.write(FAKE.replace("{bcb}", bcb))
        os.chmod(path, 0o755)
        return path

    def run_session(self, names, script=None, stop_after=None, timeout=120, **kw):
        env = runner.environment(ATLAS, kw.pop("python", None))
        session = runner.RunSession(self.case, "input.ini", names, env, script=script, **kw)
        lines = []
        session.line.connect(lambda tool, text, kind: lines.append((tool, kind, text)))
        loop = QEventLoop()
        session.finished.connect(lambda ok: loop.quit())
        QTimer.singleShot(timeout * 1000, loop.quit)
        session.start()
        if stop_after is not None:
            QTimer.singleShot(int(stop_after * 1000), session.stop)
        loop.exec()
        self.assertIsNotNone(session.ok, "the run did not finish")
        return session, lines

    def test_chain_handoff_and_link(self):
        self.touch("input.ini", "chamber.p3d")
        session, lines = self.run_session(
            ["ICB", "BCB", "GPB"], self.fake(),
            mesh_link=("mesh.p3d", os.path.join(self.case, "chamber.p3d")))
        self.assertTrue(session.ok)
        self.assertEqual([r.status for r in session.results.values()], ["done"] * 3)
        self.assertEqual(list(session.results), ["GPB", "BCB", "ICB"])   # in the order they run
        out = [text for tool, kind, text in lines if tool == "BCB" and kind == "out"]
        self.assertIn("linked chamber.p3d", out)
        self.assertIn("BCB sees gas-phase.txt", out)
        self.assertNotIn("BCB sees gas-transport.dat", out)  # only the tables BCB and ICB read
        self.assertTrue(os.path.isfile(os.path.join(self.case, "drop-properties.dat")))
        gpb = session.results["GPB"]
        self.assertEqual(gpb.files, ["drop-properties.dat", "gas-phase.txt", "gas-thermo.dat",
                                     "gas-transport.dat"])
        self.assertEqual((gpb.errors, gpb.warnings), (0, 1))
        self.assertEqual(session.results["ICB"].files, ["ic.tec"])
        heads = [text for _t, kind, text in lines if kind == "head"]
        self.assertEqual(heads[0], "ATLAS GPB --input input.ini")
        self.assertTrue(heads[-1].startswith("ICB done in "))

    def test_failure_skips_the_rest(self):
        self.touch("input.ini")
        session, lines = self.run_session(
            ["BCB", "ICB"], self.fake("echo '[ERROR] BCB: no'; exit 3"))
        self.assertFalse(session.ok)
        bcb, icb = session.results["BCB"], session.results["ICB"]
        self.assertEqual((bcb.status, bcb.exit_code, bcb.errors), ("failed", 3, 1))
        self.assertEqual(icb.status, "skipped")
        self.assertIn("BCB failed after", [t for _n, k, t in lines if k == "head"][-1])

    def test_stop_ends_the_tool(self):
        self.touch("input.ini")
        script = self.fake("ls *phase.txt > filelist.txt 2>/dev/null; "
                           "sleep 60 & echo $! > child.pid; wait")
        started = time.monotonic()
        session, lines = self.run_session(["BCB", "ICB"], script, stop_after=1.5)
        self.assertLess(time.monotonic() - started, 20)
        self.assertFalse(session.ok)
        self.assertEqual([r.status for r in session.results.values()], ["stopped", "skipped"])
        with open(os.path.join(self.case, "child.pid")) as handle:
            child = int(handle.read())
        for _ in range(50):                      # the signal reaches the child too
            try:
                os.kill(child, 0)
            except ProcessLookupError:
                break
            time.sleep(0.1)
        else:
            os.kill(child, 9)
            self.fail("the tool started by the launcher survived the stop")
        self.assertFalse(os.path.exists(os.path.join(self.case, "filelist.txt")))

    def test_stop_keeps_the_users_filelist(self):
        self.touch("input.ini")
        self.touch("filelist.txt", text="gas-phase.txt\n")
        session, _lines = self.run_session(["BCB"], self.fake("sleep 60 & wait"), stop_after=1.0)
        self.assertEqual(session.results["BCB"].status, "stopped")
        self.assertTrue(os.path.exists(os.path.join(self.case, "filelist.txt")))

    @unittest.skipUnless(os.access(os.path.join(ATLAS, "bin", "ICB"), os.X_OK), "ICB is not built")
    def test_icb_through_atlas_sh(self):
        for name in ("input.ini", "mesh.tec", "solid-phase.txt"):
            shutil.copy(os.path.join(SP_BASIC, name), self.case)
        session, lines = self.run_session(["ICB"])
        self.assertTrue(session.ok, "\n".join(t for _n, _k, t in lines))
        self.assertEqual(session.results["ICB"].files, ["solid-ic.tec"])
        self.assertEqual(session.results["ICB"].exit_code, 0)
        self.assertFalse(os.path.exists(os.path.join(self.case, "filelist.txt")))
        # the same file as ATLAS ICB typed in a shell
        shell = os.path.join(self.case, "shell")
        os.makedirs(shell)
        for name in ("input.ini", "mesh.tec", "solid-phase.txt"):
            shutil.copy(os.path.join(SP_BASIC, name), shell)
        subprocess.run(["bash", runner.launcher(ATLAS), "ICB"], cwd=shell, capture_output=True,
                       env=runner.environment(ATLAS), check=True, timeout=120)
        with open(os.path.join(self.case, runner.OUTPUT_DIR, "solid-ic.tec")) as mine, \
                open(os.path.join(shell, runner.OUTPUT_DIR, "solid-ic.tec")) as typed:
            self.assertEqual(mine.read(), typed.read())

    @unittest.skipUnless(os.access(os.path.join(ATLAS, "bin", "ICB"), os.X_OK), "ICB is not built")
    @unittest.skipUnless(runner.has_cantera(), "this Python has no Cantera for GPB")
    def test_gpb_then_icb(self):
        shutil.copy(os.path.join(IG_2D, "mesh.p3d"), self.case)
        self.touch("input.ini", text=textwrap.dedent("""
            [GPB-Phase1]
            name = air
            mixture-name = air
            mixture = {N2: 75.4} {O2: 23.3} {Ar: 1.3}
            thermo = NASA9
            transport = CEA

            [ICB-Block*]
            p = 1e5
            T = 300
            """))
        session, lines = self.run_session(["GPB", "ICB"], python=sys.executable)
        self.assertTrue(session.ok, "\n".join(t for _n, _k, t in lines))
        self.assertIn("air-phase.txt", os.listdir(self.case))
        self.assertEqual(session.results["ICB"].files, ["air-ic.tec"])


if __name__ == "__main__":
    unittest.main()
