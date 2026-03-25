import {
  Action,
  ActionPanel,
  Color,
  getPreferenceValues,
  Icon,
  List,
} from "@raycast/api";
import { useState, useMemo } from "react";
import { parseQuery } from "./parser";
import { resolveZones } from "./aliases";
import {
  buildReferenceDate,
  formatTime,
  formatDate,
  formatForCopy,
  formatAllForCopy,
} from "./formatter";
import type { Preferences, ZoneResult } from "./types";

export default function ConvertTime() {
  const prefs = getPreferenceValues<Preferences>();
  const zones = useMemo(
    () => resolveZones(prefs.defaultZones),
    [prefs.defaultZones],
  );
  const [searchText, setSearchText] = useState("");

  const parsed = useMemo(
    () => (searchText.trim() ? parseQuery(searchText) : undefined),
    [searchText],
  );

  const refDate = useMemo(
    () =>
      parsed
        ? buildReferenceDate(parsed.hour, parsed.minute, parsed.sourceTimezone)
        : new Date(),
    [parsed],
  );

  const results = useMemo(
    (): ZoneResult[] =>
      zones.map((zone) => ({
        ...zone,
        time: formatTime(refDate, zone.timezone, prefs.timeFormat),
        date: formatDate(refDate, zone.timezone),
        isSource: parsed ? zone.timezone === parsed.sourceTimezone : false,
        isTarget: parsed?.targetTimezone
          ? zone.timezone === parsed.targetTimezone
          : false,
      })),
    [refDate, parsed, zones, prefs.timeFormat],
  );

  return (
    <List
      searchText={searchText}
      onSearchTextChange={setSearchText}
      searchBarPlaceholder="3pm SF, 1130am BKK in NYC, noon London..."
      throttle
    >
      {results.length === 0 ? (
        <List.EmptyView
          title="No zones configured"
          description="Set your default zones in extension preferences"
          icon={Icon.Globe}
        />
      ) : (
        results.map((zone, index) => (
          <List.Item
            key={`${zone.label}-${index}`}
            icon={
              zone.isSource
                ? { source: Icon.CircleFilled, tintColor: Color.Orange }
                : zone.isTarget
                  ? { source: Icon.CircleFilled, tintColor: Color.Blue }
                  : { source: Icon.Circle, tintColor: Color.SecondaryText }
            }
            title={zone.label}
            subtitle={zone.time}
            accessories={[{ text: zone.date }]}
            actions={
              <ActionPanel>
                <Action.CopyToClipboard
                  title="Copy Time"
                  content={formatForCopy(
                    refDate,
                    zone.timezone,
                    zone.label,
                    prefs.timeFormat,
                    prefs.copyFormat,
                  )}
                />
                <Action.CopyToClipboard
                  title="Copy All Times"
                  content={formatAllForCopy(
                    refDate,
                    zones,
                    prefs.timeFormat,
                    prefs.copyFormat,
                  )}
                  shortcut={{ modifiers: ["cmd", "shift"], key: "c" }}
                />
                <Action.Open
                  title="Open in Timezoner"
                  target="timezoner://"
                  shortcut={{ modifiers: ["cmd"], key: "o" }}
                />
              </ActionPanel>
            }
          />
        ))
      )}
    </List>
  );
}
