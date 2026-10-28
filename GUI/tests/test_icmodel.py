"""Tests of the ICB model of the GUI (no Qt needed).

usage: python3 -B GUI/tests/test_icmodel.py [-v]

Every deck of the test suite goes through the GUI's case document and back:
the ICB sections -- blocks, zones, and what the model keeps as read -- must
come out with the same keys, values and key order, and no zone section may
turn into a boundary condition.
"""

import os
import sys
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(_HERE))

from atlasgui import gpbmodel, icmodel  # noqa: E402
from atlasgui.bcmodel import BCBDocument, _parse_ini  # noqa: E402
from atlasgui.document import AtlasDocument  # noqa: E402
from atlasgui.icmodel import ICState, ICZoneRef  # noqa: E402

TEST_ROOT = os.path.join(icmodel.ATLAS_ROOT, "test")


def decks():
    """Every INI deck of the test suite (not the copies the runs make)."""
    found = []
    for root, dirs, files in os.walk(TEST_ROOT):
        dirs[:] = sorted(d for d in dirs
                         if not d.startswith("_run-") and d != "fromATLAStoSolver")
        found += [os.path.join(root, f) for f in sorted(files) if f.endswith(".ini")]
    return found


def icb_owned(sections):
    """The sections of *sections* the ICB model owns, as comparable tuples."""
    zones = set(icmodel.zone_section_names(sections))
    return sorted((name, tuple(kv)) for name, kv in sections
                  if name.strip().startswith("ICB-") or name in zones)


class RoundTrip(unittest.TestCase):

    def test_decks_found(self):
        self.assertGreater(len(decks()), 60)

    def test_every_deck_keeps_its_icb_sections(self):
        checked = 0
        for path in decks():
            with self.subTest(deck=os.path.relpath(path, TEST_ROOT)):
                with open(path, encoding="utf-8") as handle:
                    text = handle.read()
                sections = _parse_ini(text)
                doc = AtlasDocument.from_ini(text)
                written = _parse_ini(doc.to_ini())
                self.assertEqual(icb_owned(written), icb_owned(sections))
                zones = set(icmodel.zone_section_names(sections))
                self.assertFalse(zones & set(doc.bcb.sections),
                                 "an ICB zone was read as a BC")
                checked += 1
        self.assertGreater(checked, 60)

    def test_multizone_deck_is_written_as_read(self):
        path = os.path.join(TEST_ROOT, "ICB", "IG-multizone", "input.ini")
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
        out = AtlasDocument.from_ini(text).to_ini()
        self.assertNotIn("type = wall", out)
        self.assertEqual(sorted(_parse_ini(out)), sorted(_parse_ini(text)))

    def test_bcb_alone_leaves_the_zones(self):
        text = ("[ICB-Block*]\ndirection = x\nzone1 = hot\nrange1 = 0 1\n\n"
                "[hot]\nT = 900\n\n[inlet]\ntype = inlet\np0 = 2e5\n")
        self.assertEqual(list(BCBDocument.from_ini(text).sections), ["inlet"])


