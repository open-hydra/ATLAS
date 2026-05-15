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

original_authors = cfg.get("original_authors", [])
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

original_author_names = {a["name"] for a in original_authors}

contributors = sorted(
    set(contributors)
    - original_author_names
)

def format_author_link(name, github_username):
    """Format author name with optional GitHub link."""
    if github_username:
        return f"[{name}](https://github.com/{github_username})"
    return name

with open(OUTPUT, "w", encoding="utf-8") as f:
    f.write("# Authors\n\n")

    if original_authors:
        f.write("## Original Authors\n\n")
        for a in original_authors:
            github_user = a.get("github_username", "")
            link = format_author_link(a["name"], github_user)
            f.write(f"- {link}\n")

    f.write("\n## Contributors\n\n")
    f.write("Automatically sourced from git history.\n\n")
    for c in contributors:
        f.write(f"- {c}\n")

print(f"Generated {OUTPUT}")