#!/usr/bin/env python3
"""
Automatic features manifest generation script for Moblin.
Executed during the Xcode Build Phase.
"""

import json
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path


def get_marketing_version() -> str:
    """Extracts MARKETING_VERSION from Config/Base.xcconfig"""
    config_path = Path("Config/Base.xcconfig")
    if not config_path.exists():
        print("⚠️ Base.xcconfig not found. Using fallback.")
        return "1.0.0"

    content = config_path.read_text(encoding="utf-8")
    for line in content.splitlines():
        if line.strip().startswith("MARKETING_VERSION"):
            version = line.split("=")[1].strip()
            return version
    return "1.0.0"


def get_git_features() -> set:
    """Tries to extract features via Conventional Commits"""
    try:
        # Last tag
        last_tag = (
            subprocess.check_output(
                ["git", "describe", "--tags", "--abbrev=0"], stderr=subprocess.PIPE
            )
            .decode()
            .strip()
        )

        # Commits since last tag
        log = subprocess.check_output(
            ["git", "log", f"{last_tag}..HEAD", "--oneline"], stderr=subprocess.PIPE
        ).decode()

        features = set()

        # feat(scope):
        features.update(re.findall(r"feat\(([^)]+)\):", log))
        # feature: scope
        features.update(re.findall(r"feature:\s*([a-zA-Z0-9_-]+)", log, re.IGNORECASE))

        print(f"✅ Git detected: {len(features)} features found (last tag: {last_tag})")
        return features

    except Exception as e:
        print(f"⚠️ Git unavailable or shallow clone: {e}")
        print("   → Using ManualFeatures.json only")
        return set()


def main():
    print("=== Moblin New Features Manifest Generator ===")

    root = Path.cwd()
    output_dir = root / "Config"
    output_file = output_dir / "NewFeatures.json"
    manual_file = root / "Config" / "ManualFeatures.json"

    output_dir.mkdir(parents=True, exist_ok=True)

    # 1. Current version
    version = get_marketing_version()

    # 2. Git features (with fallback)
    git_features = get_git_features()

    # 3. Manual Manifest
    manual_features = set()
    manual_config = {}
    source = "manual-only"

    if manual_file.exists():
        try:
            manual_config = json.loads(manual_file.read_text(encoding="utf-8"))
            manual_features = set(manual_config.get("features", []))

            # Respects autoDetectFromGit flag
            auto_detect = manual_config.get("autoDetectFromGit", True)

            if auto_detect:
                all_features = git_features.union(manual_features)
                source = "git+manual"
            else:
                all_features = manual_features
                source = "manual-only"

            print(f"✅ ManualFeatures.json loaded: {len(manual_features)} features")
        except Exception as e:
            print(f"❌ Error reading ManualFeatures.json: {e}")
            all_features = git_features
    else:
        all_features = git_features
        print("ℹ️ ManualFeatures.json not found (optional)")

    # 4. Generate final manifest
    manifest = {
        "version": version,
        "features": sorted(list(all_features)),
        "generatedAt": datetime.utcnow().isoformat() + "Z",
        "source": source,
    }

    # 5. Save
    output_file.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8"
    )

    print(f"✅ NewFeatures.json generated successfully!")
    print(f"   Version: {version}")
    print(f"   Features: {len(manifest['features'])}")
    print(f"   Source: {source}")
    print(f"   File: {output_file}")


if __name__ == "__main__":
    main()