class Deck(unittest.TestCase):

    TEXT = """
[ATLAS-Parameters]
IC-format = tec

[ICB-Block*]
p = 101325
T = 300

[ICB-Block2]
phase = gas solid
direction = x
zone1 = left
range1 = 0 0.5
zone3 = orphan
range3 = 2 3
zone2 = right
range2 = 0.5 1

[left]
type = nozzle
p0 = 5e5
T0 = 450

[right]
old-solution = field.tec
interpolation-law = index

[orphan]
yN2-file = yN2.dat
yN2-direction = x
yO2 = 0.25
p = 1e5

[ICB-Block2]
T = 1

[ICB-Notes]
anything = kept

[inlet]
type = inlet
"""

    def setUp(self):
        self.doc = AtlasDocument.from_ini(self.TEXT)
        self.icb = self.doc.icb

    def test_sections_are_routed(self):
        self.assertEqual(list(self.icb.blocks), [2])
        self.assertIsNotNone(self.icb.wildcard)
        self.assertEqual(self.icb.zone_names(), ["left", "right", "orphan"])
        self.assertEqual(list(self.doc.bcb.sections), ["inlet"])
        self.assertEqual([n for n, _kv in self.icb.kept], ["ICB-Block2", "ICB-Notes"])
        self.assertEqual(self.doc.foreign, [])

    def test_wildcard_gives_the_blocks_without_a_section(self):
        self.assertIs(self.icb.block(1), self.icb.wildcard)
        self.assertIs(self.icb.block(2), self.icb.blocks[2])
        self.assertEqual(self.icb.block(1).mode, "uniform")

    def test_block_structure(self):
        block = self.icb.blocks[2]
        self.assertEqual(block.phases, ["gas", "solid"])
        self.assertTrue(block.is_split)
        self.assertEqual(block.state_keys(), [])
        self.assertEqual(block.zone_numbers(), [1, 2, 3])
        self.assertEqual(block.zone_refs(), [ICZoneRef("left", ["0", "0.5"]),
                                             ICZoneRef("right", ["0.5", "1"]),
                                             ICZoneRef("orphan", ["2", "3"])])
        self.assertFalse(self.icb.wildcard.is_split)

    def test_modes(self):
        zones = self.icb.zones
        self.assertEqual(zones["left"].mode, "nozzle")
        self.assertEqual(zones["right"].mode, "interpolate")
        self.assertEqual(zones["orphan"].mode, "uniform")
        self.assertTrue(zones["orphan"].is_variable())
        self.assertFalse(zones["right"].is_variable())
        state = ICState([("type", "nozzle"), ("p0", "1")])
        state.set_mode("interpolate")
        self.assertEqual(state.get("type"), "interpolation")
        state.set_mode("uniform")
        self.assertFalse(state.has("type"))
        state = ICState([("type", "homogeneous"), ("old-solution", "f.tec")])
        self.assertEqual(state.mode, "interpolate")
        state.set_mode("uniform")
        self.assertEqual(list(state.params.items()), [("type", "homogeneous")])
        with self.assertRaises(ValueError):
            state.set_mode("multizone")

    def test_species_keys(self):
        orphan = self.icb.zones["orphan"]
        self.assertEqual(orphan.species_keys(), ["yN2-file", "yN2-direction", "yO2"])
        self.assertEqual(dict(orphan.mass_fractions()), {"O2": "0.25"})
        self.assertEqual(orphan.profile_keys(), ["yN2-file"])
        self.assertEqual(icmodel.species_of_key("yAL2O3(L)"), "AL2O3(L)")
        self.assertEqual(icmodel.species_key_pattern("yN2-direction"), "yspecies-direction")
        for key in ("y", "p", "type", "eq-CEA-file"):
            self.assertEqual(icmodel.species_key_pattern(key), "", key)

    def test_set_zones_renumbers_in_order(self):
        block = self.icb.blocks[2]
        refs = block.zone_refs()
        block.set_zones("x", [refs[1], refs[0]])
        self.assertEqual(list(block.params.items()), [
            ("phase", "gas solid"), ("direction", "x"),
            ("zone1", "right"), ("range1", "0.5 1"),
            ("zone2", "left"), ("range2", "0 0.5")])
        self.icb.drop_unused_zones()
        self.assertEqual(self.icb.zone_names(), ["left", "right"])
        block.set_zones("x", [])
        self.assertFalse(block.is_split)

    def test_rename_zone_follows_the_references(self):
        self.icb.rename_zone("left", "plenum")
        self.assertEqual(self.icb.zone_names(), ["plenum", "right", "orphan"])
        self.assertEqual(self.icb.blocks[2].get("zone1"), "plenum")
        self.assertIn("[plenum]\ntype = nozzle", self.doc.to_ini())

    def test_own_block_and_removal(self):
        block = self.icb.own_block(1)
        self.assertEqual(list(self.icb.blocks), [1, 2])
        self.assertIs(self.icb.block(1), block)
        self.icb.remove_block(2)
        self.assertEqual(self.icb.zone_names(), [])
        self.assertIs(self.icb.block(2), self.icb.wildcard)

    def test_section_names_cover_every_tool(self):
        names = self.doc.section_names()
        for name in ("ATLAS-Parameters", "ICB-Block*", "ICB-Block2", "left",
                     "orphan", "ICB-Notes", "inlet"):
            self.assertIn(name, names)

    def test_written_order(self):
        names = [n for n, _kv in _parse_ini(self.doc.to_ini())]
        self.assertEqual(names, ["ATLAS-Parameters", "inlet", "ICB-Block*", "ICB-Block2",
                                 "left", "right", "orphan", "ICB-Block2", "ICB-Notes"])

    def test_zone_never_claims_another_tools_section(self):
        sections = _parse_ini("[ICB-Block1]\ndirection = x\nzone1 = ATLAS-Parameters\n"
                              "zone2 = ICB-Block2\nzone3 = STB-Grid\nzone4 = ok\n")
        self.assertEqual(icmodel.zone_section_names(sections), ["ok"])


