import SwiftUI

private enum IntroSlide: Int, CaseIterable {
    case measure, reading, history, trends

    var artwork: String {
        switch self {
        case .measure: "intro-fingertip"
        case .reading: "intro-reading"
        case .history: "intro-journal"
        case .trends: "intro-trend"
        }
    }

    var title: (String, String) {
        switch self {
        case .measure: ("Measure your", "heart rate")
        case .reading: ("Learn more about", "your pulse")
        case .history: ("Start saving", "measurements")
        case .trends: ("Track your", "pulse trends")
        }
    }

    var detail: String {
        switch self {
        case .measure: "Hold your phone and gently cover the rear camera near the flash with the pad of your index finger."
        case .reading: "Hold still until your result appears in beats per minute."
        case .history: "Find each reading in History, along with the date and time."
        case .trends: "Compare your readings by week, month or year."
        }
    }
}

private enum ProfileQuestion: Int, CaseIterable {
    case sex, height, weight

    var title: String {
        switch self {
        case .sex: "Your sex"
        case .height: "Your height"
        case .weight: "Your weight"
        }
    }

    var hint: String {
        switch self {
        case .sex: "This is an optional detail for your profile in Settings. You can leave it blank and still use the camera to measure your pulse."
        case .height: "Choose your height in centimetres. If you also add your weight, the app uses both values to calculate your body mass index (BMI)."
        case .weight: "Choose your weight in kilograms. When you enter both height and weight, you’ll see your BMI in Settings. You can skip this and still save pulse readings."
        }
    }

    private var numericAnswer: (field: PulseProfile.Field, initial: Int)? {
        switch self {
        case .sex: nil
        case .height: (.height, 170)
        case .weight: (.weight, 70)
        }
    }

    func leave(_ profile: inout PulseProfile, skipping: Bool) {
        if let answer = numericAnswer {
            profile[keyPath: answer.field.key] = skipping ? nil : (profile[keyPath: answer.field.key] ?? answer.initial)
        } else if skipping {
            profile.sex = nil
        }
    }

