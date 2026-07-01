import { resolveZones } from "./aliases";
import type { ZoneInfo } from "./types";

const STORAGE_KEY = "timezoner.zones";

type RaycastApi = typeof import("@raycast/api");

async function getLocalStorage(): Promise<RaycastApi["LocalStorage"]> {
  const moduleName = "@raycast/api";
  const api = (await import(/* @vite-ignore */ moduleName)) as RaycastApi;
  return api.LocalStorage;
}

function normalize(value: string): string {
  return value.trim().toLowerCase();
}

function isZoneInfo(value: unknown): value is ZoneInfo {
  if (!value || typeof value !== "object") return false;
  const candidate = value as Record<string, unknown>;
  return (
    typeof candidate.label === "string" &&
    typeof candidate.timezone === "string"
  );
}

export function addZone(zones: ZoneInfo[], zone: ZoneInfo): ZoneInfo[] {
  const timezone = normalize(zone.timezone);
  return [
    ...zones.filter((existing) => normalize(existing.timezone) !== timezone),
    zone,
  ];
}

export function removeZone(
  zones: ZoneInfo[],
  labelOrTimezone: string,
): ZoneInfo[] {
  const target = normalize(labelOrTimezone);
  return zones.filter(
    (zone) =>
      normalize(zone.label) !== target && normalize(zone.timezone) !== target,
  );
}

export async function loadZones(defaultZones: string): Promise<ZoneInfo[]> {
  const LocalStorage = await getLocalStorage();
  const stored = await LocalStorage.getItem<string>(STORAGE_KEY);

  if (typeof stored !== "string") {
    return resolveZones(defaultZones);
  }

  try {
    const parsed = JSON.parse(stored) as unknown;
    if (!Array.isArray(parsed) || !parsed.every(isZoneInfo)) {
      throw new Error("Invalid zone storage");
    }
    return parsed;
  } catch {
    await LocalStorage.removeItem(STORAGE_KEY);
    return resolveZones(defaultZones);
  }
}

export async function saveZones(zones: ZoneInfo[]): Promise<void> {
  const LocalStorage = await getLocalStorage();
  await LocalStorage.setItem(STORAGE_KEY, JSON.stringify(zones));
}
