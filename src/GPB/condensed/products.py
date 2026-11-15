"""Condensed material -> gas species, <name>products.txt of every dispersed phase (read by hydra-MI2 for the phase
of ICE and for the phase of IGLOO). Run after every [GPB-Phase*] is built: it reads back the phase files of this run.

One record per process GPB can resolve for a material; the coupler keeps the records of the processes the solver runs:
  evaporation  the material's vapour (psat-vapour), energy word "latent"
  combustion   the reaction of particle-mechanism that consumes it and gives gas species only
  cap          the reaction that consumes it and gives one condensed product, the material that product= names on
               its line (the oxide a cap retains): the gas species it draws and frees, per kg of the material
  release      the reaction that consumes a product material and gives gas species only (a cap handed to the gas)
The three reaction records carry the energy word "formation": the heat of reaction is in the formation enthalpies of
the species, so every gas species of a reaction is a species of the gas phase. A material that burns (combustion= on
its line) and that no reaction consumes stops GPB."""
import os
import re
import yaml
import cantera as ct
from PiNeR import get
import config
from config import PARTICLE_MECH_DIR, require_burcat
from ini.condensed import (CP_read_models, CP_read_material, CP_read_psat_pairs, CP_read_enthalpy_datum,
                           CP_read_particle_mechanism)
from .builder import THERMO_FILES

T_REF = 298.15
CONDENSED_SUFFIX = re.compile(r'\([^()]+\)$')    # (L), (cr), (gr), (a), (II), ...: how the databases mark a condensed species
TERM = re.compile(r'^\s*(?:(\d*\.?\d+(?:[eE][-+]?\d+)?)\s+)?(\S+)\s*$')   # '[coefficient ]species'
BAD_CHARS = (',', '/')    # a name is one blank-separated token of the file, read by a Fortran list-directed read
ORDER = {'combustion': 0, 'cap': 1, 'release': 2}   # a molar mass a reaction fixes is known to the kinds after it


def _phase_prefix(ini, section):
    name = get(ini, section, 'name', str)
    return name + '-' if name else ''


def _read_phase_file(path):
    with open(path) as f:
        lines = [l.split() for l in f if l.strip()]
    return lines[0], lines[1:]


def _read_products_of(path):
    """material -> its combustion product, from the cap rows of <name>models.txt (no file: no capped material)."""
    out = {}
    if os.path.exists(path):
        with open(path) as f:
            for r in (l.split() for l in f if l.strip() and not l.lstrip().startswith('#')):
                if r[1] == 'cap':
                    out.update({r[0]: t.split('=', 1)[1] for t in r[3:] if t.startswith('product=')})
    return out


def _composition(sp):
    return {e: n for e, n in sp.composition.items() if n != 0}


def _resolve_vapour(material, pair, db, from_db):
    """The vapour of a material: the one of its psat pair, else, for a material taken from the database, its species
    without the condensed suffix when the two have the same elements, else None."""
    if pair is not None:
        return pair[1]
    m = CONDENSED_SUFFIX.search(material)
    if m is None or not from_db:
        return None
    vap = material[:m.start()]
    if vap in db and _composition(db[vap]) == _composition(db[material]):
        return vap
    return None


def _check_name(name, sec, pname):
    if any(c in name for c in BAD_CHARS):
        raise SystemExit(f"[ERROR] [{sec}] the name '{name}' holds ',' or '/': {pname}products.txt is read token by "
                         "token and cannot carry it")


def _h_table(sp, T):
    """Formation-inclusive enthalpy [J/kg] as the condensed table of GPB gives it (properties.py): the fit inside its
    range, constant cp beyond its ends."""
    Te = min(max(T, sp.thermo.min_temp), sp.thermo.max_temp)
    return (sp.thermo.h(Te) + sp.thermo.cp(Te) * (T - Te)) / sp.molecular_weight


