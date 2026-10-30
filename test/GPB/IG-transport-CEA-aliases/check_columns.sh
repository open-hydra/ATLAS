#!/bin/bash
# The rows (temperature, viscosity, conductivity) of zone $2 of the transport table $1 are those of zone $4 of the table $3, byte by
# byte: a species found through an alias of its CEApolynomials record (AR) gets the columns of the same record found by its name (Ar).
# Usage: check_columns.sh <transport.dat> <zone> <reference transport.dat> <zone>
set -u
rows() { awk -v z="$2" '/^ZONE/ { p = ($0 == "ZONE T=\"" z "\"") } p && /^ *[0-9]/' "$1"; }
a=$(rows "$1" "$2"); b=$(rows "$3" "$4")
if [ -z "$a" ] || [ -z "$b" ]; then echo "FAIL zone $2 of $1 or zone $4 of $3 has no rows"; exit 1; fi
if [ "$a" != "$b" ]; then echo "FAIL zone $2 of $1 differs from zone $4 of $3:"; diff <(echo "$a") <(echo "$b") | head -5; exit 1; fi
echo "PASS zone $2 of $1 = zone $4 of $3 ($(echo "$a" | wc -l) rows)"
