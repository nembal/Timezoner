import { Action, ActionPanel, Color, getPreferenceValues, Icon, List } from "@raycast/api";
import { useMemo } from "react";
import { resolveZones } from "./aliases";
import { formatTime, formatDate, formatForCopy, formatAllForCopy } from "./formatter";
import type { ZoneResult } from "./types";

interface Preferences {
  defaultZones: string;
  timeFormat: "12h" | "24h";
  copyFormat: "time-tz" | "24h-tz" | "time-city";
}

export default function WorldClock() {
  const prefs = getPreferenceValues<Preferences>();
  const zones = useMemo(() => resolveZones(prefs.defaultZones), [prefs.defaultZones]);
  const now = new Date();

  const results: ZoneResult[] = zones.map((zone) => ({
    ...zone,
    time: formatTime(now, zone.timezone, prefs.timeFormat),
    date: formatDate(now, zone.timezone),
    isSource: false,
    isTarget: false,
  }));

  return (
    <List>
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
            icon={{ source: Icon.Clock, tintColor: Color.SecondaryText }}
            title={zone.label}
            subtitle={zone.time}
            accessories={[{ text: zone.date }]}
            actions={
              <ActionPanel>
                <Action.CopyToClipboard
                  title="Copy Time"
                  content={formatForCopy(now, zone.timezone, zone.label, prefs.timeFormat, prefs.copyFormat)}
                />
                <Action.CopyToClipboard
                  title="Copy All Times"
                  content={formatAllForCopy(now, zones, prefs.timeFormat, prefs.copyFormat)}
                  shortcut={{ modifiers: ["cmd", "shift"], key: "c" }}
                />
                <Action.Open
                  title="Open in TimeZoner"
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
