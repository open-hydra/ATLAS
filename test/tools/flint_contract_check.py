#!/usr/bin/env python3
"""Check the ATLAS chemistry database against the mechanism contract that FLINT publishes (a copy of its
src/lib/Lib_ChemMech/mechanism_contract.json in test/tools/flint_mechanism_contract.json).

FLINT selects its compiled chemistry routine by the exact phase name GPB writes on line 1 of
<name>chemistry-info.txt (read list-directed: a blank truncates the name); any other name falls back to the
'general' procedure with a WARNING. FLINT's contract file records, for every hooked name, the routine's
species slots, number of species, reaction counts per table type and, for generated routines, the per-reaction
fingerprint that FLINT computes from its own sources; test/tools/flint_mechanism_contract.source names the
FLINT commit of the copy.

For every database/chemistry/*.yaml (Cantera parse = the parse GPB uses):
  1. effective name = the phase name as FLINT reads it (first blank-delimited token); a name with blanks is
     flagged, and it is an ERROR if the truncation changes the hook (full name vs effective name);
  2. hooked name (a case): species slots must match by elemental composition, and by name for generated
     routines (same generator source) or where two slots share a composition; ns exact, except that a
     routine which zeroes omegadot before its assignments may be followed by inert species (in no
     reaction); reaction counts per table type (FLINT rule on the Cantera reaction type: 'Troe' -> troe,
     'Lindemann' -> lindemann, everything else -> arrhenius) must equal the routine's; generated routines:
     the fingerprint (table class/index, concentration factors, third-body use and efficiencies, omegadot
     stoichiometric rows) must match with 0 mismatches;
  3. one phase name = one structural content: two files with the same phase name must have the same species
     list and the same reaction structure (reactants, products, effective orders, reversibility, table
     class, efficiencies); rate parameters may differ;
  4. a file whose description starts with 'BROKEN:' is skipped (and listed);
  5. --expect FILE=ROUTINE (repeatable; not with --only) pins a hook: ERROR if FILE does not select
     ROUTINE ('general' = must not be a case) or is missing/skipped;
Exit status 1 on any ERROR.   Usage: flint_contract_check.py <database dir> [--only FILE.yaml]
[--require-fingerprint] [--contract JSON] [--expect FILE=ROUTINE ...]   (Python >= 3.6, Cantera, PyYAML)
"""
import argparse, glob, json, os, sys, warnings
from collections import Counter, OrderedDict
try:
    import cantera as ct, yaml
except ImportError as e:
    sys.exit('flint_contract_check: %s (run with ATLAS_PYTHON = the ATLAS conda interpreter)' % e)
warnings.filterwarnings('ignore')

class _Loader(yaml.SafeLoader):
    """PyYAML resolves NO/ON/OFF/YES as booleans (YAML 1.1); Cantera's parser (YAML 1.2 core) keeps them as strings, e.g. the species NO"""
_Loader.yaml_implicit_resolvers = {k: [(t, r) for t, r in v if t != 'tag:yaml.org,2002:bool'] for k, v in yaml.SafeLoader.yaml_implicit_resolvers.items()}
try: ct.suppress_thermo_warnings()
except Exception: pass

def table_class(rtype):
    if 'Troe' in rtype: return 'troe'
    if 'Lindemann' in rtype: return 'lindemann'
    return 'arrhenius'

NAME_READ = 'whole line (trimmed)'   # how FLINT reads line 1 of chemistry-info.txt (a constant of this checker)

def effective_name(name):
    """The phase name as FLINT Load_Chemistry.f90 reads line 1 of chemistry-info.txt: the whole line with TAB/CR as
    blanks, trimmed (snapshot name_read 'whole line (trimmed)'), or the first token delimited by a blank, comma or
    slash (older FLINT, list-directed read)."""
    if NAME_READ.startswith('whole line'):
        return name.replace('\t', ' ').replace('\r', ' ').strip()
    for sep in (' ', ',', '/'):
        name = name.split(sep)[0]
    return name