def _gas_h_ref(path):
    """Enthalpy [J/kg] at 298.15 K of every species of the gas phase's thermo table (rows at integer kelvin)."""
    out, name, rows = {}, None, {}
    with open(path) as f:
        for line in f:
            if line.startswith('ZONE'):
                name, rows = line.split('"')[1], {}
            elif name and line[:1].isdigit():
                t = line.split()
                if float(t[0]) in (298.0, 299.0):
                    rows[float(t[0])] = float(t[2])
                if len(rows) == 2:
                    out[name] = rows[298.0] + (rows[299.0] - rows[298.0]) * (T_REF - 298.0)
                    name = None
    return out


def _parse_side(side, eq, where):
    terms = {}
    for t in side.split(' + '):
        m = TERM.match(t)
        if not m:
            raise SystemExit(f"{where}: reaction '{eq}': cannot parse the term '{t.strip()}'")
        terms[m.group(2)] = terms.get(m.group(2), 0.0) + (float(m.group(1)) if m.group(1) else 1.0)
    return terms


def load_particle_mechanism(stem, section):
    where = f"[ERROR] [{section}] particle-mechanism = {stem}"
    places = ((os.getcwd(), './'), (PARTICLE_MECH_DIR, 'database/particle-combustion/'))
    found = [(os.path.join(d, stem + '.yaml'), label + stem + '.yaml') for d, label in places
             if os.path.isfile(os.path.join(d, stem + '.yaml'))]
    if not found:
        avail = sorted(f[:-5] for f in os.listdir(PARTICLE_MECH_DIR) if f.endswith('.yaml')) \
            if os.path.isdir(PARTICLE_MECH_DIR) else []
        raise SystemExit(f"{where}: no {stem}.yaml in the case directory or in {PARTICLE_MECH_DIR}. "
                         f"Available: {' '.join(avail) or '(none)'}")
    if len(found) > 1:
        raise SystemExit(f"{where}: two files of that name, {found[0][1]} and {found[1][1]}: rename one")
    path, label = found[0]
    with open(path) as f:
        data = yaml.safe_load(f) or {}
    reactions = []
    for r in data.get('reactions', []):
        eq = r['equation']
        if '<=>' in eq or '=>' not in eq:
            raise SystemExit(f"{where}: '{eq}': a particle reaction is irreversible, write '=>'")
        lhs, rhs = eq.split('=>')
        reactions.append((eq, _parse_side(lhs, eq, where), _parse_side(rhs, eq, where)))
    if not reactions:
        raise SystemExit(f"{where}: {label} holds no reaction")
    return data.get('name', stem), label, reactions


def _check_balance(eq, lhs, rhs, comp, where):
    bal = {}
    for side, sign in ((lhs, -1.0), (rhs, 1.0)):
        for s, nu in side.items():
            for el, n in comp[s].items():
                bal[el] = bal.get(el, 0.0) + sign * nu * n
    bad = {e: v for e, v in bal.items() if abs(v) > 1e-9}
    if bad:
        raise SystemExit(f"{where}: '{eq}' is not element-balanced (products - reactants: {bad})")


def _check_same_species(s, W_db, W_gas, thermo_file, where):
    if abs(W_db - W_gas) > 1e-3 * W_gas:
        raise SystemExit(f"{where}: species {s} weighs {W_db:.6g} in {thermo_file} but {W_gas:.6g} in the gas "
                         "phase file: the two names are not the same species")


def write_products_maps(ini, phase_definitions):
    gas = [p for p in phase_definitions if any(w in p.phase_type.lower() for w in ('ideal', 'heavy'))]
    dispersed = [p for p in phase_definitions if 'dispersed' in p.phase_type.lower()]
    if not dispersed:
        return
    if len(gas) != 1:
        for p in dispersed:
            if CP_read_particle_mechanism(ini, p.section):
                raise SystemExit(f"[ERROR] [{p.section}] particle-mechanism needs exactly one ideal-gas [GPB-Phase*] "
                                 f"in the deck ({len(gas)} found)")
        return                                    # no gas, or several: no map can be written, none is asked for
    gprefix = _phase_prefix(ini, gas[0].section)
    _, grows = _read_phase_file(config.OUTPATH + gprefix + 'phase.txt')
    gas_W = {r[0]: float(r[1]) for r in grows}
    for p in dispersed:
        _write_one(ini, p, gas[0].section, gprefix, gas_W)


