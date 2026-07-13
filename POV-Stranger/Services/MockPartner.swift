import Foundation

struct MockPartner: Sendable {
    let countryCode: String
    let countryName: String
    let distanceKm: Double
    let weatherSummary: String
    let timeZoneIdentifier: String

    static let presets: [MockPartner] = [
        MockPartner(
            countryCode: "IS",
            countryName: "Iceland",
            distanceKm: 10_200,
            weatherSummary: "Snow · -2°C",
            timeZoneIdentifier: "Atlantic/Reykjavik"
        ),
        MockPartner(
            countryCode: "BR",
            countryName: "Brazil",
            distanceKm: 16_800,
            weatherSummary: "Humid · 31°C",
            timeZoneIdentifier: "America/Sao_Paulo"
        ),
        MockPartner(
            countryCode: "JP",
            countryName: "Japan",
            distanceKm: 4_300,
            weatherSummary: "Clear · 18°C",
            timeZoneIdentifier: "Asia/Tokyo"
        ),
        MockPartner(
            countryCode: "NO",
            countryName: "Norway",
            distanceKm: 8_900,
            weatherSummary: "Rain · 6°C",
            timeZoneIdentifier: "Europe/Oslo"
        ),
        MockPartner(
            countryCode: "KE",
            countryName: "Kenya",
            distanceKm: 7_400,
            weatherSummary: "Sunny · 24°C",
            timeZoneIdentifier: "Africa/Nairobi"
        ),
    ]

    static func random() -> MockPartner {
        presets.randomElement() ?? presets[0]
    }

    /// Placeholder gradient "photo" for mock partner uploads in development.
    func placeholderPhotoData(for hourIndex: Int) -> Data? {
        // Minimal 1x1 PNG varies by hour — real photos come in Phase 2.
        let colors: [UInt8] = [0x4A, 0x90, 0xD9, 0xFF]
        let offset = UInt8(hourIndex % 200)
        let bytes: [UInt8] = [
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
            colors[0] &+ offset, colors[1], colors[2], colors[3]
        ]
        return Data(bytes)
    }
}
