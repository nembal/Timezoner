import Foundation

// MARK: - Timezone Alias Dictionary
// Maps lowercase aliases to IANA timezone identifiers.
// Categories: city abbreviations, city names, country names, region aliases,
// timezone abbreviations, and airport codes.

private let timezoneAliases: [String: String] = {
    var d = [String: String](minimumCapacity: 350)

    // ─── City Abbreviations (~30) ───────────────────────────────────────
    let cityAbbreviations: [(String, String)] = [
        ("sf",   "America/Los_Angeles"),
        ("nyc",  "America/New_York"),
        ("ny",   "America/New_York"),
        ("la",   "America/Los_Angeles"),
        ("chi",  "America/Chicago"),
        ("hk",   "Asia/Hong_Kong"),
        ("bkk",  "Asia/Bangkok"),
        ("ldn",  "Europe/London"),
        ("lon",  "Europe/London"),
        ("par",  "Europe/Paris"),
        ("ber",  "Europe/Berlin"),
        ("tok",  "Asia/Tokyo"),
        ("tyo",  "Asia/Tokyo"),
        ("syd",  "Australia/Sydney"),
        ("mel",  "Australia/Melbourne"),
        ("sin",  "Asia/Singapore"),
        ("sg",   "Asia/Singapore"),
        ("dxb",  "Asia/Dubai"),
        ("bom",  "Asia/Kolkata"),
        ("del",  "Asia/Kolkata"),
        ("sha",  "Asia/Shanghai"),
        ("pek",  "Asia/Shanghai"),
        ("sel",  "Asia/Seoul"),
        ("tpe",  "Asia/Taipei"),
        ("mnl",  "Asia/Manila"),
        ("jkt",  "Asia/Jakarta"),
        ("yvr",  "America/Vancouver"),
        ("yyz",  "America/Toronto"),
        ("mtl",  "America/Toronto"),
        ("akl",  "Pacific/Auckland"),
        ("sea",  "America/Los_Angeles"),
    ]

    // ─── City Names (~150) ──────────────────────────────────────────────
    let cityNames: [(String, String)] = [
        // North America
        ("san francisco",    "America/Los_Angeles"),
        ("new york",         "America/New_York"),
        ("new york city",    "America/New_York"),
        ("los angeles",      "America/Los_Angeles"),
        ("chicago",          "America/Chicago"),
        ("seattle",          "America/Los_Angeles"),
        ("portland",         "America/Los_Angeles"),
        ("denver",           "America/Denver"),
        ("phoenix",          "America/Phoenix"),
        ("dallas",           "America/Chicago"),
        ("houston",          "America/Chicago"),
        ("austin",           "America/Chicago"),
        ("san antonio",      "America/Chicago"),
        ("miami",            "America/New_York"),
        ("boston",            "America/New_York"),
        ("atlanta",          "America/New_York"),
        ("detroit",          "America/Detroit"),
        ("minneapolis",      "America/Chicago"),
        ("washington",       "America/New_York"),
        ("washington dc",    "America/New_York"),
        ("dc",               "America/New_York"),
        ("philadelphia",     "America/New_York"),
        ("san diego",        "America/Los_Angeles"),
        ("las vegas",        "America/Los_Angeles"),
        ("salt lake city",   "America/Denver"),
        ("honolulu",         "Pacific/Honolulu"),
        ("anchorage",        "America/Anchorage"),
        ("toronto",          "America/Toronto"),
        ("vancouver",        "America/Vancouver"),
        ("montreal",         "America/Toronto"),
        ("calgary",          "America/Edmonton"),
        ("edmonton",         "America/Edmonton"),
        ("ottawa",           "America/Toronto"),
        ("winnipeg",         "America/Winnipeg"),
        ("mexico city",      "America/Mexico_City"),
        ("guadalajara",      "America/Mexico_City"),
        ("monterrey",        "America/Monterrey"),
        ("havana",           "America/Havana"),
        ("panama city",      "America/Panama"),

        // South America
        ("sao paulo",        "America/Sao_Paulo"),
        ("são paulo",        "America/Sao_Paulo"),
        ("rio de janeiro",   "America/Sao_Paulo"),
        ("rio",              "America/Sao_Paulo"),
        ("buenos aires",     "America/Argentina/Buenos_Aires"),
        ("santiago",         "America/Santiago"),
        ("lima",             "America/Lima"),
        ("bogota",           "America/Bogota"),
        ("bogotá",           "America/Bogota"),
        ("caracas",          "America/Caracas"),
        ("quito",            "America/Guayaquil"),
        ("montevideo",       "America/Montevideo"),

        // Europe
        ("london",           "Europe/London"),
        ("paris",            "Europe/Paris"),
        ("berlin",           "Europe/Berlin"),
        ("amsterdam",        "Europe/Amsterdam"),
        ("brussels",         "Europe/Brussels"),
        ("zurich",           "Europe/Zurich"),
        ("zürich",           "Europe/Zurich"),
        ("geneva",           "Europe/Zurich"),
        ("munich",           "Europe/Berlin"),
        ("münchen",          "Europe/Berlin"),
        ("frankfurt",        "Europe/Berlin"),
        ("hamburg",          "Europe/Berlin"),
        ("milan",            "Europe/Rome"),
        ("rome",             "Europe/Rome"),
        ("madrid",           "Europe/Madrid"),
        ("barcelona",        "Europe/Madrid"),
        ("lisbon",           "Europe/Lisbon"),
        ("vienna",           "Europe/Vienna"),
        ("prague",           "Europe/Prague"),
        ("warsaw",           "Europe/Warsaw"),
        ("budapest",         "Europe/Budapest"),
        ("bucharest",        "Europe/Bucharest"),
        ("athens",           "Europe/Athens"),
        ("stockholm",        "Europe/Stockholm"),
        ("oslo",             "Europe/Oslo"),
        ("copenhagen",       "Europe/Copenhagen"),
        ("helsinki",         "Europe/Helsinki"),
        ("dublin",           "Europe/Dublin"),
        ("edinburgh",        "Europe/London"),
        ("glasgow",          "Europe/London"),
        ("manchester",       "Europe/London"),
        ("birmingham",       "Europe/London"),
        ("moscow",           "Europe/Moscow"),
        ("st petersburg",    "Europe/Moscow"),
        ("saint petersburg", "Europe/Moscow"),
        ("istanbul",         "Europe/Istanbul"),
        ("kyiv",             "Europe/Kyiv"),
        ("kiev",             "Europe/Kyiv"),
        ("belgrade",         "Europe/Belgrade"),
        ("sofia",            "Europe/Sofia"),
        ("zagreb",           "Europe/Zagreb"),
        ("bratislava",       "Europe/Bratislava"),
        ("luxembourg",       "Europe/Luxembourg"),
        ("riga",             "Europe/Riga"),
        ("tallinn",          "Europe/Tallinn"),
        ("vilnius",          "Europe/Vilnius"),
        ("reykjavik",        "Atlantic/Reykjavik"),

        // Middle East
        ("dubai",            "Asia/Dubai"),
        ("abu dhabi",        "Asia/Dubai"),
        ("doha",             "Asia/Qatar"),
        ("riyadh",           "Asia/Riyadh"),
        ("jeddah",           "Asia/Riyadh"),
        ("tehran",           "Asia/Tehran"),
        ("tel aviv",         "Asia/Jerusalem"),
        ("jerusalem",        "Asia/Jerusalem"),
        ("beirut",           "Asia/Beirut"),
        ("amman",            "Asia/Amman"),
        ("baghdad",          "Asia/Baghdad"),
        ("kuwait city",      "Asia/Kuwait"),
        ("muscat",           "Asia/Muscat"),
        ("bahrain",          "Asia/Bahrain"),

        // Asia
        ("tokyo",            "Asia/Tokyo"),
        ("osaka",            "Asia/Tokyo"),
        ("hong kong",        "Asia/Hong_Kong"),
        ("singapore",        "Asia/Singapore"),
        ("bangkok",          "Asia/Bangkok"),
        ("chiang mai",       "Asia/Bangkok"),
        ("phuket",           "Asia/Bangkok"),
        ("mumbai",           "Asia/Kolkata"),
        ("delhi",            "Asia/Kolkata"),
        ("new delhi",        "Asia/Kolkata"),
        ("bangalore",        "Asia/Kolkata"),
        ("bengaluru",        "Asia/Kolkata"),
        ("chennai",          "Asia/Kolkata"),
        ("hyderabad",        "Asia/Kolkata"),
        ("kolkata",          "Asia/Kolkata"),
        ("calcutta",         "Asia/Kolkata"),
        ("pune",             "Asia/Kolkata"),
        ("shanghai",         "Asia/Shanghai"),
        ("beijing",          "Asia/Shanghai"),
        ("shenzhen",         "Asia/Shanghai"),
        ("guangzhou",        "Asia/Shanghai"),
        ("chengdu",          "Asia/Shanghai"),
        ("seoul",            "Asia/Seoul"),
        ("busan",            "Asia/Seoul"),
        ("taipei",           "Asia/Taipei"),
        ("jakarta",          "Asia/Jakarta"),
        ("bali",             "Asia/Makassar"),
        ("manila",           "Asia/Manila"),
        ("hanoi",            "Asia/Ho_Chi_Minh"),
        ("ho chi minh",      "Asia/Ho_Chi_Minh"),
        ("ho chi minh city", "Asia/Ho_Chi_Minh"),
        ("saigon",           "Asia/Ho_Chi_Minh"),
        ("kuala lumpur",     "Asia/Kuala_Lumpur"),
        ("phnom penh",       "Asia/Phnom_Penh"),
        ("yangon",           "Asia/Yangon"),
        ("colombo",          "Asia/Colombo"),
        ("karachi",          "Asia/Karachi"),
        ("lahore",           "Asia/Karachi"),
        ("islamabad",        "Asia/Karachi"),
        ("kathmandu",        "Asia/Kathmandu"),
        ("dhaka",            "Asia/Dhaka"),
        ("almaty",           "Asia/Almaty"),
        ("tashkent",         "Asia/Tashkent"),
        ("tbilisi",          "Asia/Tbilisi"),
        ("yerevan",          "Asia/Yerevan"),
        ("baku",             "Asia/Baku"),
        ("ulaanbaatar",      "Asia/Ulaanbaatar"),

        // Africa
        ("cairo",            "Africa/Cairo"),
        ("lagos",            "Africa/Lagos"),
        ("nairobi",          "Africa/Nairobi"),
        ("johannesburg",     "Africa/Johannesburg"),
        ("cape town",        "Africa/Johannesburg"),
        ("addis ababa",      "Africa/Addis_Ababa"),
        ("dar es salaam",    "Africa/Dar_es_Salaam"),
        ("casablanca",       "Africa/Casablanca"),
        ("accra",            "Africa/Accra"),
        ("tunis",            "Africa/Tunis"),
        ("algiers",          "Africa/Algiers"),
        ("kigali",           "Africa/Kigali"),
        ("kampala",          "Africa/Kampala"),

        // Oceania
        ("sydney",           "Australia/Sydney"),
        ("melbourne",        "Australia/Melbourne"),
        ("brisbane",         "Australia/Brisbane"),
        ("perth",            "Australia/Perth"),
        ("adelaide",         "Australia/Adelaide"),
        ("auckland",         "Pacific/Auckland"),
        ("wellington",       "Pacific/Auckland"),
        ("fiji",             "Pacific/Fiji"),
        ("suva",             "Pacific/Fiji"),
    ]

    // ─── Country Names (~30) ────────────────────────────────────────────
    let countryNames: [(String, String)] = [
        ("thailand",         "Asia/Bangkok"),
        ("japan",            "Asia/Tokyo"),
        ("germany",          "Europe/Berlin"),
        ("france",           "Europe/Paris"),
        ("uk",               "Europe/London"),
        ("united kingdom",   "Europe/London"),
        ("great britain",    "Europe/London"),
        ("england",          "Europe/London"),
        ("scotland",         "Europe/London"),
        ("ireland",          "Europe/Dublin"),
        ("australia",        "Australia/Sydney"),
        ("new zealand",      "Pacific/Auckland"),
        ("singapore",        "Asia/Singapore"),
        ("india",            "Asia/Kolkata"),
        ("china",            "Asia/Shanghai"),
        ("south korea",      "Asia/Seoul"),
        ("korea",            "Asia/Seoul"),
        ("taiwan",           "Asia/Taipei"),
        ("vietnam",          "Asia/Ho_Chi_Minh"),
        ("indonesia",        "Asia/Jakarta"),
        ("malaysia",         "Asia/Kuala_Lumpur"),
        ("philippines",      "Asia/Manila"),
        ("pakistan",          "Asia/Karachi"),
        ("bangladesh",       "Asia/Dhaka"),
        ("nepal",            "Asia/Kathmandu"),
        ("sri lanka",        "Asia/Colombo"),
        ("uae",              "Asia/Dubai"),
        ("united arab emirates", "Asia/Dubai"),
        ("saudi arabia",     "Asia/Riyadh"),
        ("qatar",            "Asia/Qatar"),
        ("israel",           "Asia/Jerusalem"),
        ("turkey",           "Europe/Istanbul"),
        ("russia",           "Europe/Moscow"),
        ("egypt",            "Africa/Cairo"),
        ("nigeria",          "Africa/Lagos"),
        ("kenya",            "Africa/Nairobi"),
        ("south africa",     "Africa/Johannesburg"),
        ("brazil",           "America/Sao_Paulo"),
        ("argentina",        "America/Argentina/Buenos_Aires"),
        ("chile",            "America/Santiago"),
        ("colombia",         "America/Bogota"),
        ("mexico",           "America/Mexico_City"),
        ("canada",           "America/Toronto"),
        ("peru",             "America/Lima"),
        ("spain",            "Europe/Madrid"),
        ("italy",            "Europe/Rome"),
        ("netherlands",      "Europe/Amsterdam"),
        ("belgium",          "Europe/Brussels"),
        ("switzerland",      "Europe/Zurich"),
        ("austria",          "Europe/Vienna"),
        ("czech republic",   "Europe/Prague"),
        ("czechia",          "Europe/Prague"),
        ("poland",           "Europe/Warsaw"),
        ("hungary",          "Europe/Budapest"),
        ("greece",           "Europe/Athens"),
        ("sweden",           "Europe/Stockholm"),
        ("norway",           "Europe/Oslo"),
        ("denmark",          "Europe/Copenhagen"),
        ("finland",          "Europe/Helsinki"),
        ("portugal",         "Europe/Lisbon"),
        ("iceland",          "Atlantic/Reykjavik"),
        ("ukraine",          "Europe/Kyiv"),
        ("romania",          "Europe/Bucharest"),
        ("morocco",          "Africa/Casablanca"),
        ("cambodia",         "Asia/Phnom_Penh"),
        ("myanmar",          "Asia/Yangon"),
    ]

    // ─── Region Aliases ─────────────────────────────────────────────────
    let regionAliases: [(String, String)] = [
        ("europe",           "Europe/Paris"),
        ("pacific",          "America/Los_Angeles"),
        ("eastern",          "America/New_York"),
        ("central",          "America/Chicago"),
        ("mountain",         "America/Denver"),
        ("atlantic",         "America/Halifax"),
        ("east coast",       "America/New_York"),
        ("west coast",       "America/Los_Angeles"),
    ]

    // ─── Timezone Abbreviations (~25) ───────────────────────────────────
    let tzAbbreviations: [(String, String)] = [
        ("pt",   "America/Los_Angeles"),
        ("pst",  "America/Los_Angeles"),
        ("pdt",  "America/Los_Angeles"),
        ("et",   "America/New_York"),
        ("est",  "America/New_York"),
        ("edt",  "America/New_York"),
        ("ct",   "America/Chicago"),
        ("cst",  "America/Chicago"),
        ("cdt",  "America/Chicago"),
        ("mt",   "America/Denver"),
        ("mst",  "America/Denver"),
        ("mdt",  "America/Denver"),
        ("cet",  "Europe/Paris"),
        ("cest", "Europe/Paris"),
        ("gmt",  "Europe/London"),
        ("utc",  "GMT"),
        ("ict",  "Asia/Bangkok"),
        ("jst",  "Asia/Tokyo"),
        ("hkt",  "Asia/Hong_Kong"),
        ("sgt",  "Asia/Singapore"),
        ("aest", "Australia/Sydney"),
        ("aedt", "Australia/Sydney"),
        ("ist",  "Asia/Kolkata"),
        ("bst",  "Europe/London"),
        ("kst",  "Asia/Seoul"),
        ("nzst", "Pacific/Auckland"),
        ("nzdt", "Pacific/Auckland"),
        ("hst",  "Pacific/Honolulu"),
        ("akst", "America/Anchorage"),
        ("akdt", "America/Anchorage"),
        ("wet",  "Europe/Lisbon"),
        ("eet",  "Europe/Athens"),
        ("eest", "Europe/Athens"),
    ]

    // ─── Airport Codes (top ~50) ────────────────────────────────────────
    let airportCodes: [(String, String)] = [
        ("lax",  "America/Los_Angeles"),
        ("sfo",  "America/Los_Angeles"),
        ("sjc",  "America/Los_Angeles"),
        ("oak",  "America/Los_Angeles"),
        ("jfk",  "America/New_York"),
        ("ewr",  "America/New_York"),
        ("lga",  "America/New_York"),
        ("lhr",  "Europe/London"),
        ("lgw",  "Europe/London"),
        ("stn",  "Europe/London"),
        ("cdg",  "Europe/Paris"),
        ("ory",  "Europe/Paris"),
        ("nrt",  "Asia/Tokyo"),
        ("hnd",  "Asia/Tokyo"),
        ("hkg",  "Asia/Hong_Kong"),
        // "sin" already in city abbreviations
        ("icn",  "Asia/Seoul"),
        // "dxb" already in city abbreviations
        ("ams",  "Europe/Amsterdam"),
        ("fra",  "Europe/Berlin"),
        ("zrh",  "Europe/Zurich"),
        ("muc",  "Europe/Berlin"),
        ("fco",  "Europe/Rome"),
        ("mad",  "Europe/Madrid"),
        ("bcn",  "Europe/Madrid"),
        // "sea" already in city abbreviations
        ("ord",  "America/Chicago"),
        ("mdw",  "America/Chicago"),
        ("atl",  "America/New_York"),
        ("dfw",  "America/Chicago"),
        ("mia",  "America/New_York"),
        ("bos",  "America/New_York"),
        ("iad",  "America/New_York"),
        ("dca",  "America/New_York"),
        ("den",  "America/Denver"),
        // "yyz" already in city abbreviations
        // "yvr" already in city abbreviations
        ("mex",  "America/Mexico_City"),
        ("gru",  "America/Sao_Paulo"),
        ("gig",  "America/Sao_Paulo"),
        ("scl",  "America/Santiago"),
        ("eze",  "America/Argentina/Buenos_Aires"),
        // "syd" already in city abbreviations
        // "mel" already in city abbreviations
        ("bne",  "Australia/Brisbane"),
        ("per",  "Australia/Perth"),
        // "akl" already in city abbreviations
        // "pek" already in city abbreviations
        ("pvg",  "Asia/Shanghai"),
        ("can",  "Asia/Shanghai"),
        ("kix",  "Asia/Tokyo"),
        ("tpe",  "Asia/Taipei"),
        // "del" already in city abbreviations
        // "bom" already in city abbreviations
        ("doh",  "Asia/Qatar"),
        ("ist",  "Europe/Istanbul"),
        ("cai",  "Africa/Cairo"),
        ("jnb",  "Africa/Johannesburg"),
        ("cpt",  "Africa/Johannesburg"),
        ("nbo",  "Africa/Nairobi"),
        ("las",  "America/Los_Angeles"),
        ("msp",  "America/Chicago"),
        ("dtw",  "America/Detroit"),
        ("phl",  "America/New_York"),
        ("hnl",  "Pacific/Honolulu"),
        ("svo",  "Europe/Moscow"),
        ("dmk",  "Asia/Bangkok"),
        ("bkk",  "Asia/Bangkok"),
        ("cgk",  "Asia/Jakarta"),
        ("kul",  "Asia/Kuala_Lumpur"),
        ("sgn",  "Asia/Ho_Chi_Minh"),
        ("han",  "Asia/Ho_Chi_Minh"),
    ]

    for (alias, tz) in cityAbbreviations { d[alias] = tz }
    for (alias, tz) in cityNames { d[alias] = tz }
    for (alias, tz) in countryNames { d[alias] = tz }
    for (alias, tz) in regionAliases { d[alias] = tz }
    for (alias, tz) in tzAbbreviations { d[alias] = tz }
    for (alias, tz) in airportCodes { d[alias] = tz }

    return d
}()

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