class StateChoices(unittest.TestCase):

    def test_numbers_as_icb_reads_them(self):
        for text, value in (("101325", 101325.0), ("70d+5", 7e6), ("1.5D-3", 1.5e-3),
                            ("0.20,", 0.2), ("2*20e-6", 20e-6), (" 300 ", 300.0)):
            self.assertAlmostEqual(icmodel.to_float(text), value, msg=text)
        for text in ("", "abc", "nan", "inf", "0*3", "x*2", "1e"):
            self.assertIsNone(icmodel.to_float(text), text)

    def test_gas_pairs(self):
        state = ICState([("p0", "2e5"), ("T0", "400"), ("mach", "0.3")])
        self.assertEqual(icmodel.gas_pair(state), "p0-T0")
        self.assertEqual(icmodel.gas_pair(ICState([("p", "1"), ("T0", "2")])), "p-T0")
        self.assertEqual(icmodel.gas_pair(ICState([("T-file", "T.dat"), ("rho", "1")])), "T-rho")
        self.assertEqual(icmodel.gas_pair(ICState()), "p-T")
        state = ICState([("p", "1"), ("T", "2"), ("T-file", "T.dat"),
                         ("T-direction", "x"), ("yN2", "1")])
        icmodel.set_gas_pair(state, "p-rho")
        self.assertEqual(list(state.params), ["p", "yN2"])
        state = ICState([("p", "7e6"), ("h", "1e5")])
        self.assertEqual(icmodel.gas_pair(state, icmodel.REAL_FLUID_PAIRS), "p-h")

    def test_velocity(self):
        state = ICState([("mach", "0.3"), ("alpha", "0.5"), ("u", "10")])
        self.assertEqual(icmodel.velocity_mode(state), "components")
        icmodel.set_velocity_mode(state, "components")
        self.assertEqual(list(state.params), ["u"])
        state = ICState([("vel", "20"), ("v", "1")])
        icmodel.set_velocity_mode(state, "speed", "RF")
        self.assertEqual(list(state.params), ["vel"])

    def test_turbulence(self):
        self.assertEqual(icmodel.turbulence_model(ICState([("k", "1")])), 2)
        self.assertEqual(icmodel.turbulence_model(ICState([("rhoRij", "1"), ("k", "1")])), 7)
        self.assertEqual(icmodel.turbulence_model(ICState([("nuTilde", "1")])), 1)
        self.assertEqual(icmodel.turbulence_model(ICState([("nrans", "2"), ("nuTilde", "1")])), 2)
        self.assertEqual(icmodel.turbulence_model(ICState()), 0)
        state = ICState([("k", "1"), ("omega", "100"), ("p", "1")])
        self.assertFalse(icmodel.turbulence_weighted(state))
        icmodel.set_turbulence(state, 2, True)
        self.assertEqual(list(state.params.items()), [("p", "1"), ("nrans", "2")])
        state = ICState([("Rij", "1"), ("omega", "100"), ("nrans", "7")])
        icmodel.set_turbulence(state, 0, False)
        self.assertEqual(list(state.params), [])

    def test_summary(self):
        self.assertEqual(ICState([("p", "1e5"), ("T", "300")]).summary(),
                         "Uniform  ·  p 1e5  ·  T 300")
        self.assertEqual(ICState([("type", "nozzle"), ("p0", "5e5"), ("T0", "450")]).summary(),
                         "Nozzle flow  ·  p0 5e5  ·  T0 450")
        self.assertEqual(ICState([("old-solution", "run/field.tec")]).summary(),
                         "Interpolate  ·  field.tec")
        self.assertEqual(ICState().summary(), "Uniform  ·  no state yet")


