import Foundation

enum AppConstants {
    enum Links {
        static let privacyPolicy = URL(string: "https://docs.google.com/document/d/e/2PACX-1vRSepA8T4YYRrURwN0591KaDOTW844IkCw4sodoBThlsRMNT3TeQIUzBo3chLtfc185bk071JH0w_Aj/pub")!
        static let termsOfUse = URL(string: "https://docs.google.com/document/d/e/2PACX-1vRSepA8T4YYRrURwN0591KaDOTW844IkCw4sodoBThlsRMNT3TeQIUzBo3chLtfc185bk071JH0w_Aj/pub")!

        static let appStoreAppID = "6761369026"

        static var appStore: URL {
            URL(string: "https://apps.apple.com/app/id6761369026")!
        }

        static var appStoreReview: URL {
            URL(string: "https://apps.apple.com/app/id6761369026?action=write-review")!
        }

        static let shareMessage = "Track your medications with Pill Reminder. Clean reminders, easy dose history, and daily control."
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
