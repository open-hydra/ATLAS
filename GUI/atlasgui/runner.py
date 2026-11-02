"""Running the ATLAS tools on the case: GPB, then BCB, then ICB.

The GUI runs each tool as a user would from the case directory --
``ATLAS <TOOL> --input <ini>``, through ``ATLAS.sh`` -- one after the other,
and stops the chain at the first tool that fails, as ``ATLAS GPB BCB ICB``
does.  Two things a chained run needs are not done by the tools themselves,
and the run does them, saying so in its log:

* **the mesh**: BCB and ICB read ``mesh.tec``, ``mesh.p3d`` or ``mesh.szplt``
  from the case directory (the first that exists, ``read_mesh.f90``); a mesh
  loaded under another name is linked under the default one;
* **the phase files**: BCB and ICB read the ``*phase.txt`` of the case
  directory with their ``thermo.dat`` and ``properties.dat`` tables, while GPB
  writes them into ``fromATLAStoSolver/``; after GPB, the tables it has just
  written are copied into the case directory (the *hand-off*).

:func:`preflight` says beforehand what a run will do and what will stop it,
from the case alone; :class:`RunSession` runs the tools.  Nothing here makes a
widget: the Run stage (:mod:`atlasgui.runpanel`) shows both.
"""

from __future__ import annotations

import glob
import os
import re
import shutil
import signal
import sys
import time
from dataclasses import dataclass, field

from .gpbmodel import ATLAS_ROOT

OUTPUT_DIR = "fromATLAStoSolver"
MESH_NAMES = ("mesh.tec", "mesh.p3d", "mesh.szplt")    # the order the tools read them
# the default name a mesh file is read under, by its extension (the GUI's own
# reader, mesh_io, takes the same ASCII Tecplot and Plot3D files)
MESH_LINK_NAMES = {".tec": "mesh.tec", ".dat": "mesh.tec", ".plt": "mesh.tec",
                   ".tp": "mesh.tec", ".p3d": "mesh.p3d", ".xyz": "mesh.p3d",
                   ".g": "mesh.p3d", ".grd": "mesh.p3d", ".szplt": "mesh.szplt"}
PHASE_TABLES = ("phase.txt", "thermo.dat", "properties.dat")   # what BCB and ICB read
FILELIST = "filelist.txt"
GPB_STAGING = ".gpb-tmp-*"


@dataclass(frozen=True)
class Tool:
    name: str           # what ATLAS.sh takes
    stage: str          # the stage of the GUI that edits its sections
    label: str
    builds: str


TOOLS = (
    Tool("GPB", "gpb", "Phases", "the phase property tables"),
    Tool("BCB", "bcb", "Boundaries", "the boundary conditions of every block face"),
    Tool("ICB", "icb", "Initial", "the initial field of every block"),
)
TOOL_NAMES = tuple(t.name for t in TOOLS)


def tool(name):
    return next(t for t in TOOLS if t.name == name)


# ----------------------------------------------------------- environment
def atlas_root(setting=""):
    """The ATLAS installation the tools come from: *setting* when given, else
    the one this GUI belongs to."""
    path = os.path.abspath(os.path.expanduser(setting)) if setting else ATLAS_ROOT
    return path


def launcher(root):
    return os.path.join(root, "ATLAS.sh")


def binary(root, name):
    """``bin/<name>`` of a Fortran tool, None for GPB (run from source)."""
    return None if name == "GPB" else os.path.join(root, "bin", name)


_CANTERA = {}        # (interpreter, its mtime) -> whether it imports Cantera


def has_cantera(python=None):
    """Whether *python* (this interpreter when None) has Cantera, which GPB
    needs.  This interpreter is asked without importing it; another one is
    started once (the answer is kept until the file changes)."""
    if python is None or os.path.realpath(python) == os.path.realpath(sys.executable):
        import importlib.util
        return importlib.util.find_spec("cantera") is not None
    import subprocess
    try:
        key = (os.path.realpath(python), os.path.getmtime(python))
    except OSError:
        return False
    if key not in _CANTERA:
        try:
            _CANTERA[key] = subprocess.run([python, "-c", "import cantera"],
                                           capture_output=True, timeout=60).returncode == 0
        except (OSError, subprocess.SubprocessError):
            _CANTERA[key] = False
    return _CANTERA[key]


