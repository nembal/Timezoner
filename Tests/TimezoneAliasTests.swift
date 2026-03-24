import Testing
@testable import TimeZoner

@Suite("Timezone Alias Resolution")
struct TimezoneAliasTests {

    // MARK: - City Abbreviations

    @Test("SF resolves to America/Los_Angeles")
    func sfAlias() {
        let tz = resolveTimezone("SF")
        #expect(tz != nil)
        #expect(tz?.identifier == "America/Los_Angeles")
    }

    @Test("NYC resolves to America/New_York")
    func nycAlias() {
        let tz = resolveTimezone("NYC")
        #expect(tz != nil)
        #expect(tz?.identifier == "America/New_York")
    }

    @Test("BKK resolves to Asia/Bangkok")
    func bkkAlias() {
        let tz = resolveTimezone("BKK")
        #expect(tz != nil)
        #expect(tz?.identifier == "Asia/Bangkok")
    }

    @Test("HK resolves to Asia/Hong_Kong")
    func hkAlias() {
        let tz = resolveTimezone("HK")
        #expect(tz != nil)
        #expect(tz?.identifier == "Asia/Hong_Kong")
    }

    @Test("LA resolves to America/Los_Angeles")
    func laAlias() {
        let tz = resolveTimezone("LA")
        #expect(tz != nil)
        #expect(tz?.identifier == "America/Los_Angeles")
    }

    @Test("LDN resolves to Europe/London")
    func ldnAlias() {
        let tz = resolveTimezone("LDN")
        #expect(tz != nil)
        #expect(tz?.identifier == "Europe/London")
    }

    // MARK: - City Names

    @Test("bangkok resolves to Asia/Bangkok")
    func bangkokCity() {
        let tz = resolveTimezone("bangkok")
        #expect(tz != nil)
        #expect(tz?.identifier == "Asia/Bangkok")
    }

    @Test("san francisco resolves to America/Los_Angeles")
    func sanFranciscoCity() {
        let tz = resolveTimezone("san francisco")
        #expect(tz != nil)
        #expect(tz?.identifier == "America/Los_Angeles")
    }

    @Test("new york resolves to America/New_York")
    func newYorkCity() {
        let tz = resolveTimezone("new york")
        #expect(tz != nil)
        #expect(tz?.identifier == "America/New_York")
    }

    @Test("tokyo resolves to Asia/Tokyo")
    func tokyoCity() {
        let tz = resolveTimezone("tokyo")
        #expect(tz != nil)
        #expect(tz?.identifier == "Asia/Tokyo")
    }

    @Test("london resolves to Europe/London")
    func londonCity() {
        let tz = resolveTimezone("london")
        #expect(tz != nil)
        #expect(tz?.identifier == "Europe/London")
    }

    @Test("sydney resolves to Australia/Sydney")
    func sydneyCity() {
        let tz = resolveTimezone("sydney")
        #expect(tz != nil)
        #expect(tz?.identifier == "Australia/Sydney")
    }

    @Test("dubai resolves to Asia/Dubai")
    func dubaiCity() {
        let tz = resolveTimezone("dubai")
        #expect(tz != nil)
        #expect(tz?.identifier == "Asia/Dubai")
    }

    @Test("ho chi minh resolves to Asia/Ho_Chi_Minh")
    func hoChiMinhCity() {
        let tz = resolveTimezone("ho chi minh")
        #expect(tz != nil)
        #expect(tz?.identifier == "Asia/Ho_Chi_Minh")
    }

    // MARK: - Country Names

    @Test("japan resolves to Asia/Tokyo")
    func japanCountry() {
        let tz = resolveTimezone("japan")
        #expect(tz != nil)
        #expect(tz?.identifier == "Asia/Tokyo")
    }

    @Test("thailand resolves to Asia/Bangkok")
    func thailandCountry() {
        let tz = resolveTimezone("thailand")
        #expect(tz != nil)
        #expect(tz?.identifier == "Asia/Bangkok")
    }

    @Test("germany resolves to Europe/Berlin")
    func germanyCountry() {
        let tz = resolveTimezone("germany")
        #expect(tz != nil)
        #expect(tz?.identifier == "Europe/Berlin")
    }

    @Test("united kingdom resolves to Europe/London")
    func ukCountry() {
        let tz = resolveTimezone("united kingdom")
        #expect(tz != nil)
        #expect(tz?.identifier == "Europe/London")
    }

    @Test("india resolves to Asia/Kolkata")
    func indiaCountry() {
        let tz = resolveTimezone("india")
        #expect(tz != nil)
        #expect(tz?.identifier == "Asia/Kolkata")
    }

    // MARK: - Region Aliases

    @Test("Europe resolves to Europe/Paris")
    func europeRegion() {
        let tz = resolveTimezone("Europe")
        #expect(tz != nil)
        #expect(tz?.identifier == "Europe/Paris")
    }

