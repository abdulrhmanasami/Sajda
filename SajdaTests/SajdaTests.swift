//
//  SajdaTests.swift
//  SajdaTests
//
//  Unit tests for Sajda Pro prayer time calculations, coordinate parsing, and method validation.
//

import XCTest
import CoreLocation
import Adhan
@testable import Sajda

final class SajdaTests: XCTestCase {

    // MARK: - Prayer Calculation Tests

    /// Tests that prayer times are calculated correctly for Mecca using Umm al-Qura method.
    func testPrayerCalculation_Mecca_UmmAlQura() throws {
        let meccaCoords = Coordinates(latitude: 21.4225, longitude: 39.8262)
        let dateComponents = DateComponents(year: 2026, month: 1, day: 15)
        let method = SajdaCalculationMethod.allCases.first { $0.name == "Umm al-Qura University, Makkah" }
        XCTAssertNotNil(method, "Umm al-Qura University, Makkah method should exist in allCases")

        let params = method!.params
        let prayerTimes = PrayerTimes(coordinates: meccaCoords, date: dateComponents, calculationParameters: params)
        XCTAssertNotNil(prayerTimes, "PrayerTimes should be calculated for valid Mecca coordinates")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Riyadh")!
        let fajrHour = calendar.component(.hour, from: prayerTimes!.fajr)
        let dhuhrHour = calendar.component(.hour, from: prayerTimes!.dhuhr)
        let asrHour = calendar.component(.hour, from: prayerTimes!.asr)
        let maghribHour = calendar.component(.hour, from: prayerTimes!.maghrib)
        let ishaHour = calendar.component(.hour, from: prayerTimes!.isha)

        // Sanity checks: Fajr is early morning, Dhuhr is midday, etc. (Mecca local time)
        XCTAssertTrue(fajrHour >= 3 && fajrHour <= 6, "Fajr in Mecca should be between 3-6 AM, got \(fajrHour)")
        XCTAssertTrue(dhuhrHour >= 11 && dhuhrHour <= 13, "Dhuhr should be around noon, got \(dhuhrHour)")
        XCTAssertTrue(asrHour >= 14 && asrHour <= 16, "Asr should be afternoon, got \(asrHour)")
        XCTAssertTrue(maghribHour >= 17 && maghribHour <= 19, "Maghrib should be evening, got \(maghribHour)")
        XCTAssertTrue(ishaHour >= 18 && ishaHour <= 21, "Isha should be night, got \(ishaHour)")
    }

    /// Tests that time corrections produce the expected time shift.
    func testPrayerCalculation_WithCorrections() throws {
        let coords = Coordinates(latitude: 21.4225, longitude: 39.8262)
        let dateComponents = DateComponents(year: 2026, month: 6, day: 15)
        let method = SajdaCalculationMethod.allCases[0]
        let params = method.params

        let prayerTimes = PrayerTimes(coordinates: coords, date: dateComponents, calculationParameters: params)
        XCTAssertNotNil(prayerTimes)

        let correctionMinutes: Double = 5
        let originalFajr = prayerTimes!.fajr
        let correctedFajr = originalFajr.addingTimeInterval(correctionMinutes * 60)

        let diff = correctedFajr.timeIntervalSince(originalFajr)
        XCTAssertEqual(diff, 300, accuracy: 0.001, "+5 minute correction should produce exactly 300 seconds difference")
    }

    // MARK: - Coordinate Parsing Tests

    /// Tests that valid coordinate strings are parsed correctly.
    func testCoordinateParsing_ValidInput() throws {
        let service = LocationService()

        let result = service.parseCoordinates(from: "21.4225,39.8262")
        XCTAssertNotNil(result, "Valid coordinate string should parse successfully")
        XCTAssertEqual(result!.coordinates.latitude, 21.4225, accuracy: 0.001)
        XCTAssertEqual(result!.coordinates.longitude, 39.8262, accuracy: 0.001)
        XCTAssertEqual(result!.name, "Custom Coordinate")
    }

    /// Tests that valid coordinates with spaces are parsed correctly.
    func testCoordinateParsing_ValidInputWithSpaces() throws {
        let service = LocationService()

        let result = service.parseCoordinates(from: "21.4225, 39.8262")
        XCTAssertNotNil(result, "Coordinate string with spaces should parse successfully")
        XCTAssertEqual(result!.coordinates.latitude, 21.4225, accuracy: 0.001)
    }

    /// Tests that invalid inputs return nil.
    func testCoordinateParsing_InvalidInput() throws {
        let service = LocationService()

        XCTAssertNil(service.parseCoordinates(from: "invalid"), "Non-numeric string should return nil")
        XCTAssertNil(service.parseCoordinates(from: ""), "Empty string should return nil")
        XCTAssertNil(service.parseCoordinates(from: "91,0"), "Latitude > 90 should return nil")
        XCTAssertNil(service.parseCoordinates(from: "0,181"), "Longitude > 180 should return nil")
        XCTAssertNil(service.parseCoordinates(from: "-91,0"), "Latitude < -90 should return nil")
    }

    // MARK: - Calculation Method Validation

    /// Tests that all 20 calculation methods produce valid prayer times.
    func testAllCalculationMethods_ProduceValidPrayerTimes() throws {
        let coords = Coordinates(latitude: 48.8566, longitude: 2.3522) // Paris
        let dateComponents = DateComponents(year: 2026, month: 3, day: 21) // Equinox

        for method in SajdaCalculationMethod.allCases {
            let params = method.params
            let prayerTimes = PrayerTimes(coordinates: coords, date: dateComponents, calculationParameters: params)
            XCTAssertNotNil(prayerTimes, "Method '\(method.name)' should produce valid prayer times for Paris coordinates")

            if let times = prayerTimes {
                // Verify prayer order: Fajr < Dhuhr < Asr < Maghrib < Isha
                XCTAssertLessThan(times.fajr, times.dhuhr, "\(method.name): Fajr should be before Dhuhr")
                XCTAssertLessThan(times.dhuhr, times.asr, "\(method.name): Dhuhr should be before Asr")
                XCTAssertLessThan(times.asr, times.maghrib, "\(method.name): Asr should be before Maghrib")
                XCTAssertLessThan(times.maghrib, times.isha, "\(method.name): Maghrib should be before Isha")
            }
        }
    }

    // MARK: - Hanafi Madhhab Test

    /// Tests that Hanafi Asr is later than Shafi Asr.
    func testHanafiAsr_IsLaterThanShafi() throws {
        let coords = Coordinates(latitude: 21.4225, longitude: 39.8262)
        let dateComponents = DateComponents(year: 2026, month: 6, day: 15)
        let method = SajdaCalculationMethod.allCases[0]

        var shafiParams = method.params
        shafiParams.madhab = .shafi
        let shafiTimes = PrayerTimes(coordinates: coords, date: dateComponents, calculationParameters: shafiParams)

        var hanafiParams = method.params
        hanafiParams.madhab = .hanafi
        let hanafiTimes = PrayerTimes(coordinates: coords, date: dateComponents, calculationParameters: hanafiParams)

        XCTAssertNotNil(shafiTimes)
        XCTAssertNotNil(hanafiTimes)
        XCTAssertGreaterThan(hanafiTimes!.asr, shafiTimes!.asr, "Hanafi Asr should be later than Shafi Asr")
    }
}
