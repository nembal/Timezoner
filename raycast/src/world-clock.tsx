import {
  Action,
  ActionPanel,
  Color,
  getPreferenceValues,
  Icon,
  List,
} from "@raycast/api";
import { useEffect, useState } from "react";
import {
  formatTime,
  formatDate,
  formatForCopy,
  formatAllForCopy,
} from "./formatter";
import { loadZones } from "./zones";
import type { Preferences, ZoneInfo, ZoneResult } from "./types";

export default function WorldClock() {
  const prefs = getPreferenceValues<Preferences>();
  const [zones, setZones] = useState<ZoneInfo[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const now = new Date();

  useEffect(() => {
    let cancelled = false;
    setIsLoading(true);

    loadZones(prefs.defaultZones)
      .then((loadedZones) => {
        if (!cancelled) setZones(loadedZones);
      })
      .finally(() => {
        if (!cancelled) setIsLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, [prefs.defaultZones]);

  const results: ZoneResult[] = zones.map((zone) => ({
    ...zone,
    time: formatTime(now, zone.timezone, prefs.timeFormat),
    date: formatDate(now, zone.timezone),
    isSource: false,
    isTarget: false,
  }));

  return (
    <List isLoading={isLoading}>
      {results.length === 0 && !isLoading ? (
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
                  content={formatForCopy(
                    now,
                    zone.timezone,
                    zone.label,
                    prefs.timeFormat,
                    prefs.copyFormat,
                  )}
                />
                <Action.CopyToClipboard
                  title="Copy All Times"
                  content={formatAllForCopy(
                    now,
                    zones,
                    prefs.timeFormat,
                    prefs.copyFormat,
                  )}
                  shortcut={{ modifiers: ["cmd", "shift"], key: "c" }}
                />
                <Action.Open
                  title="Open in Timezoner"
                  target="timezoner://open"
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
