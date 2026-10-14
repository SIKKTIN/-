"""Check package contents and save evidence for the first Android build."""
import hashlib
import json
import pathlib
import zipfile
import argparse

ROOT = pathlib.Path(__file__).resolve().parents[1]
APK = ROOT / "build/android/prison-android-arm64-debug.apk"
REPORT = ROOT / "docs/performance/android-first-build-20261014/package-verification.json"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apk", type=pathlib.Path, default=APK)
    parser.add_argument("--report", type=pathlib.Path, default=REPORT)
    args = parser.parse_args()
    apk = args.apk.resolve()
    with zipfile.ZipFile(apk) as archive:
        names = set(archive.namelist())
        index = json.loads(archive.read("assets/art/runtime_textures_android/index.json"))
        referenced = {"assets/" + item["resource"].removeprefix("res://") for item in index["textures"].values()}
        checks = {
            "android_index_present": index["compression"] == "android_etc2_world",
            "all_baked_resources_in_apk": referenced <= names,
            "no_desktop_baked_resources": not any(name.startswith("assets/art/runtime_textures/") for name in names),
            "no_desktop_imported_formats": not any(".s3tc." in name or ".bptc." in name for name in names),
            "only_arm64_native_code": {name.split("/")[1] for name in names if name.startswith("lib/") and name.endswith(".so")} == {"arm64-v8a"},
            "no_build_docs_qa_or_credentials": not any(name.startswith(tuple("assets/" + prefix + "/" for prefix in ["build", "docs", "qa", "gamecreator", ".gamecreator-sync", ".git"])) for name in names),
        }
        groups = {}
        for entry in archive.infolist():
            parts = entry.filename.split("/")
            group = "/".join(parts[:3]) if parts[0] == "assets" else parts[0]
            groups[group] = groups.get(group, 0) + entry.compress_size
    report = {
        "apk": str(apk), "bytes": apk.stat().st_size,
        "sha256": hashlib.file_digest(apk.open("rb"), "sha256").hexdigest(),
        "checks": checks, "baked_entries": len(index["textures"]), "baked_unique_resources": len(referenced),
        "largest_compressed_groups": dict(sorted(groups.items(), key=lambda item: item[1], reverse=True)[:12]),
        "device_test": "Not run: no connected Android device",
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    raise SystemExit(0 if all(checks.values()) else 1)


if __name__ == "__main__":
    main()
