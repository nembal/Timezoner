/// <reference types="@raycast/api">

/* 🚧 🚧 🚧
 * This file is auto-generated from the extension's manifest.
 * Do not modify manually. Instead, update the `package.json` file.
 * 🚧 🚧 🚧 */

/* eslint-disable @typescript-eslint/ban-types */

type ExtensionPreferences = {
  /** Default Zones - Comma-separated list of cities or timezone abbreviations */
  "defaultZones": string,
  /** Time Format - How times are displayed */
  "timeFormat": "12h" | "24h",
  /** Copy Format - Format used when copying time to clipboard */
  "copyFormat": "time-tz" | "24h-tz" | "time-city"
}

/** Preferences accessible in all the extension's commands */
declare type Preferences = ExtensionPreferences

declare namespace Preferences {
  /** Preferences accessible in the `convert-time` command */
  export type ConvertTime = ExtensionPreferences & {}
  /** Preferences accessible in the `world-clock` command */
  export type WorldClock = ExtensionPreferences & {}
}

declare namespace Arguments {
  /** Arguments passed to the `convert-time` command */
  export type ConvertTime = {}
  /** Arguments passed to the `world-clock` command */
  export type WorldClock = {}
}

