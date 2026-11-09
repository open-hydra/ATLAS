"""Centralized configuration for GPB: paths, directories, constants."""
import os
import sys

# ------------------------------------------------------------------
# ATLAS root directory
# ------------------------------------------------------------------
ATLASDIR = os.environ.get("ATLASDIR")
if ATLASDIR is None:
    print("ERROR: ATLASDIR environment variable is not set.")
    sys.exit(1)

# ------------------------------------------------------------------
# Database paths
# ------------------------------------------------------------------
DATAPATH = os.path.join(ATLASDIR, "database")
THERMO_DIR = os.path.join(DATAPATH, "thermo")
# Thermo database files that ATLAS does not distribute (burcat.yaml): git ignores the content of this folder
# (database/thermo/external/README.md)
THERMO_EXTERNAL_DIR = os.path.join(THERMO_DIR, "external")
TRANSPORT_DIR = os.path.join(DATAPATH, "transport")
CHEMISTRY_DIR = os.path.join(DATAPATH, "chemistry")
# Mechanisms that are not published: git ignores the content of this folder (database/chemistry/external/README.md)
EXTERNAL_DIR = os.path.join(CHEMISTRY_DIR, "external")
CEA_TRANS_FILE = os.path.join(TRANSPORT_DIR, "CEApolynomials.yaml")


def chemistry_dirs():
    """The folders where a mechanism is searched: database/chemistry, database/chemistry/external and the folders
    of it (at any depth) that hold yaml files, in name order."""
    dirs = [CHEMISTRY_DIR, EXTERNAL_DIR]
    for root, subdirs, files in os.walk(EXTERNAL_DIR):
        subdirs[:] = sorted(d for d in subdirs if not d.startswith("."))
        if root != EXTERNAL_DIR and any(f.endswith(".yaml") for f in files):
            dirs.append(root)
    return dirs

# ------------------------------------------------------------------
# Output path; BCB, ICB and MDB read the phase files there when the case directory has none of the same name
# (src/common/global.f90)
# ------------------------------------------------------------------
OUTPATH = "fromATLAStoSolver/"

# ------------------------------------------------------------------
# Heavy-gas constants
# ------------------------------------------------------------------
HG_FACTOR = 1.0e+5
HG_SUBSTRING = "-HG"


def require_burcat():
    """The path of burcat.yaml, which ATLAS does not distribute: the first of the case directory,
    database/thermo/external and database/thermo (Cantera's search would put the case directory last). Stop, with
    where to put it, when it is in none."""
    for d in (os.getcwd(), THERMO_EXTERNAL_DIR, THERMO_DIR):
        path = os.path.join(d, "burcat.yaml")
        if os.path.isfile(path):
            return path
    print("[ERROR] GPB: thermo = Burcat needs burcat.yaml, which ATLAS does not distribute: the authors allow the "
          "database for non-commercial use, with citation, and ask for their written permission otherwise. Download it "
          "and put it in database/thermo/external/ (or in the case directory): see database/thermo/external/README.md")
    sys.exit(1)


def mechanism_copies(stem):
    """The files <stem>.yaml in the folders of chemistry_dirs(). Cantera takes one of them, which depends on the
    order of the folders: GPB refuses a name that has more than one (the file of the case directory comes first)."""
    return [p for p in (os.path.join(d, stem + ".yaml") for d in chemistry_dirs()) if os.path.isfile(p)]


def setup_cantera_dirs():
    """Register the ATLAS database directories with Cantera (idempotent)."""
    import cantera as ct
    ct.add_directory(THERMO_DIR)
    ct.add_directory(THERMO_EXTERNAL_DIR)
    ct.add_directory(TRANSPORT_DIR)
    for d in chemistry_dirs():
        ct.add_directory(d)


def ensure_output_dir():
    """Create the output directory if it does not exist."""
    os.makedirs(OUTPATH, exist_ok=True)


# The products of a run are written into a temporary sibling directory and moved into OUTPATH only when every phase
# of the deck succeeded; a refusal or a crash leaves nothing behind (the temporary directory is removed); files already
# present in OUTPATH are never removed (a product of the same name is replaced). The temporary directory is a new one
# for every run (.gpb-tmp-<random>): a directory left by a run killed from outside is never reused, so its files never
# reach OUTPATH.
FINAL_OUTPATH = OUTPATH
def stage_output():
    """Redirect OUTPATH to the staging directory. Call before the builder modules are imported (they bind OUTPATH at import)."""
    global OUTPATH
    import tempfile
    OUTPATH = os.path.join(tempfile.mkdtemp(prefix=".gpb-tmp-", dir="."), "")
    return OUTPATH

def commit_output():
    """Move every staged product into FINAL_OUTPATH (a rename per file; a copy when FINAL_OUTPATH is on another file system) and drop the staging directory."""
    import shutil
    os.makedirs(FINAL_OUTPATH, exist_ok=True)
    for f in sorted(os.listdir(OUTPATH)):
        shutil.move(os.path.join(OUTPATH, f), os.path.join(FINAL_OUTPATH, f))
    os.rmdir(OUTPATH)

def discard_output():
    """Remove the staging directory and whatever it holds (only files written by this run)."""
    import shutil
    shutil.rmtree(OUTPATH, ignore_errors=True)