    @Test("pacific resolves to America/Los_Angeles")
    func pacificRegion() {
        let tz = resolveTimezone("pacific")
        #expect(tz != nil)
        #expect(tz?.identifier == "America/Los_Angeles")
    }

    // MARK: - Timezone Abbreviations

    @Test("PT resolves to America/Los_Angeles")
    func ptAbbreviation() {
        let tz = resolveTimezone("PT")
        #expect(tz != nil)
        #expect(tz?.identifier == "America/Los_Angeles")
    }

    @Test("ET resolves to America/New_York")
    func etAbbreviation() {
        let tz = resolveTimezone("ET")
        #expect(tz != nil)
        #expect(tz?.identifier == "America/New_York")
    }

    @Test("JST resolves to Asia/Tokyo")
    func jstAbbreviation() {
        let tz = resolveTimezone("JST")
        #expect(tz != nil)
        #expect(tz?.identifier == "Asia/Tokyo")
    }

    @Test("ICT resolves to Asia/Bangkok")
    func ictAbbreviation() {
        let tz = resolveTimezone("ICT")
        #expect(tz != nil)
        #expect(tz?.identifier == "Asia/Bangkok")
    }

    @Test("UTC resolves to GMT")
    func utcAbbreviation() {
        let tz = resolveTimezone("UTC")
        #expect(tz != nil)
        #expect(tz?.identifier == "GMT")
    }

    // MARK: - Airport Codes

    @Test("SFO resolves to America/Los_Angeles")
    func sfoAirport() {
        let tz = resolveTimezone("SFO")
        #expect(tz != nil)
        #expect(tz?.identifier == "America/Los_Angeles")
    }

    @Test("JFK resolves to America/New_York")
    func jfkAirport() {
        let tz = resolveTimezone("JFK")
        #expect(tz != nil)
        #expect(tz?.identifier == "America/New_York")
    }

    @Test("LHR resolves to Europe/London")
    func lhrAirport() {
        let tz = resolveTimezone("LHR")
        #expect(tz != nil)
        #expect(tz?.identifier == "Europe/London")
    }

    @Test("NRT resolves to Asia/Tokyo")
    func nrtAirport() {
        let tz = resolveTimezone("NRT")
        #expect(tz != nil)
        #expect(tz?.identifier == "Asia/Tokyo")
    }

    @Test("SIN resolves to Asia/Singapore")
    func sinAirport() {
        let tz = resolveTimezone("SIN")
        #expect(tz != nil)
        #expect(tz?.identifier == "Asia/Singapore")
    }

    @Test("DXB resolves to Asia/Dubai")
    func dxbAirport() {
        let tz = resolveTimezone("DXB")
        #expect(tz != nil)
        #expect(tz?.identifier == "Asia/Dubai")
    }

    // MARK: - Case Insensitivity

    @Test("Case insensitivity: sf == SF")
    func caseInsensitiveLower() {
        let tz = resolveTimezone("sf")
        #expect(tz != nil)
        #expect(tz?.identifier == "America/Los_Angeles")
    }

    @Test("Case insensitivity: Bangkok == bangkok")
    func caseInsensitiveMixed() {
        let tz = resolveTimezone("Bangkok")
        #expect(tz != nil)
        #expect(tz?.identifier == "Asia/Bangkok")
    }

    @Test("Case insensitivity: TOKYO == tokyo")
    func caseInsensitiveUpper() {
        let tz = resolveTimezone("TOKYO")
        #expect(tz != nil)
        #expect(tz?.identifier == "Asia/Tokyo")
    }

    // MARK: - Whitespace Handling

    @Test("Leading/trailing whitespace is stripped")
    func whitespaceStripping() {
        let tz = resolveTimezone("  SF  ")
        #expect(tz != nil)
        #expect(tz?.identifier == "America/Los_Angeles")
    }

    // MARK: - IANA Identifier Fallback

    @Test("Full IANA identifier America/Los_Angeles works")
    func ianaFallback() {
        let tz = resolveTimezone("America/Los_Angeles")
        #expect(tz != nil)
        #expect(tz?.identifier == "America/Los_Angeles")
    }

    @Test("Full IANA identifier Asia/Tokyo works")
    func ianaFallbackTokyo() {
        let tz = resolveTimezone("Asia/Tokyo")
        #expect(tz != nil)
        #expect(tz?.identifier == "Asia/Tokyo")
    }

    // MARK: - Unknown Input

    @Test("Unknown input returns nil")
    func unknownReturnsNil() {
        let tz = resolveTimezone("xyzzyplugh")
        #expect(tz == nil)
    }

    @Test("Empty string returns nil")
    func emptyStringReturnsNil() {
        let tz = resolveTimezone("")
        #expect(tz == nil)
    }
}
