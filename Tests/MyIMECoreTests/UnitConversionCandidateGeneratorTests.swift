import Testing
@testable import MyIMECore

@Suite
struct UnitConversionCandidateGeneratorTests {
    @Test
    func convertsCentimeters() {
        #expect(
            UnitConversionCandidateGenerator.candidates(for: "10cm")
                == ["0.1m", "100mm"]
        )
    }

    @Test
    func convertsOtherLengthUnits() {
        #expect(
            UnitConversionCandidateGenerator.candidates(for: "1m")
                == ["100cm", "1000mm", "1,000mm"]
        )
        #expect(
            UnitConversionCandidateGenerator.candidates(for: "1km")
                == [
                    "1000m", "1,000m",
                    "100000cm", "100,000cm",
                    "1000000mm", "1,000,000mm"
                ]
        )
        #expect(
            UnitConversionCandidateGenerator.candidates(for: "1000m")
                == [
                    "1km", "100000cm", "100,000cm",
                    "1000000mm", "1,000,000mm", "千m"
                ]
        )
        #expect(
            UnitConversionCandidateGenerator.candidates(for: "10000m")
                == [
                    "10km", "1000000cm", "1,000,000cm",
                    "10000000mm", "10,000,000mm", "10千m", "1万m"
                ]
        )
        #expect(
            UnitConversionCandidateGenerator.candidates(for: "100km")
                .contains("100000m")
        )
        #expect(
            UnitConversionCandidateGenerator.candidates(for: "100km")
                .contains("100,000m")
        )
    }

    @Test
    func supportsDecimalsAndRejectsInvalidInput() {
        #expect(
            UnitConversionCandidateGenerator.candidates(for: "0.5m")
                == ["50cm", "500mm"]
        )
        #expect(UnitConversionCandidateGenerator.candidates(for: "10").isEmpty)
        #expect(UnitConversionCandidateGenerator.candidates(for: "cm").isEmpty)
        #expect(UnitConversionCandidateGenerator.candidates(for: "10inch").isEmpty)
    }

    @Test
    func convertsMassVolumeAndArea() {
        #expect(
            UnitConversionCandidateGenerator.candidates(for: "1kg")
                == [
                    "1000g", "1,000g",
                    "1000000mg", "1,000,000mg"
                ]
        )
        #expect(
            UnitConversionCandidateGenerator.candidates(for: "1L")
                == ["10dL", "100cL", "1000mL", "1,000mL"]
        )
        #expect(
            UnitConversionCandidateGenerator.candidates(for: "1ha")
                == [
                    "0.01km2", "10000m2", "10,000m2",
                    "100000000cm2", "100,000,000cm2",
                    "10000000000mm2", "10,000,000,000mm2"
                ]
        )
    }

    @Test
    func convertsTimeAndSpeed() {
        #expect(
            UnitConversionCandidateGenerator.candidates(for: "1h")
                == [
                    "0.041666666667d", "60min", "3600s", "3,600s",
                    "3600000ms", "3,600,000ms"
                ]
        )
        #expect(
            UnitConversionCandidateGenerator.candidates(for: "10m/s")
                == ["36km/h"]
        )
    }

    @Test
    func convertsTemperature() {
        #expect(
            UnitConversionCandidateGenerator.candidates(for: "0C")
                == ["32°F", "273.15K"]
        )
        #expect(
            UnitConversionCandidateGenerator.candidates(for: "32F")
                == ["0°C", "273.15K"]
        )
        #expect(
            UnitConversionCandidateGenerator.candidates(for: "273.15K")
                == ["0°C", "32°F"]
        )
    }
}
