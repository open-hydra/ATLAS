"""Writer of <name>pyrolysis.dat, the format of brief §3.2 (read by FLINT_Lib_PyrolysisGas)."""
from config import OUTPATH, ensure_output_dir

outpath = OUTPATH
ensure_output_dir()

FLOOR = 1.0e-99   # values below it are written as 0: every number keeps a 2-digit exponent (the bytes of Fortran ES24.16)


def _num(v):
    v = float(v)
    return '%24.16E' % (0.0 if abs(v) < FLOOR else v)


def write_tables(name, tables):
    """One file, one table block per entry of *tables* (dicts of builder._table), in the given order."""
    with open(outpath + name + 'pyrolysis.dat', 'w') as f:
        f.write('# hydra pyrolysis-gas composition table\n')
        f.write('format 1\n')
        f.write(f'tables {len(tables)}\n')
        for t in tables:
            f.write(f"table {t['name']}\n")
            f.write(f"treatment {t['treatment']}\n")
            f.write(f"elements {len(t['elements'])} " +
                    ' '.join(f'{e} {_num(w).strip()}' for e, w in zip(t['elements'], t['massf'])) + '\n')
            f.write('condensed 0\n')
            f.write(f"species {len(t['species'])}\n")
            for s in t['species']:
                f.write(s + '\n')
            f.write(f"pressures {len(t['p'])}\n")
            f.write(''.join(_num(p) for p in t['p']) + '\n')
            f.write(f"temperatures {len(t['T'])}\n")
            f.write(''.join(_num(T) for T in t['T']) + '\n')
            f.write('data\n')
            for row in t['rows']:
                f.write(''.join(_num(y) for y in row) + '\n')
            f.write('end table\n')
