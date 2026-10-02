import json
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parents[1]
version = (root / "VERSION").read_text().strip()
assert re.fullmatch(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", version)
assert re.search(r"^## \[" + re.escape(version) + r"\] - \d{4}-\d{2}-\d{2}$", (root / "CHANGELOG.md").read_text(), re.M)
metadata = json.loads((root / "marketplace-metadata.json").read_text())
assert metadata["directory"] == root.name
assert 45 <= len(metadata["description"]) <= 75
assert not ({"id", "code", "distributionRepo"} & metadata.keys())
assert metadata["icon"].startswith("https://")
for origin in metadata["origins"]:
    assert origin["url"] in (root / "README.md").read_text()
for heading in ["# Deploy and Host", "## About Hosting", "## Why Deploy", "## Common Use Cases", "## Dependencies for", "### Deployment Dependencies"]:
    assert heading in (root / "MARKETPLACE.md").read_text()
package = json.loads((root / "package.json").read_text())
lock = json.loads((root / "package-lock.json").read_text())
assert package["devDependencies"]["railway"] == "3.6.0"
assert lock["packages"]["node_modules/railway"]["version"] == "3.6.0"
for scope in ["dependencies", "devDependencies"]:
    for name, pin in package.get(scope, {}).items():
        assert re.fullmatch(r"\d+\.\d+\.\d+", pin), (name, pin)
        assert lock["packages"]["node_modules/" + name]["version"] == pin
required = [".env.example", ".gitignore", ".dockerignore", ".railway/railway.ts", "Dockerfile", "compose.yaml", "VERSION", "CHANGELOG.md", "README.md", "MARKETPLACE.md", "PUBLISHING.md", "SUPPORT.md", "UPGRADE.md", "LICENSE_REVIEW.md", "package.json", "package-lock.json", "marketplace-metadata.json", "template-defaults.json", "template-descriptions.json", "template-networking.json", "template-volumes.json", "scripts/verify.sh", "scripts/smoke.sh", "scripts/local-smoke.sh", "scripts/audit-template.sh", "scripts/restore-template-draft.sh", "tests/test_draft_tools.py"]
for name in required:
    assert (root / name).is_file(), name
readme = (root / "README.md").read_text()
defaults = json.loads((root / "template-defaults.json").read_text())
descriptions = json.loads((root / "template-descriptions.json").read_text())
for service, variables in defaults.items():
    assert set(variables) == set(descriptions[service])
    for key in variables:
        assert key in readme and descriptions[service][key]
for line in (root / "Dockerfile").read_text().splitlines():
    if line.startswith("FROM "):
        assert "@sha256:" in line, line
compose = (root / "compose.yaml").read_text()
assert "docker.sock" not in compose and "privileged:" not in compose
for image in re.findall(r"^\s+image: (.+)$", compose, re.M):
    assert "@sha256:" in image
assert "127.0.0.1:" in compose
for path in root.rglob("*"):
    if any(part in {"node_modules", ".venv", "__pycache__"} for part in path.relative_to(root).parts):
        continue
    assert path.name != ".env" and not path.name.endswith(".local"), path
print("Version, metadata, pins, required documentation and private-state contract passed")
