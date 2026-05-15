from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
import re

import numpy as np
import cea


@dataclass
class _SpeciesResult:
    name: list[str] = field(default_factory=list)
    massf: list[float] = field(default_factory=list)


@dataclass
class _StateResult:
    species: _SpeciesResult = field(default_factory=_SpeciesResult)
    temperature: float = 0.0
    pressure: float = 0.0
    h0: float = 0.0


@dataclass
class _ReactantEntry:
    kind: str
    reactant: object
    amount_kind: str
    amount: float


@dataclass
class _ProblemSpec:
    kind: str
    pressure_bar: float
    reactants: list[_ReactantEntry]
    only: list[str]
    omit: list[str]
    tc: float | None = None
    hc: float | None = None
    tc_est: float | None = None
    n_frz: int | None = None
    temperature: float | None = None


class CEA:
    def __init__(self):
        self.indx = 1
        self.OG = False
        self.SE = _StateResult()

    def solve(self, filename: str):
        input_path = _resolve_input_path(filename)
        problems = _split_problem_blocks(input_path.read_text())
        if self.indx < 1 or self.indx > len(problems):
            raise IndexError(f"CEA section {self.indx} is out of range for {input_path}")

        spec = _parse_problem(problems[self.indx - 1])
        result = _solve_problem(spec, gas_only=self.OG)
        self.SE = _StateResult(
            species=_SpeciesResult(
                name=result["names"],
                massf=result["massf"],
            ),
            temperature=result["temperature"],
            pressure=result["pressure"],
            h0=result["h0"],
        )


def _resolve_input_path(filename: str) -> Path:
    path = Path(filename)
    if path.suffix.lower() != ".inp":
        path = path.with_suffix(".inp")
    return path


def _split_problem_blocks(text: str) -> list[list[str]]:
    blocks: list[list[str]] = []
    current: list[str] = []

    for raw_line in text.splitlines():
        line = raw_line.split("#", 1)[0].rstrip()
        if not line.strip():
            continue
        lower = line.lstrip().lower()
        if lower.startswith("problem") and current:
            blocks.append(current)
            current = []
        current.append(line)
        if lower.startswith("end"):
            blocks.append(current)
            current = []

    if current:
        blocks.append(current)

    return blocks


def _parse_problem(lines: list[str]) -> _ProblemSpec:
    datasets: dict[str, list[str]] = {"problem": [], "react": [], "only": [], "omit": []}
    current = "problem"

    for line in lines:
        stripped = line.strip()
        lowered = stripped.lower()
        if lowered.startswith("problem"):
            current = "problem"
        elif lowered.startswith("react"):
            current = "react"
        elif lowered.startswith("only"):
            current = "only"
        elif lowered.startswith("omit"):
            current = "omit"
        elif lowered.startswith("output"):
            current = "output"
        elif lowered.startswith("end"):
            current = "end"
        if current in datasets:
            datasets[current].append(stripped)

    problem_text = " ".join(datasets["problem"])
    lower_problem = problem_text.lower()
    if "rocket" in lower_problem:
        kind = "rocket"
    else:
        match = re.search(r"\b(tp|hp|sp|tv|uv|sv)\b", lower_problem)
        if match is None:
            raise ValueError("Unsupported CEA problem type")
        kind = match.group(1)

    pressure_bar = _extract_float(problem_text, [r"p\(bar\)\s*=\s*([-+0-9.eE]+)", r"p,bar\s*=\s*([-+0-9.eE]+)"])
    tc = _extract_optional_float(problem_text, [r"t\(k\)\s*=\s*([-+0-9.eE]+)", r"t,k\s*=\s*([-+0-9.eE]+)"])
    tc_est = _extract_optional_float(problem_text, [r"tcest\(k\)\s*=\s*([-+0-9.eE]+)", r"tcest,k\s*=\s*([-+0-9.eE]+)"])
    n_frz = _extract_optional_int(problem_text, [r"nfz\s*=\s*(\d+)"])
    hc_match = re.search(r"h,([^=\s]+)\s*=\s*([-+0-9.eE]+)", problem_text, re.IGNORECASE)
    hc = float(hc_match.group(2)) if hc_match else None

    reactants = _parse_reactants(datasets["react"])
    only = _parse_species_dataset(datasets["only"])
    omit = _parse_species_dataset(datasets["omit"])

    return _ProblemSpec(
        kind=kind,
        pressure_bar=pressure_bar,
        reactants=reactants,
        only=only,
        omit=omit,
        tc=tc,
        hc=hc,
        tc_est=tc_est,
        n_frz=n_frz,
        temperature=tc,
    )


