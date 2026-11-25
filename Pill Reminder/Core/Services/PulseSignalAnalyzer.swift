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

nonisolated struct PulseOpticalSample: Sendable {
    let time: TimeInterval
    let red: Double
    let green: Double
    let blue: Double
    let regionalRed: SIMD4<Double>?
    let nativeLuma: Double?

    init(
        time: TimeInterval, red: Double, green: Double, blue: Double,
        regionalRed: SIMD4<Double>? = nil, nativeLuma: Double? = nil
    ) {
        self.time = time
        self.red = red
        self.green = green
        self.blue = blue
        self.regionalRed = regionalRed
        self.nativeLuma = nativeLuma
    }

    var brightness: Double { (red + green + blue) / 3 }
    var redFraction: Double { red / max(red + green + blue, 1) }
}

nonisolated enum PulseLensContact {
    case searching
    case tooDark
    case covered

    static func isFingerColored(red: Double, green: Double, blue: Double) -> Bool {
        let other = max(green, blue)
        return red - other >= 14 && red >= other * 1.5
    }

    static func classify(red: Double, green: Double, blue: Double, fingerColoredFraction: Double) -> Self {
        if max(red, green, blue) < 12 { return .tooDark }
        guard fingerColoredFraction >= 0.85 else { return .searching }
        return red >= 64 ? .covered : .tooDark
    }

    static func maintainsCoverage(red: Double, fingerColoredFraction: Double) -> Bool {
        red >= 40 && fingerColoredFraction >= 0.70
    }
}

nonisolated struct PulseContactGate {
    private var coveredSince: TimeInterval?

    mutating func confirm(_ contact: PulseLensContact, at time: TimeInterval) -> Bool {
        guard contact == .covered else {
            coveredSince = nil
            return false
        }
        if coveredSince == nil { coveredSince = time }
        return time - (coveredSince ?? time) >= 0.7
    }
}

nonisolated struct PulseTorchGate {
    enum Decision { case waiting, enable, ready, unavailable }

    private var waitingSince: TimeInterval?
    private var litSince: TimeInterval?
    private var lastEnableRequest: TimeInterval?

    mutating func update(isLit: Bool, canEnable: Bool, at now: TimeInterval) -> Decision {
        if waitingSince == nil { waitingSince = now }
        if isLit {
            if litSince == nil { litSince = now }
            if now - (litSince ?? now) >= 0.4 {
                waitingSince = nil
                lastEnableRequest = nil
                return .ready
            }
        } else {
            litSince = nil
        }

        if now - (waitingSince ?? now) >= 4 { return .unavailable }
        if !isLit, canEnable, lastEnableRequest.map({ now - $0 >= 1 }) ?? true {
            lastEnableRequest = now
            return .enable
        }
        return .waiting
    }
}

nonisolated struct PulseMeasurementEvidence {
    private var recent: [PulseEstimate?] = []
    private(set) var progress: Double = 0
    private static let requiredCount = 4
    static let minimumQuality = 0.65

    mutating func record(_ estimate: PulseEstimate?) -> PulseEstimate? {
        let current = estimate.flatMap { $0.quality >= Self.minimumQuality ? $0 : nil }
        recent.append(current)
        if recent.count > 6 { recent.removeFirst() }

        let valid = recent.compactMap { $0 }
        guard let reference = valid.last else {
            progress = 0
            return nil
        }

        let tolerance = max(5, Double(reference.bpm) * 0.06)
        let matching = valid.filter { Double(abs($0.bpm - reference.bpm)) <= tolerance }
        progress = Double(min(matching.count, Self.requiredCount - 1)) / Double(Self.requiredCount)
        guard current != nil,
              let result = PulseSignalAnalyzer.reliableFinalEstimate(from: matching),
              Double(abs(result.bpm - reference.bpm)) <= tolerance else { return nil }
        progress = 1
        return result
    }
}