def yaml_reactions(g):
    """structural description of every reaction (1-based slots)"""
    sp = g.species_names; out = []; cnt = Counter()
    for i in range(g.n_reactions):
        r = g.reaction(i); cls = table_class(r.reaction_type); cnt[cls] += 1
        fwd = OrderedDict((str(sp.index(s) + 1), float(v)) for s, v in r.reactants.items())
        for s, v in r.orders.items(): fwd[str(sp.index(s) + 1)] = float(v)
        rev = OrderedDict((str(sp.index(s) + 1), float(v)) for s, v in r.products.items())
        tb = getattr(r, 'third_body', None)
        effs = OrderedDict((str(k + 1), float(tb.efficiency(s))) for k, s in enumerate(sp)) if tb is not None else None
        out.append(dict(n=i + 1, eq=r.equation, type=r.reaction_type, cls=cls, idx=cnt[cls], fwd=fwd, rev=rev, rev_flag=bool(r.reversible), tb=tb is not None, effs=effs))
    return out

def structural_fingerprint(g):
    rx = yaml_reactions(g)
    return json.dumps([g.species_names] + [[r['eq'], r['cls'], sorted(r['fwd'].items()), sorted(r['rev'].items()), r['rev_flag'],
                                            sorted((k, v) for k, v in (r['effs'] or {}).items() if v != 0)] for r in rx], sort_keys=True)

