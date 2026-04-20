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