nonisolated enum PulseSignalAnalyzer {
    static let maximumSampleGap: TimeInterval = 0.30
    static let minimumFrequencySampleCount = 91
    static let longestAnalysisWindow: TimeInterval = 18

    static func estimateRecentPulse(from samples: [PulseOpticalSample]) -> PulseEstimate? {
        guard let first = samples.first?.time, let last = samples.last?.time else { return nil }
        let recentStart = min(last - 9, samples.suffix(minimumFrequencySampleCount).first?.time ?? last)
        if let estimate = estimateOpticalPulse(from: samples, startingAt: recentStart) { return estimate }
        guard last - first >= 12 else { return nil }
        return estimateOpticalPulse(from: samples, startingAt: last - longestAnalysisWindow, requireRepeatedPhase: true)
    }

    static func estimateOpticalPulse(
        from samples: [PulseOpticalSample], startingAt start: TimeInterval, requireRepeatedPhase: Bool = false
    ) -> PulseEstimate? {
        let window = samples.filter { $0.time >= start }
        guard window.count >= minimumFrequencySampleCount else { return nil }
        let brightness = window.map(\.brightness).sorted()
        let tail = brightness.count / 20
        guard brightness[brightness.count - 1 - tail] - brightness[tail] <= max(8, brightness[brightness.count / 2] * 0.18) else { return nil }
        var varyingChannels = 0
        for channel in [\PulseOpticalSample.red, \.green, \.blue] {
            let levels = window.map { $0[keyPath: channel] }.sorted()
            let span = levels[levels.count - 1 - tail] - levels[tail]
            guard span <= max(12, levels[levels.count / 2] * 0.45) else { return nil }
            if span > 0.3 { varyingChannels += 1 }
        }

        func estimate(_ value: (PulseOpticalSample) -> Double) -> PulseEstimate? {
            guard let contour = pulseBand(from: window, channel: value),
                  let spectrum = frequencyEstimate(from: contour, requireRecentPhase: requireRepeatedPhase),
                  !requireRepeatedPhase || spectrum.repeatsAcrossHalves else { return nil }
            if let confirmed = combinePulseEstimates(estimatePulse(from: contour), spectrum.estimate) {
                return confirmed
            }
            return spectrum.repeatsAcrossHalves ? spectrum.estimate : nil
        }

        func intensity(_ value: (PulseOpticalSample) -> Double) -> PulseEstimate? {
            estimate { value($0) / 255 }
        }

        func consensus(_ candidates: [PulseEstimate?]) -> PulseEstimate? {
            let valid = candidates.compactMap { $0 }.filter { $0.quality >= PulseMeasurementEvidence.minimumQuality }
            let groups = valid.map { reference in
                valid.filter { Double(abs($0.bpm - reference.bpm)) <= max(5, Double(reference.bpm) * 0.06) }
            }
            guard let group = groups.max(by: { $0.count < $1.count }), group.count * 2 > valid.count else { return nil }
            if group.count == 1 {
                let minimum = varyingChannels > 1 ? 0.88 : 0.72
                return group[0].quality >= minimum ? group[0] : nil
            }
            return PulseEstimate(bpm: Int(median(group.map { Double($0.bpm) }).rounded()), quality: median(group.map(\.quality)))
        }

        let red = intensity(\.red)
        let green = intensity(\.green)
        if let red, let green, let agreed = consensus([red, green]) { return agreed }
        var channels = [red, green, intensity(\.blue)]
        if window.first?.nativeLuma != nil {
            channels.append(intensity { $0.nativeLuma ?? 0 })
        }
        channels.append(estimate(\.redFraction))
        if let agreed = consensus(channels) { return agreed }
        channels.append(estimate { ($0.green - $0.blue) / max(1, $0.red - min($0.green, $0.blue)) })
        if let agreed = consensus(channels) { return agreed }
        if window.first?.regionalRed != nil {
            let regions = (0..<4).compactMap { region in
                intensity { $0.regionalRed?[region] ?? 0 }
            }
            if regions.count >= 2 { return consensus(channels + regions) }
        }
        return nil
    }

    private static func pulseBand(
        from samples: [PulseOpticalSample], channel: (PulseOpticalSample) -> Double
    ) -> [PulseSignalSample]? {
        let raw = samples.map(channel)
        guard let first = raw.first, raw.allSatisfy(\.isFinite),
              raw.contains(where: { abs($0 - first) > 0.000025 }) else { return nil }
        var values = raw
        for i in 1..<(values.count - 1) {
            let left = raw[i - 1]
            let right = raw[i + 1]
            values[i] = min(max(raw[i], min(left, right)), max(left, right))
        }
        for pass in 0..<2 {
            let forward = pass == 0
            let start = forward ? values.startIndex : values.count - 1
            let step = forward ? 1 : -1
            var baseline = values[start]
            var smoothed = 0.0
            values[start] = 0
            for offset in 1..<values.count {
                let i = start + offset * step
                let dt = (samples[i].time - samples[i - step].time) * Double(step)
                guard dt > 0, dt <= maximumSampleGap else { return nil }
                let value = values[i]
                baseline += (1 - exp(-2 * .pi * 0.55 * dt)) * (value - baseline)
                smoothed += (1 - exp(-2 * .pi * 3.5 * dt)) * (value - baseline - smoothed)
                values[i] = smoothed
            }
        }
        return zip(samples, values).map {
            PulseSignalSample(time: $0.time, value: $1, brightness: $0.brightness)
        }
    }

    private static func estimatePulse(from samples: [PulseSignalSample]) -> PulseEstimate? {
        let smoothed = samples.map(\.value)

        let mean = smoothed.reduce(0, +) / Double(smoothed.count)
        let variance = smoothed.reduce(0) { partial, value in
            partial + pow(value - mean, 2)
        } / Double(smoothed.count)
        let standardDeviation = sqrt(variance)
        guard standardDeviation > 0.000025 else { return nil }

        let brightnessValues = samples.map(\.brightness)
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

                let time = samples[index].time
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

    private static func frequencyEstimate(
        from samples: [PulseSignalSample], requireRecentPhase: Bool
    ) -> (estimate: PulseEstimate, repeatsAcrossHalves: Bool)? {
        guard let firstTime = samples.first?.time, let lastTime = samples.last?.time else { return nil }

        let duration = lastTime - firstTime
        guard duration > 5 else { return nil }

        let values = samples.map(\.value)
        let mean = values.reduce(0, +) / Double(values.count)
        let centered = values.map { $0 - mean }

        let energy = centered.reduce(0) { partial, value in
            partial + value * value
        }
        let rms = sqrt(energy / Double(centered.count))
        guard rms > 0.000018 else { return nil }

        guard let currentStart = samples.firstIndex(where: { $0.time >= lastTime - 3 }) else { return nil }
        let current = samples[currentStart...]
        let currentMean = current.reduce(0) { $0 + $1.value } / Double(current.count)
        let currentEnergy = current.reduce(0) { $0 + ($1.value - currentMean) * ($1.value - currentMean) }
        guard sqrt(currentEnergy / Double(current.count)) >= max(0.000018, rms * 0.20) else { return nil }

        let signal = centered.enumerated().map { index, value in
            let window = 0.54 - 0.46 * cos(2 * Double.pi * Double(index) / Double(max(centered.count - 1, 1)))
            return value / rms * window
        }
        let times = samples.map { $0.time - firstTime }

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
        guard separationScore >= 0.30 else { return nil }
        let middle = times.firstIndex { $0 >= duration / 2 } ?? times.endIndex
        let omega = 2 * Double.pi * best.bpm / 60
        func projection(_ indices: Range<Int>) -> (phase: SIMD2<Double>, strength: Double) {
            let localMean = indices.reduce(0) { $0 + centered[$1] } / Double(indices.count)
            var vector = SIMD2<Double>.zero
            var energy = 0.0
            for i in indices {
                let x = centered[i] - localMean
                let angle = omega * times[i]
                vector += x * SIMD2(cos(angle), sin(angle))
                energy += x * x
            }
            let power = (vector * vector).sum()
            guard power > 0, energy > 0 else { return (.zero, 0) }
            return (vector / sqrt(power), min(1, 2 * power / (Double(indices.count) * energy)))
        }
        let left = projection(0..<middle)
        let right = projection(middle..<times.count)
        let repeats = duration * best.bpm / 60 >= 4 && separationScore >= 0.45
            && min(left.strength, right.strength) >= 0.25 && (left.phase * right.phase).sum() >= 0.72
        if requireRecentPhase {
            guard repeats, let recentStart = times.firstIndex(where: { $0 >= duration - 4 }) else { return nil }
            let recent = projection(recentStart..<times.count)
            guard recent.strength >= 0.25, (recent.phase * right.phase).sum() >= 0.72 else { return nil }
        }
        guard periodicityScore >= 0.55 || repeats else { return nil }
        let amplitudeScore = min(max((rms - 0.000018) / 0.00016, 0), 1)
        let durationScore = min(max(duration / 10, 0), 1)
        let bpm = best.bpm
        guard (40...180).contains(bpm) else { return nil }

        let repetitionScore = repeats ? max(periodicityScore, sqrt(left.strength * right.strength)) : periodicityScore
        let quality = max(
            0,
            min(
                1,
                separationScore * 0.35
                    + repetitionScore * 0.35
                    + durationScore * 0.20
                    + amplitudeScore * 0.10
            )
        )
        guard quality >= 0.45 else { return nil }

        return (PulseEstimate(bpm: Int(bpm.rounded()), quality: quality), repeats)
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
        guard valid.count >= 4 else { return nil }
        let medianBPM = median(valid.map { Double($0.bpm) })
        let tolerance = max(5, medianBPM * 0.06)
        let consistent = valid.filter { abs(Double($0.bpm) - medianBPM) <= tolerance }
        guard consistent.count >= 4,
              let result = aggregateEstimate(from: consistent), result.quality >= 0.65 else { return nil }
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
}