    @ViewBuilder
    func control(profile: Binding<PulseProfile>) -> some View {
        if let answer = numericAnswer {
            let selection = Binding(
                get: { profile.wrappedValue[keyPath: answer.field.key] ?? answer.initial },
                set: { profile.wrappedValue[keyPath: answer.field.key] = $0 }
            )
            Picker(title, selection: selection) {
                ForEach(answer.field.range, id: \.self) { value in
                    Text("\(value) \(answer.field.unit)").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .background(.white, in: RoundedRectangle(cornerRadius: 22))
        } else {
            VStack(spacing: 10) {
                ForEach(PulseProfile.Sex.allCases, id: \.self) { sex in
                    let selected = profile.wrappedValue.sex == sex
                    Button { profile.wrappedValue.sex = sex } label: {
                        HStack(spacing: 14) {
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(selected ? PulseStyle.accent : PulseStyle.secondary)
                            Text(sex.rawValue).font(.body.weight(.medium))
                            Spacer()
                        }
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .frame(minHeight: 54)
                        .background(.white, in: RoundedRectangle(cornerRadius: 18))
                        .overlay {
                            if selected { RoundedRectangle(cornerRadius: 18).strokeBorder(PulseStyle.accent) }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }
}

private enum OnboardingStep: Hashable {
    case intro(IntroSlide)
    case welcome
    case question(ProfileQuestion)
    case preparation

    var progress: (index: Int, count: Int)? {
        switch self {
        case let .intro(slide): (slide.rawValue, IntroSlide.allCases.count)
        case let .question(question): (question.rawValue, ProfileQuestion.allCases.count)
        case .welcome, .preparation: nil
        }
    }
}

private enum OnboardingSection {
    case introduction, profile

    var firstPage: OnboardingStep { self == .introduction ? .intro(.measure) : .welcome }

    var pages: [OnboardingStep] {
        switch self {
        case .introduction: IntroSlide.allCases.map(OnboardingStep.intro) + [.welcome]
        case .profile: [.welcome] + ProfileQuestion.allCases.map(OnboardingStep.question) + [.preparation]
        }
    }
}

struct OnboardingView: View {
    @AppStorage(AppConstants.Onboarding.finishedIntroductionKey) private var hasFinishedIntroduction = false
    @State private var profile = PulseProfile.load()
    let onFinish: () -> Void

    var body: some View {
        let section: OnboardingSection = hasFinishedIntroduction ? .profile : .introduction
        OnboardingPager(section: section, profile: $profile) {
            switch section {
            case .introduction: hasFinishedIntroduction = true
            case .profile: onFinish()
            }
        }
        .id(section)
        .foregroundStyle(PulseStyle.primaryText)
        .background(PulseStyle.background.ignoresSafeArea())
    }
}

private struct OnboardingPager: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding private var profile: PulseProfile
    @State private var step: OnboardingStep
    @State private var preparationReady = false
    let section: OnboardingSection
    let onComplete: () -> Void

    init(section: OnboardingSection, profile: Binding<PulseProfile>, onComplete: @escaping () -> Void) {
        self.section = section
        self._profile = profile
        self._step = State(initialValue: section.firstPage)
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: Binding(get: { step }, set: { select($0) })) {
                ForEach(section.pages, id: \.self) { page in
                    Tab(value: page) {
                        switch page {
                        case let .intro(slide):
                            IntroSlideView(slide: slide)
                        case .welcome:
                            ProfileWelcomePage()
                        case let .question(question):
                            QuestionPage(question: question, profile: $profile)
                        case .preparation:
                            PreparationPage(profile: profile, isCurrent: step == .preparation) {
                                preparationReady = true
                            }
                        }
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack(spacing: 8) {
                if let progress = step.progress {
                    if case .question = step {
                        HStack {
                            pageIndicator(progress)
                            Spacer()
                            Button("Skip question") { move(1, skipping: true) }
                                .buttonStyle(.plain)
                                .font(.subheadline.weight(.medium)).foregroundStyle(PulseStyle.secondary)
                                .frame(minHeight: 44).accessibilityIdentifier("onboarding.skip")
                        }
                    } else {
                        pageIndicator(progress)
                    }
                }
                Button("Continue") {
                    if step == .preparation {
                        if preparationReady { onComplete() }
                    } else {
                        move(1)
                    }
                }
                .buttonStyle(PulsePrimaryButton())
                .disabled((step == .question(.sex) && profile.sex == nil) || waitingForPreparation)
                .opacity(waitingForPreparation ? 0 : 1)
                .accessibilityHidden(waitingForPreparation)
                .accessibilityIdentifier("onboarding.next")
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: waitingForPreparation)
            }
            .frame(maxWidth: 480)
            .padding(.horizontal, 22).padding(.bottom, 8)
        }
    }

    private var waitingForPreparation: Bool { step == .preparation && !preparationReady }

    private func pageIndicator(_ progress: (index: Int, count: Int)) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<progress.count, id: \.self) { index in
                Capsule().fill(index == progress.index ? PulseStyle.accent : PulseStyle.separator)
                    .frame(width: index == progress.index ? 23 : 10, height: 5)
            }
        }
        .frame(height: 22)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page")
        .accessibilityValue("\(progress.index + 1) of \(progress.count)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: move(1)
            case .decrement: move(-1)
            @unknown default: break
            }
        }
    }

    private func select(_ destination: OnboardingStep, skipping: Bool = false) {
        let pages = section.pages
        guard step != destination, let current = pages.firstIndex(of: step),
              let target = pages.firstIndex(of: destination) else { return }
        if section == .introduction, destination == .welcome {
            onComplete()
            return
        }
        if case let .question(question) = step, target == current + 1 {
            question.leave(&profile, skipping: skipping)
        }
        preparationReady = false
        step = destination
    }

    private func move(_ direction: Int, skipping: Bool = false) {
        let pages = section.pages
        guard let current = pages.firstIndex(of: step), pages.indices.contains(current + direction) else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) {
            select(pages[current + direction], skipping: skipping)
        }
    }
}

private struct IntroSlideView: View {
    let slide: IntroSlide

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 8)
                    Image(slide.artwork).resizable().scaledToFit()
                        .frame(maxWidth: 510)
                        .frame(height: max(148, min(proxy.size.width * 1.2, proxy.size.height * 0.66)))
                        .accessibilityHidden(true)
                    Spacer(minLength: 18)
                    VStack(spacing: 12) {
                        VStack(spacing: 0) {
                            Text(slide.title.0)
                            Text(slide.title.1).foregroundStyle(PulseStyle.accent)
                        }
                        .font(.largeTitle.bold())
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(slide.title.0) \(slide.title.1)")
                        .accessibilityAddTraits(.isHeader)
                        Text(slide.detail).font(.body).foregroundStyle(PulseStyle.secondary)
                            .frame(maxWidth: 400)
                    }
                    .padding(.horizontal, 24)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 18)
                }
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize).scrollIndicators(.hidden)
        }
    }
}

