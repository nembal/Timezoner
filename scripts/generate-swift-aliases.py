#!/usr/bin/env python3
"""
Generate TimezoneAliases.swift from shared/timezone-aliases.json.
Preserves insertion order within each category as found in the JSON.
"""

import json
import sys
import argparse
from pathlib import Path
from collections import OrderedDict

REPO_ROOT = Path(__file__).parent.parent

CATEGORY_ORDER = [
    "city_abbreviation",
    "city_name",
    "country_name",
    "region_alias",
    "tz_abbreviation",
    "airport_code",
]

ARRAY_NAMES = {
    "city_abbreviation": "cityAbbreviations",
    "city_name":         "cityNames",
    "country_name":      "countryNames",
    "region_alias":      "regionAliases",
    "tz_abbreviation":   "tzAbbreviations",
    "airport_code":      "airportCodes",
}

SECTION_COMMENTS = {
    "city_abbreviation": "// ─── City Abbreviations (~30) ───────────────────────────────────────",
    "city_name":         "// ─── City Names (~150) ──────────────────────────────────────────────",
    "country_name":      "// ─── Country Names (~30) ────────────────────────────────────────────",
    "region_alias":      "// ─── Region Aliases ─────────────────────────────────────────────────",
    "tz_abbreviation":   "// ─── Timezone Abbreviations (~25) ───────────────────────────────────",
    "airport_code":      "// ─── Airport Codes (top ~50) ────────────────────────────────────────",
}

RESOLVE_FUNCTION = '''\
/// Resolves user-friendly timezone input to a `TimeZone` object.
///
/// Resolution order:
/// 1. Lowercase and strip whitespace
/// 2. Look up in the static alias dictionary
/// 3. Fall back to `TimeZone(identifier:)` for IANA identifiers like "America/Los_Angeles"
/// 4. Fall back to `TimeZone(abbreviation:)` for things like "PST"
/// 5. Return nil if nothing matches
public func resolveTimezone(_ input: String) -> TimeZone? {
    let normalized = input.trimmingCharacters(in: .whitespaces).lowercased()

    guard !normalized.isEmpty else { return nil }

    // 1. Check alias dictionary
    if let identifier = timezoneAliases[normalized] {
        return TimeZone(identifier: identifier)
    }

    // 2. Try as a direct IANA identifier (e.g. "America/Los_Angeles")
    if let tz = TimeZone(identifier: input.trimmingCharacters(in: .whitespaces)) {
        // TimeZone(identifier:) returns GMT for unknown identifiers on some platforms,
        // so verify it's a known identifier
        if TimeZone.knownTimeZoneIdentifiers.contains(tz.identifier) || tz.identifier == "GMT" {
            return tz
        }
    }

    // 3. Try as a timezone abbreviation (e.g. "PST")
    if let tz = TimeZone(abbreviation: input.trimmingCharacters(in: .whitespaces).uppercased()) {
        return tz
    }

    return nil
}
'''


def load_aliases(json_path: Path) -> dict:
    """Load aliases from JSON, grouped by category, preserving order."""
    with open(json_path, encoding="utf-8") as f:
        entries = json.load(f)

    grouped = OrderedDict((cat, []) for cat in CATEGORY_ORDER)
    for entry in entries:
        cat = entry["category"]
        if cat in grouped:
            grouped[cat].append((entry["alias"], entry["iana_id"]))
        else:
            # Unknown category — add to end just in case
            grouped.setdefault(cat, []).append((entry["alias"], entry["iana_id"]))

    return grouped


def format_tuple_array(name: str, entries: list) -> str:
    """Format a Swift [(String, String)] array literal."""
    if not entries:
        return f"    let {name}: [(String, String)] = []\n"

    # Compute column width for alignment: longest alias + 2 quotes + comma + space
    max_alias_len = max(len(alias) for alias, _ in entries)
    # pad alias field to align the IANA id column
    # format: ("alias",   "iana_id"),
    # alias column width = max_alias_len + 2 (quotes)

    lines = [f"    let {name}: [(String, String)] = ["]
    for alias, iana in entries:
        quoted_alias = f'"{alias}"'
        padding = " " * (max_alias_len - len(alias) + 3)
        lines.append(f'        ({quoted_alias},{padding}"{iana}"),')
    lines.append("    ]")
    return "\n".join(lines) + "\n"


def generate_swift(grouped: dict) -> str:
    """Generate the complete Swift source file content."""
    parts = []

    # Header
    parts.append("// Auto-generated from shared/timezone-aliases.json — do not edit manually\n")
    parts.append("import Foundation\n")
    parts.append("\n")

    # Opening of closure
    parts.append("private let timezoneAliases: [String: String] = {\n")
    parts.append("    var d = [String: String](minimumCapacity: 350)\n")
    parts.append("\n")

    # Each category array
    for cat in CATEGORY_ORDER:
        entries = grouped.get(cat, [])
        comment = SECTION_COMMENTS[cat]
        array_name = ARRAY_NAMES[cat]

        parts.append(f"    {comment}\n")
        parts.append(format_tuple_array(array_name, entries))
        parts.append("\n")

    # For-loop insertions
    for cat in CATEGORY_ORDER:
        array_name = ARRAY_NAMES[cat]
        parts.append(f"    for (alias, tz) in {array_name} {{ d[alias] = tz }}\n")

    parts.append("\n")
    parts.append("    return d\n")
    parts.append("}()\n")
    parts.append("\n")

    # resolveTimezone function
    parts.append(RESOLVE_FUNCTION)

    return "".join(parts)


def main():
    parser = argparse.ArgumentParser(description="Generate TimezoneAliases.swift from JSON")
    parser.add_argument(
        "--output",
        default=str(REPO_ROOT / "app" / "Sources" / "Data" / "TimezoneAliases.swift"),
        help="Output path (default: app/Sources/Data/TimezoneAliases.swift)",
    )
    args = parser.parse_args()

    json_path = REPO_ROOT / "shared" / "timezone-aliases.json"
    output_path = Path(args.output)

    grouped = load_aliases(json_path)
    total = sum(len(v) for v in grouped.values())

    swift_source = generate_swift(grouped)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(swift_source, encoding="utf-8")

    print(f"Generated {total} aliases in {output_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
