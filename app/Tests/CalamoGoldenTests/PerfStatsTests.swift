import Testing

struct PerfStatsTests {
    @Test func givenAnOddSampleWhenTheMedianIsTakenThenItIsTheMiddleValue() {
        // Given
        let values = [3.0, 1.0, 2.0]

        // Then
        #expect(PerfStats.median(values) == 2.0)
    }

    @Test func givenAnEvenSampleWhenTheMedianIsTakenThenItAveragesTheTwoMiddles() {
        // Given
        let values = [4.0, 1.0, 3.0, 2.0]

        // Then
        #expect(PerfStats.median(values) == 2.5)
    }

    @Test func givenTenValuesWhenP90IsTakenThenItIsTheNinthSortedValue() {
        // Given: nearest-rank on n=10 picks ceil(0.9·10) = the 9th value
        let values = [50.0, 90.0, 10.0, 70.0, 30.0, 100.0, 20.0, 80.0, 40.0, 60.0]

        // Then
        #expect(PerfStats.p90(values) == 90.0)
    }

    @Test func givenASingleValueWhenP90IsTakenThenItIsThatValue() {
        // Given
        let values = [7.0]

        // Then
        #expect(PerfStats.p90(values) == 7.0)
    }

    @Test func givenAFullHarnessRunWhenP90IsTakenThenItMatchesTheNearestRank() {
        // Given: the harness size, 15 takes × 3 passes — ceil(0.9·45) = 41st
        let values = (1...45).map(Double.init).shuffled()

        // Then
        #expect(PerfStats.p90(values) == 41.0)
    }

    @Test func givenStageStampsWhenTheMeasureIsDerivedThenStagesAndE2eComeOutInMilliseconds() {
        // Given: nanosecond stamps shaped like the reference median dictation
        let stamps = StageStamps(
            released: 500,
            transcribing: 2_000_500,
            cleaning: 176_000_500,
            inserting: 1_006_000_500,
            inserted: 1_007_000_500)

        // When
        let measure = PerfMeasure(stamps)

        // Then
        #expect(measure.ffiMs == 2.0)
        #expect(measure.asrMs == 174.0)
        #expect(measure.cleanupMs == 830.0)
        #expect(measure.spellingMs == 1.0)
        #expect(measure.e2eMs == 1007.0)
    }
}
