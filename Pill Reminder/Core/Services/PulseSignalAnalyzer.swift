import Foundation

nonisolated struct PulseSignalSample: Sendable {
    let time: TimeInterval
    let value: Double
    let brightness: Double
}

nonisolated struct PulseEstimate: Sendable {
    let bpm: Int
    let quality: Double
}

nonisolated enum PulseSignalAnalyzer {
    static func basicSignalQuality(
        from samples: [PulseSignalSample],
        stabilizationDuration: TimeInterval
    ) -> Double {
        let usableSamples = continuousSamples(from: samples, after: stabilizationDuration)
        guard usableSamples.count > 20 else { return 0 }

        let values = usableSamples.map(\.value)
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { partial, value in
            partial + pow(value - mean, 2)
        } / Double(values.count)
        let standardDeviation = sqrt(variance)

        return min(max((standardDeviation - 0.000025) / 0.00024, 0), 0.62)
    }

    static func estimatePulse(
        from samples: [PulseSignalSample],
        stabilizationDuration: TimeInterval
    ) -> PulseEstimate? {
        guard samples.count > 45 else { return nil }

        let usableSamples = continuousSamples(from: samples, after: stabilizationDuration)
        guard usableSamples.count > 36 else { return nil }

        let smoothed = movingAverage(
            usableSamples.map(\.value),
            window: smoothingWindow(for: usableSamples)
        )
        guard smoothed.count == usableSamples.count else { return nil }

        let mean = smoothed.reduce(0, +) / Double(smoothed.count)
        let variance = smoothed.reduce(0) { partial, value in
            partial + pow(value - mean, 2)
        } / Double(smoothed.count)
        let standardDeviation = sqrt(variance)
        guard standardDeviation > 0.000025 else { return nil }

        let brightnessValues = usableSamples.map(\.brightness)
        let brightnessMean = brightnessValues.reduce(0, +) / Double(brightnessValues.count)
        let brightnessVariance = brightnessValues.reduce(0) { partial, value in
            partial + pow(value - brightnessMean, 2)
        } / Double(brightnessValues.count)
        let brightnessDeviation = sqrt(brightnessVariance)
        let brightnessNoise = brightnessDeviation / max(brightnessMean, 1)

        let candidates = [1.0, -1.0].compactMap { direction -> PulseEstimate? in
            let transformed = smoothed.map { ($0 - mean) * direction }
            let threshold = standardDeviation * 0.22
            var peakTimes: [TimeInterval] = []
            var peakValues: [Double] = []

            for index in 1..<(transformed.count - 1) {
                let value = transformed[index]
                guard value > threshold,
                      value > transformed[index - 1],
                      value >= transformed[index + 1]
                else {
                    continue
                }

                let time = usableSamples[index].time
                if let last = peakTimes.last, time - last < 0.28 {
                    if let lastValue = peakValues.last, value > lastValue {
                        peakTimes[peakTimes.count - 1] = time
                        peakValues[peakValues.count - 1] = value
                    }
                    continue
                }
                peakTimes.append(time)
                peakValues.append(value)
            }

            guard peakTimes.count >= 3 else { return nil }

            let intervals = zip(peakTimes.dropFirst(), peakTimes).map { $0 - $1 }
            guard !intervals.isEmpty else { return nil }

            let medianInterval = median(intervals)
            let stableIntervals = intervals.filter {
                abs($0 - medianInterval) / max(medianInterval, 0.001) < 0.34
            }
            guard stableIntervals.count >= max(2, intervals.count / 2) else { return nil }

            let averageInterval = stableIntervals.reduce(0, +) / Double(stableIntervals.count)
            let rawBPM = 60 / averageInterval
            let bpm = rawBPM
            guard (40...180).contains(bpm) else { return nil }

            let intervalVariance = stableIntervals.reduce(0) { partial, value in
                partial + pow(value - averageInterval, 2)
            } / Double(stableIntervals.count)
            let intervalDeviation = sqrt(intervalVariance)
            let intervalVariation = intervalDeviation / max(averageInterval, 0.001)
            guard intervalVariation < 0.42 else { return nil }

            let signalDuration = (peakTimes.last ?? 0) - (peakTimes.first ?? 0)
            let amplitudeScore = min(max((standardDeviation - 0.000025) / 0.00028, 0), 1)
            let regularityScore = 1 - min(intervalVariation / 0.40, 1)
            let durationScore = min(max(signalDuration / 7, 0), 1)
            let motionScore = 1 - min(brightnessNoise / 0.11, 1)
            let quality = max(
                0,
                min(
                    1,
                    regularityScore * 0.45
                        + amplitudeScore * 0.25
                        + durationScore * 0.2
                        + motionScore * 0.1
                )
            )

            return PulseEstimate(bpm: Int(bpm.rounded()), quality: quality)
        }

        guard let estimate = candidates.max(by: { $0.quality < $1.quality }) else {
            return nil
        }

        return estimate
    }

    static func frequencyEstimate(
        from samples: [PulseSignalSample],
        stabilizationDuration: TimeInterval
    ) -> PulseEstimate? {
        let usableSamples = continuousSamples(from: samples, after: stabilizationDuration)
        guard usableSamples.count > 90,
              let firstTime = usableSamples.first?.time,
              let lastTime = usableSamples.last?.time
        else {
            return nil
        }

        let duration = lastTime - firstTime
        guard duration > 5 else { return nil }

        let values = movingAverage(usableSamples.map(\.value), window: smoothingWindow(for: usableSamples))
        let trendWindow = min(max(11, smoothingWindow(for: usableSamples) * 15), values.count)
        let trend = movingAverage(values, window: trendWindow)
        guard values.count == trend.count else { return nil }

        var centered = zip(values, trend).map { $0 - $1 }
        let mean = centered.reduce(0, +) / Double(centered.count)
        centered = centered.map { $0 - mean }

        let energy = centered.reduce(0) { partial, value in
            partial + value * value
        }
        let rms = sqrt(energy / Double(centered.count))
        guard rms > 0.000018 else { return nil }

        let signal = centered.enumerated().map { index, value in
            let window = 0.54 - 0.46 * cos(2 * Double.pi * Double(index) / Double(max(centered.count - 1, 1)))
            return value / rms * window
        }
        let times = usableSamples.map { $0.time - firstTime }

        var powers: [(bpm: Double, power: Double)] = []
        powers.reserveCapacity(141)

        for bpm in stride(from: 40.0, through: 180.0, by: 1.0) {
            let frequency = bpm / 60
            var real = 0.0
            var imaginary = 0.0

            for index in signal.indices {
                let angle = 2 * Double.pi * frequency * times[index]
                real += signal[index] * cos(angle)
                imaginary += signal[index] * sin(angle)
            }

            powers.append((bpm, real * real + imaginary * imaginary))
        }

        guard let best = powers.max(by: { $0.power < $1.power }),
              best.power > 0
        else {
            return nil
        }

        let secondPower = powers
            .filter { abs($0.bpm - best.bpm) > 8 }
            .map(\.power)
            .max() ?? 0
        let separationScore = max(0, min(1, 1 - secondPower / best.power))
        let periodicityScore = periodicity(values: centered, times: times, bpm: best.bpm)
        guard separationScore >= 0.30, periodicityScore >= 0.55 else { return nil }
        let amplitudeScore = min(max((rms - 0.000018) / 0.00016, 0), 1)
        let durationScore = min(max(duration / 10, 0), 1)
        let bpm = best.bpm
        guard (40...180).contains(bpm) else { return nil }

        let quality = max(
            0,
            min(
                1,
                separationScore * 0.35
                    + periodicityScore * 0.35
                    + durationScore * 0.20
                    + amplitudeScore * 0.10
            )
        )
        guard quality >= 0.45 else { return nil }

        return PulseEstimate(bpm: Int(bpm.rounded()), quality: quality)
    }

    static func combinePulseEstimates(
        _ peakEstimate: PulseEstimate?,
        _ frequencyEstimate: PulseEstimate?
    ) -> PulseEstimate? {
        guard let peakEstimate, let frequencyEstimate else { return nil }
        let tolerance = max(6, Double(frequencyEstimate.bpm) * 0.08)
        guard Double(abs(peakEstimate.bpm - frequencyEstimate.bpm)) <= tolerance else { return nil }
        let peakWeight = max(0.05, peakEstimate.quality * peakEstimate.quality)
        let frequencyWeight = max(0.05, frequencyEstimate.quality * frequencyEstimate.quality)
        let bpm = (Double(peakEstimate.bpm) * peakWeight + Double(frequencyEstimate.bpm) * frequencyWeight)
            / (peakWeight + frequencyWeight)
        let quality = min(min(peakEstimate.quality, frequencyEstimate.quality) + 0.08, 1)
        return PulseEstimate(bpm: Int(bpm.rounded()), quality: quality)
    }

    static func reliableFinalEstimate(from estimates: [PulseEstimate]) -> PulseEstimate? {
        let valid = estimates.filter { (40...180).contains($0.bpm) && $0.quality >= 0.60 }
        guard valid.count >= 4, valid.count == estimates.count else { return nil }
        let medianBPM = median(valid.map { Double($0.bpm) })
        let tolerance = max(5, medianBPM * 0.06)
        guard valid.allSatisfy({ abs(Double($0.bpm) - medianBPM) <= tolerance }),
              let result = aggregateEstimate(from: valid), result.quality >= 0.65 else { return nil }
        return result
    }

    static func aggregateEstimate(from estimates: [PulseEstimate]) -> PulseEstimate? {
        let valid = estimates.filter {
            (40...180).contains(Double($0.bpm)) && $0.quality >= 0.45
        }
        guard !valid.isEmpty else { return nil }

        guard valid.count >= 3 else {
            return valid.max { $0.quality < $1.quality }
        }

        let medianBPM = median(valid.map { Double($0.bpm) })
        let close = valid.filter {
            abs(Double($0.bpm) - medianBPM) <= max(8, medianBPM * 0.14)
        }
        let stable = close.count >= 2 ? close : valid
        let weights = stable.map { max(0.05, $0.quality * $0.quality) }
        let totalWeight = weights.reduce(0, +)
        guard totalWeight > 0 else {
            return stable.max { $0.quality < $1.quality }
        }

        let weightedBPM = zip(stable, weights).reduce(0.0) { result, pair in
            result + Double(pair.0.bpm) * pair.1
        } / totalWeight
        let medianQuality = median(stable.map(\.quality))
        let spread = stable.map {
            abs(Double($0.bpm) - weightedBPM)
        }.reduce(0, +) / Double(stable.count)
        let stabilityPenalty = min(spread / 18, 0.28)
        let quality = max(
            0,
            min(
                1,
                medianQuality + min(Double(stable.count) / 18, 0.12) - stabilityPenalty
            )
        )

        return PulseEstimate(bpm: Int(weightedBPM.rounded()), quality: quality)
    }

    private static func continuousSamples(
        from samples: [PulseSignalSample],
        after stabilizationDuration: TimeInterval
    ) -> [PulseSignalSample] {
        let usable = samples.filter {
            $0.time >= stabilizationDuration && $0.time.isFinite && $0.value.isFinite && $0.brightness.isFinite
        }
        guard usable.count > 1 else { return [] }
        guard zip(usable.dropFirst(), usable).allSatisfy({
            let interval = $0.0.time - $0.1.time
            return interval > 0 && interval <= 0.25
        }) else { return [] }
        return usable
    }

    private static func smoothingWindow(for samples: [PulseSignalSample]) -> Int {
        let intervals = zip(samples.dropFirst(), samples).map { $0.0.time - $0.1.time }
        let interval = median(intervals)
        guard interval > 0 else { return 3 }
        return max(3, Int((0.10 / interval).rounded()) | 1)
    }

    private static func periodicity(values: [Double], times: [TimeInterval], bpm: Double) -> Double {
        guard values.count == times.count, bpm > 0 else { return 0 }
        let period = 60 / bpm
        var shiftedIndex = 1
        var cross = 0.0
        var leftEnergy = 0.0
        var rightEnergy = 0.0
        var count = 0
        for index in values.indices {
            let targetTime = times[index] + period
            while shiftedIndex < times.count && times[shiftedIndex] < targetTime {
                shiftedIndex += 1
            }
            guard shiftedIndex < times.count else { break }
            let previous = shiftedIndex - 1
            let interval = times[shiftedIndex] - times[previous]
            guard interval > 0 else { return 0 }
            let fraction = (targetTime - times[previous]) / interval
            let shifted = values[previous] + fraction * (values[shiftedIndex] - values[previous])
            let value = values[index]
            cross += value * shifted
            leftEnergy += value * value
            rightEnergy += shifted * shifted
            count += 1
        }
        guard count >= 30, leftEnergy > 0, rightEnergy > 0 else { return 0 }
        return min(max(cross / sqrt(leftEnergy * rightEnergy), 0), 1)
    }

    static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }

        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }

        return sorted[middle]
    }

    static func movingAverage(_ values: [Double], window: Int) -> [Double] {
        guard values.count >= window, window > 1 else { return values }
        var cumulative = [Double](repeating: 0, count: values.count + 1)
        for index in values.indices {
            cumulative[index + 1] = cumulative[index] + values[index]
        }
        return values.indices.map { index in
            let lower = max(0, index - window / 2)
            let upper = min(values.count, index + window / 2 + 1)
            return (cumulative[upper] - cumulative[lower]) / Double(upper - lower)
        }
    }
}
