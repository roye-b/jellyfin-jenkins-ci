#!/usr/bin/env python3
import argparse
from pathlib import Path
import xml.etree.ElementTree as ET

NS = {"t": "http://microsoft.com/schemas/VisualStudio/TeamTest/2010"}

def duration_seconds(value):
    if not value:
        return 0.0
    try:
        hours, minutes, seconds = value.split(":")
        return int(hours) * 3600 + int(minutes) * 60 + float(seconds)
    except (ValueError, AttributeError):
        return 0.0

def convert(source, destination):
    root = ET.parse(source).getroot()
    results = root.findall("t:Results/t:UnitTestResult", NS)

    suite = ET.Element("testsuite", {
        "name": source.parent.name,
        "tests": str(len(results)),
        "failures": str(sum(r.get("outcome") == "Failed" for r in results)),
        "errors": str(sum(r.get("outcome") not in ("Passed", "Failed", "NotExecuted") for r in results)),
        "skipped": str(sum(r.get("outcome") == "NotExecuted" for r in results)),
    })

    for result in results:
        case = ET.SubElement(suite, "testcase", {
            "classname": source.parent.name,
            "name": result.get("testName", "unknown"),
            "time": str(duration_seconds(result.get("duration"))),
        })

        outcome = result.get("outcome")
        message = result.findtext("t:Output/t:ErrorInfo/t:Message", default="", namespaces=NS)
        stack = result.findtext("t:Output/t:ErrorInfo/t:StackTrace", default="", namespaces=NS)

        if outcome == "Failed":
            ET.SubElement(case, "failure", {"message": message}).text = stack
        elif outcome == "NotExecuted":
            ET.SubElement(case, "skipped")
        elif outcome != "Passed":
            ET.SubElement(case, "error", {"message": outcome or "Unknown outcome"}).text = message

    destination.parent.mkdir(parents=True, exist_ok=True)
    ET.ElementTree(suite).write(destination, encoding="utf-8", xml_declaration=True)
    print(f"Converted {source.name}: {len(results)} tests -> {destination}")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("results_dir", type=Path)
    args = parser.parse_args()

    reports = sorted(args.results_dir.glob("*/*.trx"))
    if not reports:
        raise SystemExit("ERROR: No project TRX reports found")

    for source in reports:
        convert(source, args.results_dir / "junit" / f"{source.parent.name}.xml")

    print(f"SUCCESS: Converted {len(reports)} TRX reports")

if __name__ == "__main__":
    main()