def _write_one(ini, phase, gas_section, gprefix, gas_W):
    sec = phase.section
    name, _, _, thermo = CP_read_models(ini, sec)
    # as the builder: the materials are the database's when no cp is given, or when thermo is given beside cp
    database = (thermo or 'NASA9') in THERMO_FILES and (CP_read_material(ini, sec)[2] is None or thermo is not None)
    thermo = thermo or 'NASA9'
    db, thermo_file = {}, 'no species database'
    if thermo in THERMO_FILES:
        thermo_file = require_burcat() if thermo == 'Burcat' else THERMO_FILES[thermo]
        db = {s.name: s for s in ct.Species.list_from_file(thermo_file)}
    header, rows = _read_phase_file(config.OUTPATH + name + 'phase.txt')
    materials = [r[0] for r in rows]
    tokens = [dict(t.split('=', 1) for t in r[2:]) for r in rows]
    for m in materials:
        _check_name(m, sec, name)
    pairs = CP_read_psat_pairs(ini, sec, materials) or [None] * len(materials)
    h0 = CP_read_enthalpy_datum(ini, sec, len(materials))
    gas_list = ' '.join(gas_W)
    records = {m: [] for m in materials}          # m -> [(process, energy, h298, [(sp, nu_mass, nu_mole)], comment, tail)]

    def from_db(m):
        return database and m in db

    def h298(i):
        """The material's formation-inclusive enthalpy at 298.15 K [J/kg], None when the deck does not give one."""
        m = materials[i]
        if from_db(m):
            return _h_table(db[m], T_REF)
        return None if h0 is None else float(h0[i])

    # --- evaporation: the material's own vapour ---------------------------------------------------------------
    for i, m in enumerate(materials):
        where = f"[ERROR] [{sec}] material {m}"
        evaporates = 'evaporation' in tokens[i]
        vap = _resolve_vapour(m, pairs[i], db, from_db(m))
        if vap is None:
            if evaporates:
                raise SystemExit(f"{where}: evaporation={tokens[i]['evaporation']} but no vapour species: give "
                                 f"psat-vapour, or name the material by its species of {thermo_file} (as H2O(L))")
            continue
        if vap not in gas_W:
            msg = (f"{where}: its vapour {vap} is not a species of the gas phase ({gas_list}): "
                   f"add it to [{gas_section}] species")
            if evaporates:
                raise SystemExit(msg)
            if pairs[i] is not None:               # a vapour the deck names: say why no record is written
                print(' [WARNING]' + msg[7:] + ' (no evaporation record written)')
            continue
        _check_name(vap, sec, name)
        _check_same_species(vap, db[vap].molecular_weight, gas_W[vap], thermo_file, where)
        records[m].append(('evaporation', 'latent', h298(i) or 0.0, [(vap, 1.0, 1.0)], f'{m} -> {vap}', ''))

    # --- the reactions of the particle mechanism ----------------------------------------------------------------
    stem = CP_read_particle_mechanism(ini, sec)
    mech_label = 'none'
    done = set()                                     # (material, kind) a reaction already gave
    product_of = _read_products_of(config.OUTPATH + name + 'models.txt')
    if stem:
        mname, mpath, reactions = load_particle_mechanism(stem, sec)
        mech_label = f"{mname} ({mpath})"
        # what is known of each species: molar mass [kg/kmol], elements, enthalpy at 298.15 K [J/kg]
        W = {s: (db[s].molecular_weight if s in db else w) for s, w in gas_W.items()}
        comp = {s: _composition(db[s]) for s in gas_W if s in db}
        gas_h = None
        for m in materials:
            if from_db(m):
                W[m], comp[m] = db[m].molecular_weight, _composition(db[m])
        work = []
        for eq, lhs, rhs in reactions:
            where = f"[ERROR] [{sec}] particle-mechanism {mname}, '{eq}'"
            cond = [s for s in lhs if s in materials or CONDENSED_SUFFIX.search(s)]
            if len(cond) != 1:
                raise SystemExit(f"{where}: needs exactly one condensed reactant, found {' '.join(cond) or 'none'}")
            fuel = cond[0]
            if fuel not in materials:
                raise SystemExit(f"{where}: the condensed reactant {fuel} is not a material of this phase "
                                 f"({' '.join(materials)})")
            made = [s for s in rhs if s in materials or CONDENSED_SUFFIX.search(s)]
            if len(made) > 1:
                raise SystemExit(f"{where}: {len(made)} condensed products ({' '.join(made)}): a reaction gives gas "
                                 "species, and at most the one product a cap retains")
            if made:
                kind = 'cap'
                if product_of.get(fuel) != made[0]:
                    raise SystemExit(f"{where}: condensed product {made[0]}: a record hands the gas gas species only. "
                                     f"A condensed product is the oxide a cap retains: declare it as a material of "
                                     f"this phase with 0 groups and name it with product on the line of {fuel} "
                                     f"(product of {fuel}: {product_of.get(fuel, 'none')})")
            else:
                kind = 'release' if fuel in product_of.values() else 'combustion'
            if (fuel, kind) in done:
                raise SystemExit(f"{where}: a second reaction consumes {fuel}" +
                                 ("" if kind == 'combustion' else f" ({kind})"))
            done.add((fuel, kind))
            work.append((ORDER[kind], kind, fuel, made[0] if made else None, eq, lhs, rhs, where))
        for _, kind, fuel, prod, eq, lhs, rhs, where in sorted(work, key=lambda t: t[0]):
            net = {s: -nu for s, nu in lhs.items() if s != fuel}
            for s, nu in rhs.items():
                if s != prod:
                    net[s] = net.get(s, 0.0) + nu
            for s in net:
                if s not in gas_W:
                    raise SystemExit(f"{where}: gas species {s} is not in the gas phase ({gas_list}): "
                                     f"add it to [{gas_section}] species")
                _check_name(s, sec, name)
                if s in db:
                    _check_same_species(s, db[s].molecular_weight, gas_W[s], thermo_file, where)
            # the molar mass of a constant-property material is the one the reaction's mass balance gives it
            everyone = list(lhs) + list(rhs)
            unknown = [s for s in everyone if s not in W]
            if len(unknown) > 1:
                raise SystemExit(f"{where}: {' and '.join(unknown)} are constant-property materials: the reaction "
                                 "cannot give two molar masses. Name one by its species of the thermo database, or "
                                 f"give the reaction that consumes {fuel} into gas species first")
            if unknown:
                u = unknown[0]
                known = sum(nu * W[s] for s, nu in rhs.items() if s != u) - sum(nu * W[s] for s, nu in lhs.items() if s != u)
                W[u] = known / lhs[u] if u in lhs else -known / rhs[u]
                if not W[u] > 0.0:
                    raise SystemExit(f"{where}: the mass balance gives {u} the molar mass {W[u]:.6g}: the reaction "
                                     "cannot conserve mass")
                print(f" -- {u} has no composition: '{eq}' is balanced in mass only, with {W[u]:.6f} kg/kmol for {u}")
            elif all(s in comp for s in everyone):
                _check_balance(eq, lhs, rhs, comp, where)
            else:
                bare = ' '.join(s for s in everyone if s not in comp)
                print(f" -- {bare}: no composition, the element balance of '{eq}' is not checked (its mass is)")
            nf, Wf = lhs[fuel], W[fuel]
            terms = [(s, nu * W[s] / (nf * Wf), nu / nf) for s, nu in net.items() if nu != 0.0]
            nu_prod = rhs[prod] * W[prod] / (nf * Wf) if prod else 0.0
            total = sum(t[1] for t in terms) + nu_prod
            if abs(total - 1.0) > 1e-8:
                raise SystemExit(f"{where}: mass coefficients sum to {total:.12g}, not 1")
            hf = h298(materials.index(fuel))
            hp = h298(materials.index(prod)) if prod else 0.0
            for s, h in ((fuel, hf), (prod, hp)):
                if h is None:
                    raise SystemExit(f"{where}: {s} is a constant-property material without h0: a reaction needs its "
                                     "enthalpy at 298.15 K on the formation scale of the gas (h0, one value per "
                                     "material); the heat of reaction is the difference of these enthalpies")
            if any(s not in db for s, _, _ in terms) and gas_h is None:
                gas_h = _gas_h_ref(config.OUTPATH + gprefix + 'thermo.dat')
            Qr = hf - nu_prod * hp - sum(nm * (_h_table(db[s], T_REF) if s in db else gas_h[s]) for s, nm, _ in terms)
            print(f" -- {fuel}: '{eq}', heat of reaction {Qr/1e6:.4f} MJ/kg at {T_REF} K")
            tail = f" {prod} {nu_prod:.10e} {hp:.10e}" if prod else ''
            records[fuel].append((kind, 'formation', hf, terms, eq, tail))

    # --- a material told to burn names its reaction: the gas holds what it becomes ------------------------------
    for i, m in enumerate(materials):
        word = tokens[i].get('combustion')
        if word and word != 'none' and (m, 'combustion') not in done:
            raise SystemExit(f"[ERROR] [{sec}] material {m}: combustion={word} and no reaction consumes it: give "
                             f"particle-mechanism = <stem>, the file of the reaction '{m} [+ gas species] => gas "
                             f"species'. Every gas species of it must be a species of the gas phase ({gas_list})")
        if m in product_of and (m, 'cap') not in done:
            raise SystemExit(f"[ERROR] [{sec}] material {m}: product={product_of[m]} and no reaction of "
                             f"particle-mechanism makes {product_of[m]} from it: add '{m} [+ gas species] => "
                             f"{product_of[m]} [+ gas species]'")

    path = config.OUTPATH + name + 'products.txt'
    with open(path, 'w') as f:
        f.write("# ATLAS GPB: condensed material -> gas species. Generated: edit the INI and run ATLAS GPB again.\n")
        f.write(f"# particle-mechanism: {mech_label}\n")
        f.write("# record: material <name> <none|evaporation|combustion|cap|release> <terms> <none|latent|formation> "
                "<h298 [J/kg]>\n")
        f.write("#         then <terms> lines: <gas species> <nu_mass [kg/kg material]> <nu_mole [mol/mol material]>\n")
        f.write("#         a cap record ends with: <product material> <kg of it per kg of material> <its h298 [J/kg]>\n")
        f.write(f"gas {gprefix or '-'} {len(gas_W)}\n")
        for m in materials:
            if not records[m]:
                f.write(f"material {m} none 0 none {0.0:.10e}\n")
            for proc, energy, h, terms, comment, tail in records[m]:
                f.write(f"# {comment}\n")
                f.write(f"material {m} {proc} {len(terms)} {energy} {h:.10e}{tail}\n")
                for s, nm, nmol in terms:
                    f.write(f"  {s} {nm:.10e} {nmol:.10e}\n")
    print(f" -- Material -> gas species written to {name}products.txt")
    for m in materials:
        if not records[m]:
            print(f"    {m}: no record (inert)")
        for proc, energy, _, terms, _, tail in records[m]:
            kept = f"; condensed product {tail.split()[0]} {float(tail.split()[1]):+.5f}" if tail else ''
            print(f"    {m} [{proc}, {energy}]: " + ', '.join(f"{s} {nm:+.5f}" for s, nm, _ in terms) + kept)
