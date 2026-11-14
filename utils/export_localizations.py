#!/usr/bin/env python3

import re
import shutil
import subprocess
import sys
from pathlib import Path
from xml.etree import ElementTree

from termcolor import colored
from yaspin import yaspin
from yaspin.spinners import Spinners

PROJECT = "Moblin.xcodeproj"
EXPORT_PATH = Path("Moblin Localizations")
NS = {"": "urn:oasis:names:tc:xliff:document:1.2"}
KNOWN_REGIONS_RE = re.compile(r"knownRegions = \(([^)]*)\);")

ElementTree.register_namespace("", "urn:oasis:names:tc:xliff:document:1.2")


def run(description, command):
    with yaspin(Spinners.dots, text=description, color="cyan", timer=" ({})") as spinner:
        try:
            output = subprocess.run(command, capture_output=True, text=True, check=True).stdout
        except subprocess.CalledProcessError as e:
            spinner.fail(colored("✘", "red"))
            print(e.stdout)
            print(e.stderr)
            raise
        spinner.ok(colored("✔", "green"))
    return output


def sort_trans_units(path):
    tree = ElementTree.parse(path)

    for body in tree.findall("./file/body", namespaces=NS):
        sorted_trans_units: list[ElementTree.Element] = []

        for trans_unit in body.findall("./trans-unit", namespaces=NS):
            target = trans_unit.find("./target", namespaces=NS)

            if target is None:
                sorted_trans_units.insert(0, trans_unit)
            else:
                if target.attrib.get("state") == "translated":
                    sorted_trans_units.append(trans_unit)
                else:
                    sorted_trans_units.insert(0, trans_unit)

        body.clear()
        body.extend(sorted_trans_units)

    ElementTree.indent(tree)
    tree.write(path, xml_declaration=True, encoding="utf-8")


def read_languages():
    project = Path(f"{PROJECT}/project.pbxproj").read_text(encoding="utf-8")
    match = KNOWN_REGIONS_RE.search(project)
    if match is None:
        return sys.exit(f"knownRegions not found in {PROJECT}.")
    languages = [line.strip().strip(',"') for line in match.group(1).splitlines()]
    return [language for language in languages if language and language != "Base"]


def export(export_path, languages):
    command = [
        "xcodebuild",
        "-exportLocalizations",
        "-project",
        PROJECT,
        "-localizationPath",
        str(export_path),
    ]
    for language in languages:
        command += ["-exportLanguage", language]
    run("Exporting localizations", command)


def pack(export_path):
    xclocs = sorted(export_path.glob("*.xcloc"))
    if not xclocs:
        raise Exception(f"No localizations exported to {export_path}.")
    with yaspin(Spinners.dots, color="cyan", timer=" ({})") as spinner:
        for xcloc in xclocs:
            spinner.text = f"Packing {xcloc.name}"
            for path in (xcloc / "Localized Contents").glob("*.xliff"):
                sort_trans_units(path)
            shutil.make_archive(str(xcloc), "zip", export_path, xcloc.name)
            shutil.rmtree(xcloc)
        spinner.text = "Packing localizations"
        spinner.ok(colored("✔", "green"))


def main():
    shutil.rmtree(EXPORT_PATH, ignore_errors=True)
    export(EXPORT_PATH, read_languages())
    pack(EXPORT_PATH)


main()