private struct ProfileWelcomePage: View {
    var body: some View {
        GeometryReader { proxy in
            let artSize = min(150, proxy.size.width * 0.36, proxy.size.height * 0.27)
            ScrollView {
                VStack(spacing: 0) {
                    Image(decorative: "intro-profile")
                        .resizable().scaledToFit()
                        .frame(width: artSize, height: artSize)
                    Text("Set up your profile")
                        .font(.title.bold()).accessibilityAddTraits(.isHeader)
                        .padding(.top, 20)
                    Text("Choose the details you’d like to keep with your pulse history. Each question is optional.")
                        .font(.body).foregroundStyle(PulseStyle.secondary)
                        .frame(maxWidth: 320)
                        .padding(.top, 10)
                }
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24).padding(.vertical, 18)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize).scrollIndicators(.hidden)
        }
    }
}

private struct QuestionPage: View {
    let question: ProfileQuestion
    @Binding var profile: PulseProfile

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Good to know", systemImage: "heart.text.square.fill")
                            .font(.headline)
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(PulseStyle.accent)
                        Text(question.hint)
                            .font(.body).foregroundStyle(PulseStyle.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white, in: RoundedRectangle(cornerRadius: 22))
                    Spacer(minLength: 6)
                    Text(question.title).font(.title.bold()).accessibilityAddTraits(.isHeader)
                    question.control(profile: $profile)
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 22).padding(.vertical, 20)
                .frame(maxWidth: 520, minHeight: proxy.size.height)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize).scrollIndicators(.hidden)
        }
    }
}

private struct PreparationPage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var completed = 0
    @State private var fill = 0
    let profile: PulseProfile
    let isCurrent: Bool
    let onReady: () -> Void

    private enum TaskRow: String, Identifiable {
        case details = "Review your answers"
        case bmi = "Calculate your BMI"
        case save = "Save your profile"

        var id: Self { self }
        var symbol: String {
            switch self {
            case .details: "list.bullet.clipboard"
            case .bmi: "function"
            case .save: "person.crop.circle"
            }
        }
    }

    private var rows: [TaskRow] { profile.bmi == nil ? [.details, .save] : [.details, .bmi, .save] }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 14) {
                    Spacer(minLength: 10)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 37, weight: .semibold))
                        .foregroundStyle(PulseStyle.actionGradient)
                        .frame(width: 76, height: 76).background(.white, in: RoundedRectangle(cornerRadius: 23))
                        .accessibilityHidden(true)
                    Text(completed == rows.count ? "Your profile is ready" : "Setting up your profile")
                        .font(.title.bold())
                        .multilineTextAlignment(.center).accessibilityAddTraits(.isHeader)
                        .padding(.bottom, 14)
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                Image(systemName: completed > index ? "checkmark.circle.fill" : row.symbol)
                                    .foregroundStyle(PulseStyle.accent).accessibilityHidden(true)
                                Text(row.rawValue).font(.headline)
                                Spacer()
                                if row == .bmi, completed > index, let bmi = profile.bmi {
                                    Text(bmi.formatted(.number.precision(.fractionLength(1))))
                                        .font(.headline.monospacedDigit())
                                }
                            }
                            GeometryReader { bar in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(PulseStyle.background)
                                    Capsule().fill(PulseStyle.actionGradient)
                                        .frame(width: fill > index ? bar.size.width : 0)
                                }
                            }
                            .frame(height: 6)
                        }
                        .padding(18).frame(maxWidth: .infinity)
                        .background(.white, in: RoundedRectangle(cornerRadius: 20))
                        .accessibilityElement(children: .combine)
                    }
                    Spacer(minLength: 14)
                }
                .padding(.horizontal, 22).padding(.vertical, 12)
                .frame(maxWidth: 520, minHeight: proxy.size.height).frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .task(id: isCurrent) {
            completed = 0
            fill = 0
            guard isCurrent else { return }
            do {
                let secondsPerRow = reduceMotion ? 0.15 : 5.4 / Double(rows.count)
                for index in rows.indices {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: secondsPerRow)) { fill = index + 1 }
                    try await Task.sleep(for: .seconds(secondsPerRow))
                    try Task.checkCancellation()
                    completed = index + 1
                }
                profile.save()
                onReady()
            } catch {
                return
            }
        }
    }
}
