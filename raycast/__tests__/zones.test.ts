import { describe, expect, it } from "vitest";
import type { ZoneInfo } from "../src/types";
import { addZone, removeZone } from "../src/zones";

describe("zones", () => {
  it("adds zones and replaces duplicates by timezone", () => {
    const zones: ZoneInfo[] = [{ label: "SF", timezone: "America/Los_Angeles" }];

    expect(
      addZone(zones, { label: "San Francisco", timezone: "America/Los_Angeles" }),
    ).toEqual([{ label: "San Francisco", timezone: "America/Los_Angeles" }]);
  });

  it("removes zones by label case-insensitively", () => {
    const zones: ZoneInfo[] = [
      { label: "SF", timezone: "America/Los_Angeles" },
      { label: "NYC", timezone: "America/New_York" },
    ];

    expect(removeZone(zones, "sf")).toEqual([
      { label: "NYC", timezone: "America/New_York" },
    ]);
  });

  it("removes zones by timezone case-insensitively", () => {
    const zones: ZoneInfo[] = [
      { label: "SF", timezone: "America/Los_Angeles" },
      { label: "NYC", timezone: "America/New_York" },
    ];

    expect(removeZone(zones, "america/new_york")).toEqual([
      { label: "SF", timezone: "America/Los_Angeles" },
    ]);
  });

  // LocalStorage is intentionally exercised through Raycast build/runtime.
  // Vitest cannot resolve @raycast/api's extension-only package entry reliably.
});
