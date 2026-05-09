#!/usr/bin/env python3
"""Spark-only guardrail scan for Optivus.

This scan is intentionally local and conservative. It fails on active deploy
targets, active package dependencies, and config keys that would reintroduce
Firebase Blaze-only or Google Cloud billing paths. It also reports wording that
future agents must review so legacy references stay clearly labeled.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

SKIP_DIRS = {
    ".dart_tool",
    ".git",
    ".gradle",
    ".idea",
    ".pub-cache",
    "__pycache__",
    "build",
    "node_modules",
}

FORBIDDEN_PUB_PACKAGES = {
    "cloud_functions",
    "firebase_functions",
    "firebase_storage",
    "firebase_storage_web",
    "google_maps_flutter",
    "google_maps_flutter_android",
    "google_maps_flutter_ios",
    "google_maps_flutter_platform_interface",
    "google_cloud",
    "googleapis_auth",
}

FORBIDDEN_CONFIG_TERMS = {
    "firebase cloud functions": "Firebase Cloud Functions",
    "firebase-functions": "firebase-functions",
    "cloud_functions": "cloud_functions",
    "firebase storage": "Firebase Storage",
    "firebase.storage": "firebase.storage",
    "firebase hosting": "Firebase Hosting",
    "app hosting": "App Hosting",
    "google maps": "Google Maps",
    "google_maps": "google_maps",
    "com.google.android.geo.api_key": "Google Maps Android API key",
    "cloud run": "Cloud Run",
    "cloud build": "Cloud Build",
    "artifact registry": "Artifact Registry",
    "google cloud secrets manager": "Google Cloud Secrets Manager",
    "secret manager": "Secret Manager",
    "google cloud vision": "Google Cloud Vision",
    "cloud vision": "Cloud Vision",
    "blaze": "Firebase Blaze",
}

REFERENCE_OK_MARKERS = (
    "spark-only",
    "spark-inactive",
    "legacy",
    "inactive",
    "forbidden",
    "disallowed",
    "do not",
    "must not",
    "no ",
    "not supported",
    "outside the optivus",
    "cloudflare",
    "mapbox",
    "r2",
    "replaces",
    "fallback",
    "without google maps",
    "no google maps",
    "no firebase storage",
)

DOC_REFERENCE_MARKERS = (
    "forbidden services",
    "disallowed google billing",
    "spark-only override",
    "historical reference only",
    "superseded",
    "legacy",
    "do not implement",
    "not implementation guidance",
)


def rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def iter_files() -> list[Path]:
    files: list[Path] = []
    for path in ROOT.rglob("*"):
        if path.is_dir():
            continue
        parts = set(path.relative_to(ROOT).parts)
        if parts & SKIP_DIRS:
            continue
        if path.name in {".DS_Store"}:
            continue
        files.append(path)
    return sorted(files)


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return path.read_text(encoding="utf-8", errors="ignore")


def add_failure(failures: list[str], path: Path, message: str) -> None:
    failures.append(f"{rel(path)}: {message}")


def add_warning(warnings: list[str], path: Path, line_no: int | None, message: str) -> None:
    location = rel(path) if line_no is None else f"{rel(path)}:{line_no}"
    warnings.append(f"{location}: {message}")


def check_firebase_json(failures: list[str], warnings: list[str]) -> None:
    path = ROOT / "firebase.json"
    if not path.exists():
        add_warning(warnings, path, None, "firebase.json is missing")
        return

    try:
        data = json.loads(read_text(path))
    except json.JSONDecodeError as exc:
        add_failure(failures, path, f"invalid JSON: {exc}")
        return

    forbidden_targets = {"functions", "storage", "hosting", "apphosting"}
    for target in forbidden_targets:
        if target in data:
            add_failure(
                failures,
                path,
                f"active forbidden Firebase deploy target `{target}` is configured",
            )

    encoded = json.dumps(data).lower()
    if "storage.rules" in encoded:
        add_failure(failures, path, "`storage.rules` is referenced by Firebase deploy config")

    firestore = data.get("firestore")
    if not isinstance(firestore, dict):
        add_warning(warnings, path, None, "Firestore rules/index deploy target is not configured")


def check_pubspec(failures: list[str]) -> None:
    path = ROOT / "pubspec.yaml"
    text = read_text(path)
    for line_no, line in enumerate(text.splitlines(), start=1):
        match = re.match(r"^\s*([a-zA-Z0-9_]+)\s*:", line)
        if match and match.group(1) in FORBIDDEN_PUB_PACKAGES:
            add_failure(
                failures,
                path,
                f"line {line_no}: forbidden Flutter dependency `{match.group(1)}`",
            )


def check_storage_rules_label(failures: list[str], warnings: list[str]) -> None:
    path = ROOT / "storage.rules"
    if not path.exists():
        return

    first_lines = "\n".join(read_text(path).splitlines()[:5]).lower()
    if "inactive" not in first_lines or "not referenced by firebase.json" not in first_lines:
        add_failure(
            failures,
            path,
            "storage.rules exists but is not clearly labeled inactive and unreferenced",
        )
    else:
        add_warning(
            warnings,
            path,
            None,
            "inactive legacy Firebase Storage rules file exists; firebase.json must keep not referencing it",
        )


def check_functions_legacy_label(failures: list[str]) -> None:
    functions_dir = ROOT / "functions"
    if not functions_dir.exists():
        return

    readme = functions_dir / "README.md"
    package_json = functions_dir / "package.json"

    readme_text = read_text(readme).lower() if readme.exists() else ""
    if not all(marker in readme_text for marker in ("legacy", "spark-inactive", "do not deploy")):
        add_failure(
            failures,
            readme,
            "`functions/` must be labeled legacy Spark-inactive and not deployable",
        )

    try:
        package = json.loads(read_text(package_json))
    except Exception as exc:  # noqa: BLE001 - guardrail should report parse failures
        add_failure(failures, package_json, f"cannot parse functions/package.json: {exc}")
        return

    description = str(package.get("description", "")).lower()
    if "legacy" not in description or "spark-inactive" not in description:
        add_failure(
            failures,
            package_json,
            "description must label package as legacy Spark-inactive reference",
        )

    scripts = package.get("scripts", {})
    for script_name in ("serve", "shell", "deploy", "logs"):
        script = str(scripts.get(script_name, "")).lower()
        if "disabled" not in script and "spark-inactive" not in script:
            add_failure(
                failures,
                package_json,
                f"`npm run {script_name}` must fail closed for legacy Firebase Functions",
            )


def check_android_manifests(failures: list[str]) -> None:
    manifest_root = ROOT / "android" / "app" / "src"
    if not manifest_root.exists():
        return

    map_key_patterns = (
        "com.google.android.geo.api_key",
        "com.google.android.maps.v2.api_key",
        "google_maps_api_key",
        "google_maps_key",
    )
    for path in manifest_root.rglob("AndroidManifest.xml"):
        lower = read_text(path).lower()
        for pattern in map_key_patterns:
            if pattern in lower:
                add_failure(failures, path, f"forbidden Google Maps key marker `{pattern}`")


def check_config_manifests(failures: list[str]) -> None:
    config_paths = [
        ROOT / "android" / "app" / "build.gradle.kts",
        ROOT / "android" / "build.gradle.kts",
        ROOT / "android" / "settings.gradle.kts",
    ]
    config_paths.extend((ROOT / "workers").glob("*/package.json"))
    config_paths.extend((ROOT / "workers").glob("*/wrangler.toml"))

    active_term_patterns = (
        "firebase-functions",
        "firebase_storage",
        "google_maps_flutter",
        "cloud run",
        "cloud build",
        "artifact registry",
        "google cloud secrets manager",
        "cloud vision",
    )
    for path in config_paths:
        if not path.exists():
            continue
        lower = read_text(path).lower()
        for pattern in active_term_patterns:
            if pattern in lower:
                add_failure(failures, path, f"forbidden active config term `{pattern}`")


def is_doc_or_todo(path: Path) -> bool:
    top = path.relative_to(ROOT).parts[0]
    return top in {"docs", "OPTIVUS Docs"} or path.name.startswith("todo_") or path.name == "GEMINI.md"


def check_wording_references(warnings: list[str]) -> None:
    for path in iter_files():
        if path.suffix.lower() in {".png", ".jpg", ".jpeg", ".mp3", ".lock", ".pyc"}:
            continue
        if path == Path(__file__).resolve():
            continue

        text = read_text(path)
        lower_text = text.lower()
        if not any(term in lower_text for term in FORBIDDEN_CONFIG_TERMS):
            continue

        if rel(path).startswith("functions/"):
            continue

        if path.name == "storage.rules":
            continue

        doc_has_label = any(marker in lower_text[:1500] for marker in DOC_REFERENCE_MARKERS)

        for line_no, line in enumerate(text.splitlines(), start=1):
            lower_line = line.lower()
            hits = [
                label
                for term, label in FORBIDDEN_CONFIG_TERMS.items()
                if term in lower_line
            ]
            if not hits:
                continue

            line_ok = any(marker in lower_line for marker in REFERENCE_OK_MARKERS)
            if is_doc_or_todo(path) and doc_has_label:
                line_ok = True

            if not line_ok:
                add_warning(
                    warnings,
                    path,
                    line_no,
                    "forbidden-service wording needs legacy/prohibition labeling: "
                    + ", ".join(sorted(set(hits))),
                )


def main() -> int:
    failures: list[str] = []
    warnings: list[str] = []

    check_firebase_json(failures, warnings)
    check_pubspec(failures)
    check_storage_rules_label(failures, warnings)
    check_functions_legacy_label(failures)
    check_android_manifests(failures)
    check_config_manifests(failures)
    check_wording_references(warnings)

    print("Spark-only guardrail scan")
    print("=========================")

    if failures:
        print("\nFAILURES")
        for item in failures:
            print(f"- {item}")
    else:
        print("\nNo active forbidden dependency or deploy target found.")

    if warnings:
        print("\nWARNINGS / MANUAL REVIEW")
        for item in warnings:
            print(f"- {item}")
    else:
        print("\nNo warning-level legacy wording found.")

    print("\nChecked:")
    print("- firebase.json active deploy targets")
    print("- pubspec.yaml forbidden packages")
    print("- Android manifests for Google Maps keys")
    print("- Worker package/wrangler configs for forbidden active services")
    print("- storage.rules inactive label and firebase.json non-reference")
    print("- functions/ legacy Spark-inactive label and disabled deploy scripts")
    print("- repository wording that mentions forbidden services")

    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
