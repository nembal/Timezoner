import {
  Action,
  ActionPanel,
  Color,
  getPreferenceValues,
  Icon,
  List,
  showToast,
  Toast,
} from "@raycast/api";
import { useEffect, useMemo, useState } from "react";
import { parseQuery } from "./parser";
import {
  buildReferenceDate,
  formatTime,
  formatDate,
  formatForCopy,
  formatAllForCopy,
} from "./formatter";
import { buildTimeZonerURL } from "./timezoner-url";
import { addZone, loadZones, removeZone, saveZones } from "./zones";
import type { Preferences, ZoneInfo, ZoneResult } from "./types";

function appendMissingZone(zones: ZoneInfo[], zone: ZoneInfo): ZoneInfo[] {
  if (zones.some((existing) => existing.timezone === zone.timezone)) {
    return zones;
  }
  return [...zones, zone];
}

export default function ConvertTime() {
  const prefs = getPreferenceValues<Preferences>();
  const [zones, setZones] = useState<ZoneInfo[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [searchText, setSearchText] = useState("");

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

  const parsed = useMemo(
    () => (searchText.trim() ? parseQuery(searchText) : undefined),
    [searchText],
  );
  const conversion = parsed?.kind === "conversion" ? parsed : undefined;

  const refDate = useMemo(
    () =>
      conversion
        ? buildReferenceDate(
            conversion.hour,
            conversion.minute,
            conversion.sourceTimezone,
          )
        : new Date(),
    [conversion],
  );

  const displayZones = useMemo(() => {
    if (!conversion) return zones;

    let next = appendMissingZone(zones, {
      label: conversion.sourceLabel,
      timezone: conversion.sourceTimezone,
    });

    if (conversion.targetTimezone && conversion.targetLabel) {
      next = appendMissingZone(next, {
        label: conversion.targetLabel,
        timezone: conversion.targetTimezone,
      });
    }

    return next;
  }, [conversion, zones]);

  const results = useMemo(
    (): ZoneResult[] =>
      displayZones.map((zone) => ({
        ...zone,
        time: formatTime(refDate, zone.timezone, prefs.timeFormat),
        date: formatDate(refDate, zone.timezone),
        isSource: conversion
          ? zone.timezone === conversion.sourceTimezone
          : false,
        isTarget: conversion?.targetTimezone
          ? zone.timezone === conversion.targetTimezone
          : false,
      })),
    [displayZones, refDate, conversion, prefs.timeFormat],
  );

  async function handleAddZone(zone: ZoneInfo) {
    const next = addZone(zones, zone);
    setZones(next);
    await saveZones(next);
    setSearchText("");
    await showToast(Toast.Style.Success, `Added ${zone.label}`);
  }

  async function handleRemoveZone(label: string) {
    const next = removeZone(zones, label);
    if (next.length === zones.length) {
      await showToast(Toast.Style.Failure, `No zone matched ${label}`);
      return;
    }

    setZones(next);
    await saveZones(next);
    setSearchText("");
    await showToast(Toast.Style.Success, `Removed ${label}`);
  }

  const openURL = buildTimeZonerURL(conversion);

  return (
    <List
      isLoading={isLoading}
      searchText={searchText}
      onSearchTextChange={setSearchText}
      searchBarPlaceholder="3pm SF, +Tokyo, remove NYC..."
      throttle
    >
      {parsed?.kind === "addZone" ? (
        <List.Item
          icon={{ source: Icon.Plus, tintColor: Color.Green }}
          title={`Add ${parsed.label}`}
          subtitle={parsed.timezone}
          actions={
            <ActionPanel>
              <Action
                title="Add Zone"
                icon={Icon.Plus}
                onAction={() =>
                  handleAddZone({
                    label: parsed.label,
                    timezone: parsed.timezone,
                  })
                }
              />
              <Action.Open
                title="Open in Timezoner"
                target="timezoner://open"
                shortcut={{ modifiers: ["cmd"], key: "o" }}
              />
            </ActionPanel>
          }
        />
      ) : parsed?.kind === "removeZone" ? (
        <List.Item
          icon={{ source: Icon.Minus, tintColor: Color.Red }}
          title={`Remove ${parsed.label}`}
          subtitle="Remove a matching label or timezone"
          actions={
            <ActionPanel>
              <Action
                title="Remove Zone"
                icon={Icon.Minus}
                onAction={() => handleRemoveZone(parsed.label)}
              />
              <Action.Open
                title="Open in Timezoner"
                target="timezoner://open"
                shortcut={{ modifiers: ["cmd"], key: "o" }}
              />
            </ActionPanel>
          }
        />
      ) : results.length === 0 && !isLoading ? (
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
                    displayZones,
                    prefs.timeFormat,
                    prefs.copyFormat,
                  )}
                  shortcut={{ modifiers: ["cmd", "shift"], key: "c" }}
                />
                <Action.Open
                  title="Open in Timezoner"
                  target={openURL}
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