class Phases(unittest.TestCase):

    def test_phase_files(self):
        root = os.path.join(TEST_ROOT, "ICB", "IG+DP")
        self.assertEqual(icmodel.read_phase_file(os.path.join(root, "particles-phase.txt")),
                         ("DP", ["AL2O3(L)"], [1]))
        self.assertEqual(icmodel.phase_name_of_file("a/b/gas-phase.txt"), "gas")
        self.assertEqual(icmodel.phase_name_of_file("phase.txt"), "")
        phases = icmodel.case_phases(None, root)
        self.assertEqual([(p.name, p.kind, p.entries) for p in phases],
                         [("gas", "IG", ["N2"]), ("particles", "DP", ["AL2O3(L)"])])

    def test_deck_phases_come_first_and_keep_their_kind(self):
        doc = AtlasDocument.from_ini(
            "[GPB-Phase1]\nname = air\ntype = ideal-gas\nspecies = O2 N2\n\n"
            "[GPB-Phase2]\nname = wall\ntype = solid\nmaterial = steel copper\n")
        root = os.path.join(TEST_ROOT, "ICB", "IG+SP")      # holds gas- and solid-phase.txt
        phases = icmodel.case_phases(doc.gpb, root)
        self.assertEqual([(p.name, p.kind) for p in phases][:2], [("air", "IG"), ("wall", "SP")])
        self.assertEqual(phases[0].entries, ["O2", "N2"])
        self.assertEqual(phases[1].entries, ["steel", "copper"])
        self.assertEqual(phases[0].source, "deck")
        self.assertEqual({p.name for p in phases[2:]}, {"gas", "solid"})
        looked_up = icmodel.case_phases(
            AtlasDocument.from_ini("[GPB-Phase1]\nname = g\nreactions = h2o2\n").gpb,
            None, lambda phase: ["H2", "O2"])
        self.assertEqual(looked_up[0].entries, ["H2", "O2"])

    def test_phase_renames_reach_the_blocks(self):
        doc = AtlasDocument.from_ini("[ICB-Block1]\nphase = gas particles\n\n"
                                     "[ICB-Block*]\nphase = gas\n")
        doc.icb.rename_phase("gas", "air")
        self.assertEqual(doc.icb.blocks[1].phases, ["air", "particles"])
        self.assertEqual(doc.icb.wildcard.phases, ["air"])
        doc.icb.drop_phase("air")
        self.assertEqual(doc.icb.blocks[1].phases, ["particles"])
        self.assertFalse(doc.icb.wildcard.has("phase"))


