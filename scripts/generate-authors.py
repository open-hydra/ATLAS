#!/usr/bin/env python3

from pathlib import Path
import subprocess
import yaml

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
CONFIG = SCRIPT_DIR / "contributors.yml"
OUTPUT = REPO_ROOT / "AUTHORS.md"

with open(CONFIG, "r", encoding="utf-8") as f:
    cfg = yaml.safe_load(f)

maintainers = cfg.get("maintainers", [])
alumni = cfg.get("alumni", [])
exclude = set(cfg.get("exclude", []))

result = subprocess.check_output(
    ["git", "shortlog", "-sne", "--all"],
    text=True,
)

contributors = []

for line in result.splitlines():
    line = line.strip()

    if not line:
        continue

    # Match previous pipeline filtering that excluded bot-generated identities.
    if "dependabot" in line.lower() or "github-actions" in line.lower():
        continue

    _, identity = line.split("\t", 1)

    name = identity.split("<")[0].strip()

    if name in exclude:
        continue

    contributors.append(name)

maintainer_names = {m["name"] for m in maintainers}
alumni_names = set(alumni)

contributors = sorted(
    set(contributors)
    - maintainer_names
    - alumni_names
)

with open(OUTPUT, "w", encoding="utf-8") as f:
    f.write("# Authors\n\n")

    f.write("## Core Maintainers\n\n")

    for m in maintainers:
        f.write(f'- {m["name"]} — {m["role"]}\n')

    f.write("\n## Contributors\n\n")

    for c in contributors:
        f.write(f"- {c}\n")

    if alumni:
        f.write("\n## Alumni\n\n")

        for a in alumni:
            f.write(f"- {a}\n")

print(f"Generated {OUTPUT}")