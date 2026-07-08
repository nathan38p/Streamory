import CloudKit
import Foundation

enum StreamoryCloudKitAvailability: Equatable {
    case unknown
    case available
    case noAccount
    case restricted
    case temporarilyUnavailable
    case couldNotDetermine

    init(accountStatus: CKAccountStatus) {
        switch accountStatus {
        case .available:
            self = .available
        case .noAccount:
            self = .noAccount
        case .restricted:
            self = .restricted
        case .temporarilyUnavailable:
            self = .temporarilyUnavailable
        case .couldNotDetermine:
            self = .couldNotDetermine
        @unknown default:
            self = .couldNotDetermine
        }
    }
}

struct StreamoryCloudKitService {
    static let containerIdentifier = "iCloud.nathan38p.Streamory"

    private let container: CKContainer

    init(containerIdentifier: String = Self.containerIdentifier) {
        container = CKContainer(identifier: containerIdentifier)
    }

    func accountAvailability() async -> StreamoryCloudKitAvailability {
        do {
            return StreamoryCloudKitAvailability(accountStatus: try await accountStatus())
        } catch {
            return .couldNotDetermine
        }
    }

    func saveProfileSnapshot(_ profile: StreamoryProfile, session: StreamorySession) async throws {
        guard try await accountStatus() == .available else {
            throw StreamoryCloudKitError.iCloudUnavailable
        }

        let recordID = CKRecord.ID(recordName: profile.userID.uuidString)
        let record = CKRecord(recordType: "StreamoryProfile", recordID: recordID)
        record["userID"] = profile.userID.uuidString as NSString
        record["username"] = profile.username as NSString
        record["updatedAt"] = Date() as NSDate

        if let email = session.user.email, !email.isEmpty {
            record["email"] = email as NSString
        }

        if let country = profile.country, !country.isEmpty {
            record["country"] = country as NSString
        }

        if let premiumStatut = profile.premiumStatut {
            record["premiumStatut"] = NSNumber(value: premiumStatut)
        }

        let result = try await container.privateCloudDatabase.modifyRecords(
            saving: [record],
            deleting: [],
            savePolicy: .changedKeys,
            atomically: false
        )

        if case .failure(let error) = result.saveResults[recordID] {
            throw error
        }
    }

    private func accountStatus() async throws -> CKAccountStatus {
        try await withCheckedThrowingContinuation { continuation in
            container.accountStatus { status, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: status)
                }
            }
        }
    }
}

enum StreamoryCloudKitError: LocalizedError {
    case iCloudUnavailable

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            "iCloud n'est pas disponible sur cet appareil."
        }
    }
}