def _parse_reactants(lines: list[str]) -> list[_ReactantEntry]:
    entries: list[str] = []
    current = ""

    for line in lines[1:]:
        stripped = line.strip()
        lower = stripped.lower()
        if lower.startswith(("fuel=", "oxid=", "name=")):
            if current:
                entries.append(current)
            current = stripped
        elif current:
            current = f"{current} {stripped}"
    if current:
        entries.append(current)

    parsed: list[_ReactantEntry] = []
    for entry in entries:
        kind_match = re.search(r"\b(fuel|oxid|name)\s*=\s*([^\s]+)", entry, re.IGNORECASE)
        if kind_match is None:
            raise ValueError(f"Unable to parse CEA reactant entry: {entry}")
        kind_key = kind_match.group(1).lower()
        name = kind_match.group(2)
        kind = {"fuel": "fu", "oxid": "ox", "name": "na"}[kind_key]

        amount_kind = "weight"
        amount = _extract_optional_float(entry, [r"wt%?\s*=\s*([-+0-9.eE]+)"])
        if amount is None:
            amount = _extract_optional_float(entry, [r"moles?\s*=\s*([-+0-9.eE]+)"])
            amount_kind = "mole"
        if amount is None:
            amount = 1.0

        temperature = _extract_optional_float(entry, [r"t\(k\)\s*=\s*([-+0-9.eE]+)", r"t,k\s*=\s*([-+0-9.eE]+)"])
        enthalpy_match = re.search(r"h,([^=\s]+)\s*=\s*([-+0-9.eE]+)", entry, re.IGNORECASE)
        enthalpy = None
        enthalpy_units = None
        if enthalpy_match:
            enthalpy_units = _normalize_enthalpy_units(enthalpy_match.group(1))
            enthalpy = float(enthalpy_match.group(2))

        formula = _parse_formula(entry)
        reactant = cea.Reactant(
            name,
            formula=formula or None,
            enthalpy=enthalpy,
            enthalpy_units=enthalpy_units,
            temperature=temperature,
        )
        parsed.append(_ReactantEntry(kind=kind, reactant=reactant, amount_kind=amount_kind, amount=float(amount)))

    return parsed


def _parse_formula(entry: str) -> dict[str, float]:
    cleaned = entry
    patterns = [
        r"\b(fuel|oxid|name)\s*=\s*[^\s]+",
        r"wt%?\s*=\s*[-+0-9.eE]+",
        r"moles?\s*=\s*[-+0-9.eE]+",
        r"t\([^)]*\)\s*=\s*[-+0-9.eE]+",
        r"t,[^=\s]+\s*=\s*[-+0-9.eE]+",
        r"h,[^=\s]+\s*=\s*[-+0-9.eE]+",
    ]
    for pattern in patterns:
        cleaned = re.sub(pattern, " ", cleaned, flags=re.IGNORECASE)

    tokens = cleaned.split()
    formula: dict[str, float] = {}
    i = 0
    while i + 1 < len(tokens):
        element = tokens[i]
        coeff = tokens[i + 1]
        if re.fullmatch(r"[A-Za-z][A-Za-z]?", element) and _is_number(coeff):
            formula[element] = float(coeff)
            i += 2
        else:
            i += 1
    return formula


def _parse_species_dataset(lines: list[str]) -> list[str]:
    species: list[str] = []
    for line in lines[1:]:
        species.extend(line.split())
    return species


