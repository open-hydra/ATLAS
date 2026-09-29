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
TRANSPORT_DIR = os.path.join(DATAPATH, "transport")
CHEMISTRY_DIR = os.path.join(DATAPATH, "chemistry")
CEA_TRANS_FILE = os.path.join(TRANSPORT_DIR, "CEApolynomials.yaml")

# ------------------------------------------------------------------
# Output path
# ------------------------------------------------------------------
OUTPATH = "fromATLAStoSolver/"

# ------------------------------------------------------------------
# Heavy-gas constants
# ------------------------------------------------------------------
HG_FACTOR = 1.0e+5
HG_SUBSTRING = "-HG"


def setup_cantera_dirs():
    """Register the ATLAS database directories with Cantera (idempotent)."""
    import cantera as ct
    ct.add_directory(THERMO_DIR)
    ct.add_directory(TRANSPORT_DIR)
    ct.add_directory(CHEMISTRY_DIR)


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