# Decks ICB stops on that the checks must catch from the deck alone (the
# other refusal decks of the suite need the mesh or the source file).
REFUSED = ("ICB-type-refused/input.ini", "IG+DP/particles-only.ini",
           "IG+DP/phase-undeclared.ini", "IG-state-not-physical/input.ini",
           "IG-turbulence-specific/both.ini", "IG-turbulence-specific/eddy.ini",
           "IG-turbulence-specific/retired.ini", "IG-turbulence-zero-refused/input.ini",
           "IG-interp-species/input.ini", "IG-interp-species-decomposition/input.ini",
           "IG-total-conditions/both.ini", "IG-multizone/range-tab.ini",
           "IG-profile-zones/both.ini", "IG-profile-zones/dironly.ini")

# Decks the suite runs with the phase files of another case.
PHASES_FROM = {"IG-profile-zones/solid.ini": "IG+SP"}


class Checks(unittest.TestCase):

    def validate(self, text, nblocks=1, phases=None, strict=True):
        doc = AtlasDocument.from_ini(text)
        phases = phases if phases is not None else [
            icmodel.PhaseInfo("", "IG", ["H2", "O2", "N2"])]
        return [(level, message) for level, _t, message
                in doc.icb.validate(nblocks, phases, strict)]

    def test_icb_decks(self):
        """No deck ICB accepts is flagged, and the refusals above are caught."""
        root = os.path.join(TEST_ROOT, "ICB")
        for path in decks():
            name = os.path.relpath(path, root)
            if name.startswith(".."):
                continue
            with self.subTest(deck=name):
                with open(path, encoding="utf-8") as handle:
                    doc = AtlasDocument.from_ini(handle.read())
                if doc.icb.is_empty():
                    continue
                strict = doc.parameters.get("strict-keys", "T").strip().upper() != "F"
                case_dir = os.path.dirname(path)
                if name in PHASES_FROM:
                    case_dir = os.path.join(root, PHASES_FROM[name])
                phases = icmodel.case_phases(doc.gpb, case_dir)
                errors = [m for level, _t, m in doc.icb.validate(0, phases, strict)
                          if level == "error"]
                if name in REFUSED:
                    self.assertTrue(errors, "ICB refuses this deck")
                else:
                    self.assertEqual(errors, [])

    def test_block_without_a_state(self):
        issues = self.validate("[ICB-Block1]\np = 1e5\nT = 300\nyN2 = 1\n", nblocks=2)
        self.assertIn(("error", "Block 2 has no initial state: ICB stops on it. Give the "
                                "block a state, or give All blocks one"), issues)

    def test_speed_given_once(self):
        def errors(keys):
            return [m for level, m in self.validate(
                "[ICB-Block*]\np0 = 5e5\nT0 = 1200\nyN2 = 1\n" + keys) if level == "error"]
        self.assertEqual(errors("u = 855.8\nv = 585.5\n"), [])     # ICB expands T0 at that speed
        self.assertEqual(errors("mach = 2\nalpha = 0.6\n"), [])
        self.assertEqual(errors("mach = 2\nu = 0\n"), [])           # zero components are no speed
        self.assertTrue(any("both give the speed" in m for m in errors("mach = 2\nu = 855.8\n")))

    def test_zone_layout(self):
        zones = "\n[a]\np = 1e5\nT = 300\nyN2 = 1\n[b]\np = 2e5\nT = 300\nyN2 = 1\n"

        def errors(block):
            return [m for level, m in self.validate("[ICB-Block1]\n" + block + zones)
                    if level == "error"]
        good = "direction = x\nzone1 = a\nrange1 = 0 0.5\nzone2 = b\nrange2 = 0.5 1\n"
        self.assertEqual(errors(good), [])
        self.assertTrue(any("needs the key direction" in m for m in errors(
            "type = multizone\nzone1 = a\nrange1 = 0 1\n")))
        self.assertTrue(any("not a direction letter" in m for m in errors(
            "direction = q\nzone1 = a\nrange1 = 0 1\n")))
        self.assertTrue(any("in the order x, y, z" in m for m in errors(
            "direction = yx\nzone1 = a\nrange1 = 0 1 0 1\n")))
        self.assertTrue(any("needs 4" in m for m in errors(
            "direction = xy\nzone1 = a\nrange1 = 0 1\n")))
        self.assertTrue(any("comma" in m for m in errors(
            "direction = x\nzone1 = a\nrange1 = 0, 1\n")))
        self.assertTrue(any("zone3 is never read" in m for m in errors(
            "direction = x\nzone1 = a\nrange1 = 0 1\nzone3 = b\nrange3 = 0 1\n")))
        self.assertTrue(any("zone1 is missing" in m for m in errors(
            "direction = x\nzone2 = a\nrange2 = 0 1\n")))
        self.assertTrue(any("no range2" in m for m in errors(
            "direction = x\nzone1 = a\nrange1 = 0 1\nzone2 = b\n")))
        self.assertTrue(any("names no section" in m for m in errors(
            "direction = x\nzone1 = nowhere\nrange1 = 0 1\n")))
        turbulent = zones.replace("[b]\n", "[b]\nk = 1\nomega = 100\n").replace(
            "[a]\n", "[a]\nnuTilde = 1e-5\n")
        issues = [m for level, m in self.validate("[ICB-Block1]\n" + good + turbulent)
                  if level == "error"]
        self.assertTrue(any("different turbulence models" in m for m in issues))

    def test_zone_issue_targets(self):
        doc = AtlasDocument.from_ini(
            "[ICB-Block1]\ndirection = x\nzone1 = a\nrange1 = 0 1\n[a]\np = 1e5\nyN2 = 1\n")
        targets = {t for _l, t, _m in doc.icb.validate(1, [icmodel.PhaseInfo("", "IG", ["N2"])])}
        self.assertIn((1, "a"), targets)          # the zone's own state: its pair

    def test_composition(self):
        def errors(keys):
            return [m for level, m in self.validate("[ICB-Block*]\np = 1e5\nT = 300\n" + keys)
                    if level == "error"]
        self.assertEqual(errors("yO2 = 0.233\nyN2 = 0.767\n"), [])
        self.assertTrue(any("sum to 0.9" in m for m in errors("yO2 = 0.2\nyN2 = 0.7\n")))
        self.assertTrue(any("no species Ar" in m for m in errors("yAr = 1\n")))
        self.assertTrue(any("no composition" in m for m in errors("")))
        self.assertEqual(errors("eq-CEA-file = air.inp\n"), [])
        warnings = [m for level, m in self.validate(
            "[ICB-Block*]\np = 1e5\nT = 300\nyO2 = 0.2335\nyN2 = 0.767\n") if level == "warning"]
        self.assertTrue(any("renormalises" in m for m in warnings))

    def test_modes_and_phases(self):
        gas = icmodel.PhaseInfo("gas", "IG", ["N2"])
        fluid = icmodel.PhaseInfo("fluid", "RF", ["Water"])
        solid = icmodel.PhaseInfo("wall", "SP", ["steel"])
        def errors(text, phases):
            return [m for level, m in self.validate(text, 1, phases) if level == "error"]
        self.assertTrue(errors("[ICB-Block1]\ntype = nozzle\np0 = 1e5\n", [gas]))
        self.assertTrue(any("builds none" in m for m in errors(
            "[ICB-Block1]\nphase = wall\ntype = nozzle\nT = 300\n", [gas, solid])))
        self.assertTrue(any("needs p and T" in m for m in errors(
            "[ICB-Block1]\nphase = fluid\np = 7e6\n", [fluid])))
        self.assertTrue(any("carries no" in m for m in errors(
            "[ICB-Block1]\nphase = fluid\np = 7e6\nT = 400\nk = 1\nomega = 10\n", [fluid])))
        self.assertTrue(any("old-solution" in m for m in errors(
            "[ICB-Block1]\ntype = interpolation\n", [gas])))
        self.assertEqual(errors("[ICB-Block1]\nold-solution = f.tec\n", [gas]), [])
        self.assertTrue(any("must move into a zone" in m for m in errors(
            "[ICB-Block1]\ndirection = x\nzone1 = a\nrange1 = 0 1\np = 1\n\n[a]\n"
            "p = 1e5\nT = 300\n", [gas])))

    def test_unread_keys(self):
        text = "[ICB-Block*]\np = 1e5\nT = 300\nyN2 = 1\nlaw = index\n"
        self.assertTrue(any(level == "error" and "write interpolation-law" in m
                            for level, m in self.validate(text)))
        self.assertTrue(any(level == "warning" and "law" in m
                            for level, m in self.validate(text, strict=False)))

    def test_unread_key_hints_as_icb(self):
        """An unread key gets ICB's hint: the key it differs from in letter
        case or by a letter or two (ICB reads keys case-sensitively)."""
        found = self.validate("[ICB-Block*]\np = 1e5\nT = 300\nyN2 = 1\nnrans = 2\n"
                              "rhok = 1\nrhoomega = 100\nyn2 = 0\n")
        for key, hint in (("rhok", "rhoK"), ("rhoomega", "rhoOmega")):
            self.assertIn(("error", f"All blocks: ICB reads no key {key}: did you mean {hint}?"),
                          found)
        # a y of a species the gas does not declare: ICB names the declared ones
        self.assertIn(("error", "All blocks: the gas declares no species n2 (its species: H2, "
                                "O2, N2): did you mean yN2?"), found)
        self.assertEqual(icmodel.closest_key("xyzzy"), "")
        self.assertEqual(icmodel.closest_key("old-solutoin"), "old-solution")

    def test_boundaries_refuse_density_weighted_turbulence(self):
        """BCB refuses the density-weighted turbulence of an ICB zone in a BC,
        and the keys of earlier decks, each with its reason."""
        doc = AtlasDocument.from_ini("[BCB-Block1]\nface1 = inlet\n\n[inlet]\ntype = inlet\n"
                                     "k = 1\nrhoK = 1\nrhoOmega = 2\nkappa = 1\n")
        refused = doc.bcb.refused_keys()
        self.assertEqual([(name, key) for name, key, _why in refused],
                         [("inlet", "rhoK"), ("inlet", "rhoOmega"), ("inlet", "kappa")])
        self.assertIn("a boundary takes the specific k", refused[0][2])


