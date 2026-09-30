#!/usr/bin/env python3
"""Gate of an objective = cost decomposition: it must predict a strictly lower
maximum rank time than a reference run of MDB on the same deck.

  ./check-predicted-time.py <searched mdb log> <reference mdb log>

Both logs must carry MDB's `Predicted rank time (max)` line, printed whenever
the fine-level BC file was scanned. The prediction is MDB's own [MDB-Cost]
model, so the two runs must use the same coefficients.
"""
import re
import sys


def predicted(path):
    m = None
    for line in open(path):
        m = re.search(r'Predicted rank time \(max\)\s+([0-9.]+)', line) or m
    if m is None:
        sys.exit(f'{path}: no "Predicted rank time (max)" line')
    return float(m.group(1))


def main(searched, reference):
    a, b = predicted(searched), predicted(reference)
    print(f'predicted rank time (max): {a:.1f} searched, {b:.1f} reference')
    if not a < b:
        print(f'  [FAIL] the searched decomposition does not predict a lower time than {reference}')
        return 1
    print(f'  [ok]   the searched decomposition predicts {100.0 * (1 - a / b):.1f}% less')
    return 0


if __name__ == '__main__':
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    sys.exit(main(*sys.argv[1:3]))