def gpb_python(setting="", environ=None):
    """``(python, how)``: the interpreter GPB runs with, passed to ATLAS.sh as
    ``ATLAS_PYTHON``, and how it was found.  *setting* is the user's choice;
    when empty, this interpreter if it has Cantera, else ``ATLAS_PYTHON`` of
    the environment, else None: ATLAS.sh activates its conda environment."""
    environ = os.environ if environ is None else environ
    if setting:
        return os.path.expanduser(setting), "set in Settings"
    if has_cantera():
        return sys.executable, "the GUI's own"
    if environ.get("ATLAS_PYTHON"):
        return environ["ATLAS_PYTHON"], "ATLAS_PYTHON"
    return None, "conda"


def environment(root, python=None, threads=0, base=None):
    """The environment the tools run in: the GUI's, with ``ATLASDIR``, the CEA
    tables of the build (as ``scripts/setvars.sh`` sets them), the interpreter
    of GPB and the OpenMP threads (0: as the environment has them), and
    unbuffered output, so that the log follows the tool as it runs."""
    env = dict(os.environ if base is None else base)
    env["ATLASDIR"] = root
    if "CEA_DATA_DIR" not in env and os.path.isfile(os.path.join(root, "build", "thermo.lib")):
        env["CEA_DATA_DIR"] = os.path.join(root, "build")
    if python:
        env["ATLAS_PYTHON"] = python
    if threads:
        env["OMP_NUM_THREADS"] = str(threads)
    env["PYTHONUNBUFFERED"] = "1"
    env["GFORTRAN_UNBUFFERED_PRECONNECTED"] = "y"
    env["FORT_BUFFERED"] = "false"
    return env


def ini_argument(ini_path, case_dir):
    """The ``--input`` of the tools: the INI's name when it lives in the case
    directory, where they run, else its full path."""
    ini_path = os.path.abspath(ini_path)
    if os.path.dirname(ini_path) == os.path.abspath(case_dir):
        return os.path.basename(ini_path)
    return ini_path


def command_line(name, ini_arg):
    """What the user would type for the same run."""
    arg = ini_arg if " " not in ini_arg else f'"{ini_arg}"'
    return f"ATLAS {name} --input {arg}"


# ------------------------------------------------------------------ files
def snapshot(directory):
    """``{name: (mtime_ns, size)}`` of the files of *directory*."""
    files = {}
    try:
        entries = list(os.scandir(directory))
    except OSError:
        return files
    for entry in entries:
        try:
            if entry.is_file():
                info = entry.stat()
                files[entry.name] = (info.st_mtime_ns, info.st_size)
        except OSError:
            continue
    return files


def written(before, after):
    """The files of *after* that are new or changed since *before*."""
    return sorted(name for name, stamp in after.items() if before.get(name) != stamp)


def tools_mesh(case_dir):
    """The mesh file BCB and ICB read in *case_dir*, or None."""
    for name in MESH_NAMES:
        path = os.path.join(case_dir, name)
        if os.path.exists(path):
            return path
    return None


def _same_file(a, b):
    try:
        return os.path.samefile(a, b)
    except OSError:
        return False


@dataclass
class MeshPlan:
    """What BCB and ICB will read as the mesh.

    ``level`` is ``ok`` (the tools read the mesh the GUI shows), ``action``
    (the run links ``link`` to the loaded mesh first), ``warning`` (they read
    another file than the one loaded) or ``error`` (they find no mesh, or the
    loaded one is in a format they do not read under a default name).
    """
    level: str
    text: str
    reads: str = ""             # the file they read, once the run has linked it
    link: str = ""              # the default name to link to the loaded mesh