class Profiles(unittest.TestCase):

    def test_table_as_icb_reads_it(self):
        from atlasgui import icprofile
        table = icprofile.parse_table("# x T\n\n0.0 400\n0.5, 450 ! comment\nx T\n1d0 500 7\n")
        self.assertEqual(table.coords, [0.0, 0.5, 1.0])
        self.assertEqual(table.values, [400.0, 450.0, 500.0])
        levels = [level for level, _t in table.problems]
        self.assertEqual(levels, ["warning", "warning"])     # three numbers; a word row
        down = icprofile.parse_table("1 10\n0.5 5\n0 0\n")
        self.assertEqual(down.coords, [0.0, 0.5, 1.0])       # reversed, as ICB does
        bad = icprofile.parse_table("0 1\n1 2\n0.5 3\n")
        self.assertFalse(bad.ok)
        self.assertIn("not monotone at row 3", bad.problems[0][1])
        self.assertFalse(icprofile.parse_table("# nothing\n").ok)
        self.assertEqual(icprofile.parse_table("0 2*5\n1 1\n").values, [5.0, 1.0])

    def test_field_header(self):
        import tempfile
        from atlasgui import icprofile
        with tempfile.TemporaryDirectory() as tmp:
            good = os.path.join(tmp, "f.tec")
            with open(good, "w") as handle:
                handle.write('VARIABLES = "x" "y" "p" "T"\nZONE I=3, J=2, K=1, '
                             'DATAPACKING=BLOCK, VARLOCATION=([3-4]=CELLCENTERED)\n0\n')
            field = icprofile.read_field(good)
            self.assertEqual((field.coordinates, field.value, field.zones), (2, "p", [(3, 2, 1)]))
            self.assertTrue(field.ok and field.cell_centred)
            nodal = os.path.join(tmp, "n.tec")
            with open(nodal, "w") as handle:
                handle.write('VARIABLES = x y z p\nZONE I=2, J=2, K=2\n0\n')
            self.assertFalse(icprofile.read_field(nodal).ok)
            self.assertFalse(icprofile.read_field(os.path.join(tmp, "p.dat")).ok)

    def test_deck_checks(self):
        def issues(keys, mode=""):
            doc = AtlasDocument.from_ini("[ICB-Block1]\np = 1e5\nyN2 = 1\n" + mode + keys)
            return [(level, m) for level, _t, m in
                    doc.icb.validate(1, [icmodel.PhaseInfo("", "IG", ["N2"])])]
        self.assertEqual([i for i in issues("T-file = t.dat\nT-direction = x\n")
                          if i[0] == "error"], [])
        self.assertTrue(any("both given" in m for _l, m in issues("T = 300\nT-file = t.dat\n")))
        self.assertTrue(any("without T-file" in m for _l, m in issues("T = 300\nT-direction = x\n")))
        self.assertTrue(any("x, y, z, r or t" in m for _l, m in
                            issues("T-file = t.dat\nT-direction = i\n")))
        self.assertTrue(any(level == "warning" and "nozzle law" in m for level, m in
                            issues("T0 = 300\np0 = 1e5\nT0-file = t.dat\n", "type = nozzle\n")))
        state = ICState({"T": "300"})
        icmodel.set_profile(state, "T", "t.dat", "x")
        self.assertEqual(dict(state.params), {"T-file": "t.dat", "T-direction": "x"})
        icmodel.clear_profile(state, "T", "310")
        self.assertEqual(dict(state.params), {"T": "310"})