def _solve_problem(spec: _ProblemSpec, gas_only: bool) -> dict[str, object]:
    reactant_objects = [entry.reactant for entry in spec.reactants]
    reactants_mix = cea.Mixture(reactant_objects)
    if spec.only:
        products_mix = cea.Mixture(spec.only)
    else:
        products_mix = cea.Mixture(reactant_objects, products_from_reactants=True, omit=spec.omit)

    weights = np.array([entry.amount for entry in spec.reactants], dtype=np.float64)
    if any(entry.amount_kind == "mole" for entry in spec.reactants):
        if not all(entry.amount_kind == "mole" for entry in spec.reactants):
            raise ValueError("Mixed weight and mole CEA reactant amounts are not supported")
        weights = reactants_mix.moles_to_weights(weights)

    if spec.kind == "rocket":
        solver = cea.RocketSolver(products_mix, reactants=reactants_mix)
        solution = cea.RocketSolution(solver)
        solve_kwargs = {"pc": spec.pressure_bar}
        if spec.n_frz is not None:
            solve_kwargs["n_frz"] = spec.n_frz
        if spec.tc_est is not None:
            solve_kwargs["tc_est"] = spec.tc_est
        if spec.tc is not None:
            solve_kwargs["tc"] = spec.tc
        else:
            reactant_temps = np.array([
                entry.reactant.temperature if entry.reactant.temperature is not None else 298.15
                for entry in spec.reactants
            ], dtype=np.float64)
            solve_kwargs["hc"] = reactants_mix.calc_property(cea.ENTHALPY, weights, reactant_temps) / cea.R
        solver.solve(solution, weights, **solve_kwargs)
        names = list(products_mix.species_names)
        massf_map = solution.mass_fractions
        massf = np.array([float(massf_map[name][0]) for name in names], dtype=np.float64)
        temperature = float(solution.T[0])
        pressure = float(solution.P[0])
        h0 = float(solution.enthalpy[0]) * 1.0e3
    else:
        eq_map = {"tp": cea.TP, "hp": cea.HP, "sp": cea.SP, "tv": cea.TV, "uv": cea.UV, "sv": cea.SV}
        solve_kwargs = {"P": spec.pressure_bar, "reactants": reactant_objects}
        if spec.kind == "tp":
            solve_kwargs["T"] = spec.temperature
        elif spec.kind == "hp":
            solve_kwargs["H"] = spec.hc
        solution = cea.eq_solve(eq_map[spec.kind], only=spec.only or None, omit=spec.omit or None, **solve_kwargs)
        names = list(products_mix.species_names)
        massf_map = solution.mass_fractions
        massf = np.array([float(massf_map[name]) for name in names], dtype=np.float64)
        temperature = float(solution.T)
        pressure = float(solution.P)
        h0 = float(solution.enthalpy) * 1.0e3

    if gas_only:
        keep = ["(" not in name for name in names]
        names = [name for name, include in zip(names, keep) if include]
        massf = massf[keep]
        total = float(np.sum(massf))
        if total > 0.0:
            massf = massf / total

    return {
        "names": names,
        "massf": massf.tolist(),
        "temperature": temperature,
        "pressure": pressure,
        "h0": h0,
    }


def _extract_float(text: str, patterns: list[str]) -> float:
    value = _extract_optional_float(text, patterns)
    if value is None:
        raise ValueError(f"Unable to parse required value from CEA input: {text}")
    return value


def _extract_optional_float(text: str, patterns: list[str]) -> float | None:
    for pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            return float(match.group(1))
    return None


def _extract_optional_int(text: str, patterns: list[str]) -> int | None:
    for pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            return int(match.group(1))
    return None


def _normalize_enthalpy_units(unit: str) -> str:
    normalized = unit.strip().lower().replace("mole", "mol")
    mapping = {
        "j": "j/mol",
        "j/mol": "j/mol",
        "kj": "kj/mol",
        "kj/mol": "kj/mol",
        "cal": "cal/mol",
        "cal/mol": "cal/mol",
        "kcal": "kcal/mol",
        "kcal/mol": "kcal/mol",
    }
    if normalized not in mapping:
        raise ValueError(f"Unsupported reactant enthalpy units: {unit}")
    return mapping[normalized]


def _is_number(value: str) -> bool:
    try:
        float(value)
    except ValueError:
        return False
    return True