def mesh_plan(case_dir, loaded=None):
    current = tools_mesh(case_dir)
    if loaded:
        loaded = os.path.abspath(loaded)
        name = os.path.basename(loaded)
        if current and _same_file(current, loaded):
            return MeshPlan("ok", f"BCB and ICB read {os.path.basename(current)}, the mesh "
                            "on the screen", current)
        if current:
            return MeshPlan("warning", (
                f"BCB and ICB read {os.path.basename(current)} of the case directory, not "
                f"{name}, the mesh on the screen: the blocks and faces of the case are "
                f"those of {name}"), current)
        link = MESH_LINK_NAMES.get(os.path.splitext(name)[1].lower())
        if link is None:
            return MeshPlan("error", (
                f"{name} is not in a format BCB and ICB read (ASCII Tecplot, Plot3D or "
                f".szplt): write it as mesh.tec or mesh.p3d"))
        return MeshPlan("action", (
            f"BCB and ICB read the mesh as {link}: the run links {link} to {name} "
            f"in the case directory first"), os.path.join(case_dir, link), link)
    if current:
        return MeshPlan("ok", f"BCB and ICB read {os.path.basename(current)}", current)
    return MeshPlan("error", (
        "no mesh: BCB and ICB read mesh.tec, mesh.p3d or mesh.szplt of the case directory; "
        "load one"))


def link_mesh(case_dir, link, target):
    """Make *link* in *case_dir* name *target* (a relative symbolic link, a
    copy where links are not allowed).  Returns what was done, for the log."""
    path = os.path.join(case_dir, link)
    rel = os.path.relpath(os.path.abspath(target), case_dir)
    try:
        os.symlink(rel, path)
        return f"{link} → {rel} (link)"
    except (OSError, NotImplementedError):
        shutil.copy2(target, path)
        return f"{link} ← {rel} (copy)"


def gpb_prefixes(gpb):
    """The prefix of the files every GPB phase of the deck writes:
    ``gas-`` for ``name = gas``, empty for an unnamed phase."""
    prefixes = []
    for phase in gpb.phases:
        prefix = f"{phase.name}-" if phase.name else ""
        if prefix not in prefixes:
            prefixes.append(prefix)
    return prefixes


def phase_tables(names):
    """The files of *names* that BCB and ICB read as phase tables."""
    return [n for n in names if n.endswith(PHASE_TABLES)]


def case_phase_files(case_dir):
    return sorted(os.path.basename(p) for p in glob.glob(os.path.join(case_dir, "*phase.txt")))


def read_filelist(case_dir):
    """The names ``filelist.txt`` lists, or None when there is none."""
    try:
        with open(os.path.join(case_dir, FILELIST), encoding="utf-8", errors="replace") as handle:
            return [line.strip() for line in handle if line.strip()]
    except OSError:
        return None


# -------------------------------------------------------------- preflight
@dataclass
class Check:
    """One thing to know before a run.  ``level``: ``error`` (the tool cannot
    run), ``warning`` (it runs, and may stop or build the wrong thing),
    ``action`` (the run does something first), ``info``, ``ok``."""
    level: str
    tool: str | None
    text: str


LEVEL_ORDER = {"error": 0, "warning": 1, "action": 2, "info": 3, "ok": 4}


def readiness(doc):
    """``{tool: (enabled, note)}``: what each tool would build for *doc*,
    or why it has nothing to build."""
    phases = [p.name or "(unnamed)" for p in doc.gpb.phases]
    gpb = (bool(phases), f"{len(phases)} phase{'s' * (len(phases) != 1)}: {', '.join(phases)}"
           if phases else "no phase in the deck")
    nblocks, nbcs = doc.bcb.nblocks, len(doc.bcb.sections)
    if nblocks:
        bcb = (True, f"{nblocks} block{'s' * (nblocks != 1)}, "
                     f"{nbcs} boundary condition{'s' * (nbcs != 1)}")
    elif doc.bcb.wildcard:
        bcb = (True, "every block, from [BCB-Block*]")
    else:
        bcb = (False, "no boundary condition in the deck")
    icb = doc.icb
    if icb.is_empty():
        icb_state = (False, "no initial state in the deck")
    else:
        blocks = sorted(icb.blocks)
        parts = (["All blocks"] if icb.wildcard is not None else []) + \
            [f"Block {b}" for b in blocks[:6]] + (["…"] if len(blocks) > 6 else [])
        icb_state = (True, ", ".join(parts))
    return {"GPB": gpb, "BCB": bcb, "ICB": icb_state}