def check_fingerprint(g, fp):
    """generated routine: compare the routine's parsed structure with the yaml (0 mismatches expected)"""
    errs = []; rx = yaml_reactions(g); R = fp['reactions']; om = fp['omegadot']; sp = g.species_names
    if len(R) != len(rx): errs.append('n_reactions routine=%d yaml=%d' % (len(R), len(rx)))
    for r in rx:
        gR = R.get(str(r['n']))
        if gR is None: errs.append('r%d: missing in routine' % r['n']); continue
        f, b = gR.get('f', {}), gR.get('b', {})
        if list(f.get('tab', [])) != [r['cls'], r['idx']]: errs.append('r%d %s: table %s expected %s' % (r['n'], r['eq'], f.get('tab'), [r['cls'], r['idx']]))
        ffac = {k: float(v) for k, v in f.get('fac', {}).items()}
        if ffac != dict(r['fwd']): errs.append('r%d %s: forward factors routine %s yaml %s' % (r['n'], r['eq'], ffac, dict(r['fwd'])))
        bfac = {k: float(v) for k, v in b.get('fac', {}).items()}
        if bfac != dict(r['rev']): errs.append('r%d %s: reverse factors routine %s yaml %s' % (r['n'], r['eq'], bfac, dict(r['rev'])))
        fo = r['cls'] in ('troe', 'lindemann'); tb3 = r['tb'] and not fo
        if tb3 and not (f.get('usesM') and b.get('usesM')): errs.append('r%d: three-body but the routine does not multiply M' % r['n'])
        if not r['tb'] and (f.get('usesM') or b.get('usesM')): errs.append('r%d: routine multiplies M, yaml has no third body' % r['n'])
        if r['tb']:
            M = {}
            for v, slots in (fp['M'][f['Mi']] if f.get('Mi') is not None else []):
                for s in slots: M[str(s)] = float(v)
            ye = {k: v for k, v in r['effs'].items() if v != 0}
            if set(ye) != set(M) or any(abs(ye[k] - M[k]) > 1e-9 * max(1.0, abs(ye[k])) for k in ye):
                errs.append('r%d %s: third-body efficiencies routine %s yaml %s' % (r['n'], r['eq'], M, ye))
    for i, s in enumerate(sp, 1):
        row = om.get(str(i))
        if row is None: errs.append('species %d %s: omegadot never assigned' % (i, s)); continue
        yrow = {}
        for r in rx:
            v = r['rev'].get(str(i), 0.0) - r['fwd'].get(str(i), 0.0) if True else 0
            # stoichiometry, not orders: recompute from the reaction dictionaries
        for r in rx:
            react = g.reaction(r['n'] - 1); v = react.products.get(s, 0.0) - react.reactants.get(s, 0.0)
            if abs(v) > 0: yrow[str(r['n'])] = round(v, 9)
        rrow = {k: round(float(v), 9) for k, v in row.items() if abs(float(v)) > 0}
        if rrow != yrow: errs.append('species %d %s: omegadot row routine %s yaml %s' % (i, s, rrow, yrow))
    extra = [k for k in om if int(k) > len(sp)]
    if extra: errs.append('routine assigns omegadot beyond the yaml species: %s' % extra)
    return errs

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('database', help='ATLAS database directory (contains chemistry/ and thermo/nasa9.yaml)')
    ap.add_argument('--only', help='check this yaml only (still loads the others for the one-name-one-content check unless --require-fingerprint)')
    ap.add_argument('--require-fingerprint', action='store_true', help='ERROR unless the hooked routine of --only has a fingerprint and matches it')
    ap.add_argument('--contract', help="copy of FLINT's src/lib/Lib_ChemMech/mechanism_contract.json (default: flint_mechanism_contract.json next to this script)")
    ap.add_argument('--expect', nargs='+', default=[], metavar='FILE=ROUTINE', help="pinned hook: ERROR unless FILE selects ROUTINE ('general' = not a case); not with --only")
    a = ap.parse_args()
    expect = {}
    for x in a.expect:
        if x.count('=') != 1: sys.exit('--expect wants FILE=ROUTINE, got %r' % x)
        expect[x.split('=')[0]] = x.split('=')[1]
    here = os.path.dirname(os.path.abspath(__file__))
    chem = os.path.join(a.database, 'chemistry'); contract = a.contract or os.path.join(here, 'flint_mechanism_contract.json')
    C = json.load(open(contract)); cases = C['cases']
    src = os.path.join(os.path.dirname(os.path.abspath(contract)), 'flint_mechanism_contract.source')
    origin = open(src).read().strip() if os.path.exists(src) else 'origin not recorded'
    print('FLINT mechanism contract: %s (%s; %d cases; name read %s)' % (os.path.basename(contract), origin, len(cases), NAME_READ))
    files = sorted(glob.glob(os.path.join(chem, '*.yaml')))
    if a.only and a.require_fingerprint: files = [f for f in files if os.path.basename(f) == a.only]
    errors, flags, skipped, byname, byeff, checked = [], [], [], {}, {}, set()
    for f in files:
        fn = os.path.basename(f)
        doc = yaml.load(open(f, encoding='utf-8'), Loader=_Loader)
        desc = str(doc.get('description') or '').strip().splitlines()
        if desc and desc[0].startswith('BROKEN:'): skipped.append('%s: %s' % (fn, desc[0][:90])); continue
        try:
            g = ct.Solution(f)
        except Exception as e:
            errors.append('%s: Cantera cannot load it: %s' % (fn, str(e).splitlines()[0])); continue
        name = g.name; eff = effective_name(name)
        if eff != name:
            hook_full, hook_eff = name in cases, eff in cases
            msg = "%s: phase name %r contains a blank/comma/slash: FLINT reads %r (%s)" % (fn, name, eff, 'hooks %s' % cases[eff]['routine'] if hook_eff else 'general')
            if hook_full != hook_eff: errors.append(msg + ' - the truncation changes the hook')
            else: flags.append(msg)
        byname.setdefault(name, []).append((fn, g)); byeff.setdefault(eff, set()).add(name)
        if a.only and fn != a.only: continue
        checked.add(fn)
        c = cases.get(eff)
        if fn in expect:   # hook pinned by the ctest registration: a renamed file fails
            want, got = expect.pop(fn), (c['routine'] if c else 'general')
            if want != got: errors.append('%s: --expect %s but the phase %r selects %s (pinned hook lost)' % (fn, want, name, got))
        if c is None:
            print('  %-32s %-20s -> general (%d species, %d reactions)' % (fn, name, g.n_species, g.n_reactions))
            if a.require_fingerprint: errors.append('%s: phase %r is not a FLINT case: no fingerprint to check' % (fn, name))
            continue
        tag = '%s [%s]' % (c['routine'], c['kind']); e0 = len(errors)
        slots = c.get('species')
        if slots is None:
            errors.append('%s: phase %r hooks %s but the snapshot has no slot information for it' % (fn, name, c['routine']))
        else:
            comps = [json.dumps(s['composition'], sort_keys=True) for s in slots]
            sp = g.species_names; ns = c['ns']
            if len(sp) < ns: errors.append('%s: %d species, routine %s addresses %d slots' % (fn, len(sp), c['routine'], ns))
            for i, s in enumerate(slots[:len(sp)]):
                ycomp = json.dumps(OrderedDict(sorted((k, int(v) if float(v).is_integer() else float(v)) for k, v in g.species(i).composition.items())), sort_keys=True)
                scomp = json.dumps(OrderedDict(sorted((k, int(v) if float(v).is_integer() else float(v)) for k, v in (s['composition'] or {}).items())), sort_keys=True)
                if s['composition'] is not None and ycomp != scomp:
                    errors.append('%s: slot %d is %s %s in routine %s, yaml has %s %s' % (fn, i + 1, s['name'], scomp, c['routine'], sp[i], ycomp))
                elif (c['kind'] == 'generated' or comps.count(comps[i]) > 1) and s['name'] != sp[i]:
                    errors.append('%s: slot %d is named %s in routine %s, yaml has %s' % (fn, i + 1, s['name'], c['routine'], sp[i]))
            if len(sp) > ns:
                inert = [s for s in sp[ns:] if not any(s in g.reaction(i).reactants or s in g.reaction(i).products for i in range(g.n_reactions))]
                if not c.get('zeroes_omegadot') or len(inert) != len(sp) - ns:
                    errors.append('%s: %d species but routine %s addresses %d slots%s' % (fn, len(sp), c['routine'], ns, '' if c.get('zeroes_omegadot') else ' and does not zero omegadot (trailing species undefined)'))
                else:
                    flags.append('%s: trailing inert species %s beyond the %d slots of %s (allowed: omegadot zeroed)' % (fn, sp[ns:], ns, c['routine']))
        if c.get('nrc') is not None:
            cnt = Counter(table_class(g.reaction(i).reaction_type) for i in range(g.n_reactions))
            ycnt = OrderedDict([('arrhenius', cnt['arrhenius']), ('troe', cnt['troe']), ('lindemann', cnt['lindemann'])])
            if dict(ycnt) != dict(c['nrc']): errors.append('%s: reaction counts per table type yaml %s routine %s %s' % (fn, dict(ycnt), c['routine'], dict(c['nrc'])))
        if c.get('fingerprint'):
            fe = check_fingerprint(g, c['fingerprint'])
            if fe: errors.extend('%s vs %s fingerprint: %s' % (fn, c['routine'], x) for x in fe[:12])
            if len(fe) > 12: errors.append('%s: ... %d more fingerprint mismatches' % (fn, len(fe) - 12))
            tag += ' fingerprint %d reactions, %d mismatches' % (len(c['fingerprint']['reactions']), len(fe))
        elif a.require_fingerprint: errors.append('%s: routine %s has no fingerprint in the snapshot' % (fn, c['routine']))
        print('  %-32s %-20s -> %s: %s' % (fn, name, tag, 'OK' if len(errors) == e0 else '%d ERROR(S)' % (len(errors) - e0)))
    if a.only and a.only not in checked: errors.append('--only %s: file missing, skipped (BROKEN) or not loadable: nothing was checked' % a.only)
    for fn, want in sorted(expect.items()): errors.append('--expect %s=%s: file missing, skipped or not checked' % (fn, want))
    if not (a.only and a.require_fingerprint):
        for eff, lst in sorted(byname.items()):
            if len(lst) < 2: continue
            fps = {fn: structural_fingerprint(g) for fn, g in lst}
            if len(set(fps.values())) > 1: errors.append('one name = one content: phase %r in %s with different species/reaction structure' % (eff, sorted(fps)))
            else: flags.append('phase %r shared by %s: identical structural fingerprint (rate parameters may differ)' % (eff, sorted(fps)))
        for eff, names in sorted(byeff.items()):
            if len(names) > 1: flags.append('effective name %r shared by the phases %s (%s)' % (eff, sorted(names), 'hooks %s' % cases[eff]['routine'] if eff in cases else 'general'))
    for s in skipped: print('  [SKIPPED] ' + s)
    for s in flags: print('  [FLAG] ' + s)
    for s in errors: print('  [ERROR] ' + s)
    print('flint-contract-check: %d file(s), %d skipped, %d flag(s), %d error(s)' % (len(files), len(skipped), len(flags), len(errors)))
    sys.exit(1 if errors else 0)
if __name__ == '__main__': main()
