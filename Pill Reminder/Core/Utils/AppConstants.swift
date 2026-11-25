import Foundation

enum AppConstants {
    enum Onboarding {
        static let completedKey = "hasCompletedPulseOnboarding"
        static let finishedIntroductionKey = "hasFinishedPulseIntroduction"
    }

    enum Links {
        static let privacyPolicy = URL(string: "https://docs.google.com/document/d/e/2PACX-1vRSepA8T4YYRrURwN0591KaDOTW844IkCw4sodoBThlsRMNT3TeQIUzBo3chLtfc185bk071JH0w_Aj/pub")!
        static let termsOfUse = URL(string: "https://docs.google.com/document/d/e/2PACX-1vRSepA8T4YYRrURwN0591KaDOTW844IkCw4sodoBThlsRMNT3TeQIUzBo3chLtfc185bk071JH0w_Aj/pub")!

        static let appStoreAppID = "6761369026"

        static var appStore: URL {
            URL(string: "https://apps.apple.com/app/id\(appStoreAppID)")!
        }

        static var appStoreReview: URL {
            URL(string: "https://apps.apple.com/app/id\(appStoreAppID)?action=write-review")!
        }

        static let shareMessage = "Measure your pulse and explore your readings over time with Heart Rate."
    }

    enum Store {
        static let weeklyProductID = "pillreminderweekly"
        static let monthlyProductID = "pillremindermonthly"
        static let yearlyProductID = "pillreminderyearly"

        static let productIDs = [
            weeklyProductID,
            monthlyProductID,
            yearlyProductID
        ]
    }
}