def preflight(doc, case_dir, selected, *, ini_path=None, dirty=False, mesh_path=None,
              root=ATLAS_ROOT, python=None, python_how="", handoff=True, issues=()):
    """What a run of the tools *selected* would do, and what would stop it.

    *issues* are the GUI's own checks, ``[(level, (stage, index), message)]``:
    their errors in the stage of a selected tool are reported once per stage.
    *python* and *python_how* are :func:`gpb_python`'s answer.
    """
    checks = []
    selected = [n for n in TOOL_NAMES if n in selected]
    if not selected:
        return [Check("info", None, "no tool selected")]

    if not ini_path:
        checks.append(Check("action", None, "the case is not written to an INI file yet: "
                            "the run asks where to save it first"))
    elif dirty:
        checks.append(Check("action", None, f"{os.path.basename(ini_path)} has changes not "
                            "written yet: the run saves it first"))
    if not os.path.isfile(launcher(root)):
        checks.append(Check("error", None, f"no ATLAS.sh in {root}: set the ATLAS directory "
                            "in Settings → Tools"))
    for name in selected:
        exe = binary(root, name)
        if exe and not os.access(exe, os.X_OK):
            checks.append(Check("error", name, f"{name} is not built ({os.path.relpath(exe, root)} "
                                "not found): ./install.sh build"))

    if "GPB" in selected:
        if python and not has_cantera(python):
            checks.append(Check("error", "GPB", f"{python} ({python_how}) does not import "
                                "Cantera: set the Python of GPB in Settings → Tools"))
        elif python:
            checks.append(Check("ok", "GPB", f"GPB runs with {python} ({python_how})"))
        elif shutil.which("conda") is None:
            checks.append(Check("error", "GPB", "no Python with Cantera for GPB: neither this "
                                "GUI's Python nor ATLAS_PYTHON has it, and there is no conda "
                                "to activate ct-env; set one in Settings → Tools"))
        else:
            checks.append(Check("info", "GPB", "GPB runs in the conda environment ATLAS.sh "
                                "activates (ct-env, or ATLAS_CONDA_ENV)"))

    downstream = [n for n in selected if n in ("BCB", "ICB")]
    if downstream:
        who = " and ".join(downstream)
        plan = mesh_plan(case_dir, mesh_path)
        checks.append(Check(plan.level, downstream[0] if len(downstream) == 1 else None,
                            plan.text.replace("BCB and ICB", who)))
        checks += _phase_checks(doc, case_dir, "GPB" in selected, handoff, who)

    stages = {t.stage: t.name for t in TOOLS if t.name in selected}
    counts = {}
    for level, (stage, _index), _message in issues:
        if level == "error" and stage in stages:
            counts[stage] = counts.get(stage, 0) + 1
    for stage, count in counts.items():
        name = stages[stage]
        checks.append(Check("warning", name, (
            f"the checks find {count} error{'s' * (count != 1)} in {tool(name).label}: "
            f"{name} will likely stop on {'them' if count != 1 else 'it'} (see Review)")))

    out = os.path.join(case_dir, OUTPUT_DIR)
    present = len(snapshot(out))
    checks.append(Check("info", None, (
        f"the tools write into {OUTPUT_DIR}/" + (
            f", which holds {present} file{'s' * (present != 1)}: a tool replaces the files "
            "it writes, the others stay" if present else ""))))
    checks.sort(key=lambda c: LEVEL_ORDER[c.level])
    return checks