class Schema(unittest.TestCase):

    def test_reference_found(self):
        self.assertTrue(icmodel.SCHEMA_FOUND, icmodel._REFERENCE_PATH)
        for table in ["ICB-Block*", "ICB-Composition"] + list(icmodel.KIND_TABLES.values()):
            self.assertIn(table, icmodel.REFERENCE)

    def test_the_keys_the_gui_names_are_icb_keys(self):
        for kind, fields in icmodel.PROFILE_FIELDS.items():
            keys = icmodel.kind_keys(kind)
            for field in fields:
                for key in (field, f"{field}-file", f"{field}-direction"):
                    self.assertIn(key, keys, f"{kind}: {key}")
        for key in icmodel.INTERPOLATION_KEYS + icmodel.NOZZLE_KEYS:
            self.assertIn(key, icmodel.kind_keys("IG"), key)
        block_keys = icmodel.REFERENCE["ICB-Block*"]
        for key in icmodel.STRUCTURAL_KEYS:
            self.assertIn(key, block_keys, key)
        self.assertEqual(icmodel.allowed_values("type"), list(icmodel.ICB_TYPES))
        self.assertEqual(icmodel.allowed_values("T-direction", "IG"),
                         list(icmodel.PROFILE_DIRECTIONS))

    def test_every_gpb_phase_type_has_a_kind(self):
        for phase_type, _label, _family, _blurb in gpbmodel.PHASE_TYPES:
            self.assertIn(phase_type, icmodel.KIND_OF_TYPE, phase_type)

    def test_species_keys_read_the_species_rows(self):
        self.assertIn("Mass-fraction profile", icmodel.describe("yH2-file", "IG"))
        self.assertIn("Mass fraction", icmodel.describe("yH2", "IG"))


if __name__ == "__main__":
    unittest.main()
