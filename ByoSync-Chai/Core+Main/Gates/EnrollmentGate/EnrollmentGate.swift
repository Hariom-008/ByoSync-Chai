import Foundation
import Combine

enum EnrollmentState: Int {
    case unknown = 0
    case notEnrolled = 1
    case enrolled = 2
}

final class EnrollmentGate: ObservableObject {
    static let shared = EnrollmentGate()

    @Published private(set) var state: EnrollmentState

    private let key = "enrollmentState"

    private init() {
        let raw = UserDefaults.standard.integer(forKey: key)
        self.state = EnrollmentState(rawValue: raw) ?? .unknown
    }

    func reload() {
        let raw = UserDefaults.standard.integer(forKey: key)
        state = EnrollmentState(rawValue: raw) ?? .unknown
    }

    func markNotEnrolled() {
        state = .notEnrolled
        UserDefaults.standard.set(EnrollmentState.notEnrolled.rawValue, forKey: key)
    }

    func markEnrolled() {
        state = .enrolled
        UserDefaults.standard.set(EnrollmentState.enrolled.rawValue, forKey: key)
    }

    func resetToUnknown() {
        state = .unknown
        UserDefaults.standard.set(EnrollmentState.unknown.rawValue, forKey: key)
    }

    var isEnrolled: Bool { state == .enrolled }
    var needsEnrollment: Bool { state == .notEnrolled }
}