def _phase_checks(doc, case_dir, gpb_runs, handoff, who):
    """Which phase files BCB and ICB (*who*) will read."""
    checks = []
    prefixes = gpb_prefixes(doc.gpb)
    expected = {f"{p}phase.txt" for p in prefixes}
    present = case_phase_files(case_dir)
    if gpb_runs and handoff:
        names = ", ".join(sorted(expected))
        tables = "its" if len(expected) == 1 else "their"
        checks.append(Check("action", None, (
            f"after GPB, the phase tables it writes ({names} with {tables} thermo.dat or "
            f"properties.dat) are copied into the case directory, where {who} read them")))
    elif gpb_runs:
        checks.append(Check("warning", None, (
            f"{who} read the phase files of the case directory, not those GPB writes into "
            f"{OUTPUT_DIR}/: " + (", ".join(present) if present
                                  else "there are none, so they assume one ideal gas"))))
    elif not present:
        checks.append(Check("warning", None, (
            f"no *phase.txt in the case directory: {who} assume one ideal gas" + (
                "; run GPB with them to give them the phases of the deck" if prefixes else ""))))
    else:
        checks.append(Check("info", None, f"{who} read the phases {', '.join(present)}"))
        out = os.path.join(case_dir, OUTPUT_DIR)
        for name in present:
            built = os.path.join(out, name)
            try:
                newer = os.path.getmtime(built) > os.path.getmtime(os.path.join(case_dir, name)) + 1
            except OSError:
                newer = False
            if newer:
                checks.append(Check("warning", None, (
                    f"{name} of the case directory is older than the one GPB wrote last in "
                    f"{OUTPUT_DIR}/: run GPB with them to use the new one")))
    if prefixes:
        stale = [n for n in present if n not in expected]
        if stale:
            checks.append(Check("warning", None, (
                f"{who} also read {', '.join(stale)}, which no phase of the deck writes: "
                "remove it from the case directory if it is not a phase of this case")))
    listed = read_filelist(case_dir)
    if listed is not None:
        checks.append(Check("warning", None, (
            f"{FILELIST} in the case directory lists the phase files {who} read "
            f"({', '.join(listed) or 'none'}), not every *phase.txt: ATLAS.sh keeps it as it is")))
    return checks


# ------------------------------------------------------------------- runs
_LEVEL_RE = re.compile(r"\[(ERROR|WARNING)\]|^\s*(ERROR|WARNING)\s*:|^Traceback |"
                       r"Fortran runtime error|^\s*forrtl: severe|Program received signal|"
                       r"Segmentation fault", re.I)


def line_level(text):
    """``error``, ``warning`` or None: what a line of a tool's output reports."""
    match = _LEVEL_RE.search(text)
    if not match:
        return None
    word = (match.group(1) or match.group(2) or "ERROR").upper()
    return "error" if word == "ERROR" else "warning"


@dataclass
class ToolResult:
    """How one tool of a run went.  ``status``: ``waiting``, ``running``,
    ``done``, ``failed``, ``stopped`` or ``skipped`` (an earlier tool failed)."""
    name: str
    status: str = "waiting"
    seconds: float = 0.0
    exit_code: int | None = None
    files: list = field(default_factory=list)
    lines: list = field(default_factory=list)      # what it printed
    errors: int = 0
    warnings: int = 0
    started: float = 0.0


try:
    from PyQt6.QtCore import QObject, QProcess, QProcessEnvironment, QTimer, pyqtSignal
except ImportError:                     # the preflight works without Qt
    QObject = object

if QObject is not object:

    class RunSession(QObject):
        """One run: the tools *names*, in order, in *case_dir*, on *ini_arg*.

        Every tool is a process of its own group (``os.setsid``), so that
        Stop ends the tool ``ATLAS.sh`` started along with ``ATLAS.sh``.  After
        a stop, the ``filelist.txt`` ATLAS.sh made and the staging directory of
        GPB are removed, as the tools would have on their way out.

        Signals: ``line(tool, text, kind)`` for every line of the log, *kind*
        ``out`` (the tool's own output), ``head`` (a tool starts or ends) or
        ``gui`` (what the run does besides); ``tool_started(tool)``,
        ``tool_finished(tool)``; ``finished(ok)``.
        """

        line = pyqtSignal(str, str, str)
        tool_started = pyqtSignal(str)
        tool_finished = pyqtSignal(str)
        finished = pyqtSignal(bool)

        def __init__(self, case_dir, ini_arg, names, env, *, script=None,
                     mesh_link=None, handoff=True, parent=None):
            super().__init__(parent)
            self.case_dir = case_dir
            self.ini_arg = ini_arg
            self.names = [n for n in TOOL_NAMES if n in names]
            self.env = env
            self.script = script or launcher(env.get("ATLASDIR", ATLAS_ROOT))
            self.mesh_link = mesh_link          # (link, target) or None
            self.handoff = handoff
            self.results = {n: ToolResult(n) for n in self.names}
            self.out_dir = os.path.join(case_dir, OUTPUT_DIR)
            self.running = None
            self.stopping = False
            self.ok = None
            self._process = None
            self._buffer = ""
            self._queue = []
            self._kill_timer = QTimer(self)
            self._kill_timer.setSingleShot(True)
            self._kill_timer.timeout.connect(lambda: self._signal(signal.SIGKILL))

        # -- control -----------------------------------------------------
        def start(self):
            self._queue = list(self.names)
            self._next()

        def stop(self):
            """End the tool that runs and skip the others."""
            if self.running is None or self.stopping:
                return
            self.stopping = True
            self._say(self.running, "stop asked: the tool is ended", "gui")
            self._signal(signal.SIGTERM)
            self._kill_timer.start(3000)

        def is_running(self):
            return self.running is not None

        def wait(self, msecs=5000):
            """Block until the tool that runs ends (closing the window)."""
            if self._process is not None:
                self._process.waitForFinished(msecs)

        # -- the chain ---------------------------------------------------
        def _next(self):
            if not self._queue:
                self._finish(True)
                return
            name = self._queue.pop(0)
            result = self.results[name]
            if name in ("BCB", "ICB") and self.mesh_link:
                link, target = self.mesh_link
                self.mesh_link = None
                try:
                    self._say(name, link_mesh(self.case_dir, link, target), "gui")
                except OSError as exc:
                    self._say(name, f"[ERROR] {link} could not be made: {exc}", "gui")
                    result.status = "failed"
                    result.errors += 1
                    self.tool_finished.emit(name)
                    self._skip_rest()
                    self._finish(False)
                    return
            self._before = snapshot(self.out_dir)
            self._had_filelist = os.path.exists(os.path.join(self.case_dir, FILELIST))
            self._staging = set(glob.glob(os.path.join(self.case_dir, GPB_STAGING)))
            result.status = "running"
            result.started = time.monotonic()
            self.running = name
            self._buffer = ""
            self.tool_started.emit(name)
            self._say(name, command_line(name, self.ini_arg), "head")

            process = QProcess(self)
            process.setWorkingDirectory(self.case_dir)
            process.setProcessChannelMode(QProcess.ProcessChannelMode.MergedChannels)
            env = QProcessEnvironment()
            for key, value in self.env.items():
                env.insert(key, value)
            process.setProcessEnvironment(env)
            process.readyReadStandardOutput.connect(self._read)
            process.finished.connect(self._done)
            process.errorOccurred.connect(self._error)
            self._process = process
            # a new process group, so that a stop reaches the tool ATLAS.sh runs
            process.start(sys.executable, [
                "-I", "-c", "import os, sys; os.setsid(); os.execvp(sys.argv[1], sys.argv[1:])",
                "bash", self.script, name, "--input", self.ini_arg])

        def _read(self):
            data = bytes(self._process.readAllStandardOutput()).decode("utf-8", "replace")
            self._buffer += data.replace("\r\n", "\n")
            *lines, self._buffer = self._buffer.split("\n")
            for text in lines:
                self._tool_line(text)

        def _tool_line(self, text):
            result = self.results[self.running]
            result.lines.append(text)
            level = line_level(text)
            if level == "error":
                result.errors += 1
            elif level == "warning":
                result.warnings += 1
            self.line.emit(self.running, text, "out")

        def _error(self, error):
            if error == QProcess.ProcessError.FailedToStart:
                self._say(self.running, f"[ERROR] the tool could not be started: "
                          f"{self._process.errorString()}", "gui")
                self.results[self.running].errors += 1
                self._done(-1, QProcess.ExitStatus.CrashExit)

        def _done(self, code, status):
            if self.running is None:
                return
            self._kill_timer.stop()
            name = self.running
            if self._buffer:
                self._tool_line(self._buffer)
                self._buffer = ""
            result = self.results[name]
            result.seconds = time.monotonic() - result.started
            result.exit_code = code if status == QProcess.ExitStatus.NormalExit else None
            result.files = written(self._before, snapshot(self.out_dir))
            if self.stopping:
                result.status = "stopped"
                self._tidy_after_stop(name)
            elif status == QProcess.ExitStatus.NormalExit and code == 0:
                result.status = "done"
            else:
                result.status = "failed"
            self.running = None
            process, self._process = self._process, None
            process.deleteLater()
            files = len(result.files)
            if result.status == "done":
                what = f"{files} file{'s' * (files != 1)} written" if files else "no file written"
                self._say(name, f"{name} done in {result.seconds:.1f} s: {what}", "head")
            elif result.status == "stopped":
                self._say(name, f"{name} stopped after {result.seconds:.1f} s", "head")
            else:
                why = f"exit status {code}" if result.exit_code is not None else "it crashed"
                self._say(name, f"{name} failed after {result.seconds:.1f} s ({why})", "head")
            if result.status == "done" and name == "GPB" and self.handoff:
                self._hand_off(result.files)
            self.tool_finished.emit(name)
            if result.status != "done":
                self._skip_rest()
                self._finish(False)
            else:
                self._next()

        def _hand_off(self, files):
            """Copy the phase tables GPB wrote into the case directory."""
            tables = phase_tables(files)
            for name in tables:
                target = os.path.join(self.case_dir, name)
                try:
                    if os.path.islink(target):
                        os.remove(target)
                    shutil.copy2(os.path.join(self.out_dir, name), target)
                except OSError as exc:
                    self._say("GPB", f"[WARNING] {name} could not be copied into the case "
                              f"directory: {exc}", "gui")
                    continue
            if tables:
                self._say("GPB", f"copied into the case directory for BCB and ICB: "
                          f"{', '.join(tables)}", "gui")

        def _tidy_after_stop(self, name):
            """Remove what a stopped tool leaves behind and a whole run does not."""
            filelist = os.path.join(self.case_dir, FILELIST)
            if not self._had_filelist and os.path.exists(filelist):
                try:
                    os.remove(filelist)
                    self._say(name, f"removed {FILELIST}, which ATLAS.sh made for the run", "gui")
                except OSError:
                    pass
            for path in set(glob.glob(os.path.join(self.case_dir, GPB_STAGING))) - self._staging:
                shutil.rmtree(path, ignore_errors=True)
                self._say(name, f"removed {os.path.basename(path)}, the staging directory "
                          "of the stopped GPB", "gui")

        def _skip_rest(self):
            for name in self._queue:
                self.results[name].status = "skipped"
                self.tool_finished.emit(name)
            self._queue = []

        def _finish(self, ok):
            self.ok = ok
            self.finished.emit(ok)

        def _say(self, name, text, kind):
            self.line.emit(name or "", text, kind)

        def _signal(self, sig):
            if self._process is None:
                return
            pid = int(self._process.processId())
            if pid <= 0:
                return
            try:
                os.killpg(pid, sig)
            except (ProcessLookupError, PermissionError):
                # stopped before the wrapper made its group: end the process itself
                if sig == signal.SIGKILL:
                    self._process.kill()
                else:
                    self._process.terminate()
