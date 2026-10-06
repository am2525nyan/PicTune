import XCTest
import UIKit
import CoreNFC
@testable import PIcTune

@MainActor
final class CaptureRegressionTests: XCTestCase {
    func testLateProfileCannotRestoreFriendAfterScannerFailure() async {
        let started = expectation(description: "Profile started")
        var continuation: CheckedContinuation<UserProfile?, Error>?
        let model = FriendQRViewModel { _ in
            try await withCheckedThrowingContinuation { continuation = $0; started.fulfill() }
        }
        let loading = Task { await model.loadFriendProfile(uid: "friend") }
        await fulfillment(of: [started], timeout: 2)
        model.reportScanFailure(URLError(.notConnectedToInternet))
        continuation?.resume(returning: UserProfile(name: "友人"))
        let friend = await loading.value
        XCTAssertNil(friend)
        XCTAssertNil(model.confirmedUserID)
        XCTAssertTrue(model.showAlert)
        XCTAssertTrue(model.alertMessage.hasPrefix("QRコードを読み取れませんでした。"))
    }

    func testInvalidSharingRecipientIsRejectedBeforeUpload() async {
        let camera = CameraManager()
        let image = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { _ in }
        for uid in ["users/friend", "friend uid", "friend\n", "friend\0", String(repeating: "a", count: 129)] {
            do {
                try await camera.uploadPhoto(image, friendUid: uid)
                XCTFail("Invalid recipient must be rejected")
            } catch {
                XCTAssertEqual((error as NSError).domain, "PhotoSave")
                XCTAssertEqual((error as NSError).code, 3)
            }
        }
    }

    func testSoloAndValidFriendSharingIDsRemainSupported() {
        XCTAssertNoThrow(try CameraManager.validateFriendUID(""))
        XCTAssertNoThrow(try CameraManager.validateFriendUID("friend-id"))
    }

    func testInvalidQRPayloadNeverReachesFirestoreLoader() async {
        var requests = 0
        let model = FriendQRViewModel { _ in
            requests += 1
            return UserProfile(name: "友人")
        }
        for payload in ["", "https://example.com", "users/friend", "friend id", "friend\n", "friend\0", String(repeating: "a", count: 129)] {
            let friend = await model.loadFriendProfile(uid: payload)
            XCTAssertNil(friend, payload)
            XCTAssertNil(model.confirmedUserID)
        }
        XCTAssertEqual(requests, 0)
    }

    func testFailedScanClearsPreviousConfirmedFriend() async {
        let model = FriendQRViewModel { uid in
            uid == "friend" ? UserProfile(name: "友人") : nil
        }
        let first = await model.loadFriendProfile(uid: "friend")
        XCTAssertEqual(first, "friend")
        XCTAssertEqual(model.confirmedUserID, "friend")
        let second = await model.loadFriendProfile(uid: "missing")
        XCTAssertNil(second)
        XCTAssertNil(model.confirmedUserID)
    }

    func testStandardNFCTextRecordRoundTripsFolderReference() throws {
        let payload = "friend folder"
        let record = try XCTUnwrap(NFCNDEFPayload.wellKnownTypeTextPayload(string: payload, locale: Locale(identifier: "en")))
        XCTAssertEqual(NFCSession.folderPayload(from: record), payload)
    }

    func testLegacyNFCTextRecordKeepsEntireUserID() {
        // 'A' can be mistaken for a one-byte language-code header by the standard decoder.
        for payload in ["Alice folder", "friend folder", "0123456789 all"] {
            let record = NFCNDEFPayload(format: .nfcWellKnown, type: Data("T".utf8), identifier: Data(), payload: Data(payload.utf8))
            XCTAssertEqual(NFCSession.folderPayload(from: record), payload)
        }
    }

    func testUnrelatedAndMalformedNFCRecordsAreRejected() throws {
        let uri = try XCTUnwrap(NFCNDEFPayload.wellKnownTypeURIPayload(string: "https://example.com"))
        XCTAssertNil(NFCSession.folderPayload(from: uri))
        for payload in ["", "friend", "friend folder/child", "friend folder extra"] {
            let record = try XCTUnwrap(NFCNDEFPayload.wellKnownTypeTextPayload(string: payload, locale: Locale(identifier: "en")))
            XCTAssertNil(NFCSession.folderPayload(from: record))
        }
    }

    func testUnavailableNFCReadReportsAnError() async throws {
        guard !NFCNDEFReaderSession.readingAvailable else {
            throw XCTSkip("This regression covers devices without NFC reading support.")
        }
        let completed = expectation(description: "Read failure is reported")
        let session = NFCSession()
        session.startReadSession { _, payload, error in
            XCTAssertNil(payload)
            XCTAssertNotNil(error)
            completed.fulfill()
        }
        await fulfillment(of: [completed], timeout: 1)
    }

    func testStoppingAnInactiveNFCSessionDoesNotCrash() {
        let session = NFCSession()
        session.stopReadSession()
        session.stopReadSession()
    }

    func testPhotoCropUsesPixelDimensionsAndPreservesOrientation() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let source = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 80), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 120, height: 80))
        }
        let crop = try XCTUnwrap(CameraManager.croppedPhoto(source, normalizedRect: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)))
        XCTAssertEqual(crop.size, CGSize(width: 60, height: 40))
        XCTAssertEqual(crop.cgImage?.width, 120)
        XCTAssertEqual(crop.cgImage?.height, 80)
        let rotated = UIImage(cgImage: try XCTUnwrap(source.cgImage), scale: 2, orientation: .right)
        let rotatedCrop = try XCTUnwrap(CameraManager.croppedPhoto(rotated, normalizedRect: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)))
        XCTAssertEqual(rotatedCrop.imageOrientation, .up)
        XCTAssertEqual(rotatedCrop.size, CGSize(width: 40, height: 60))
    }

    func testPhotoCropRejectsRectOutsideImage() {
        let source = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { _ in }
        XCTAssertNil(CameraManager.croppedPhoto(source, normalizedRect: .zero))
        XCTAssertNil(CameraManager.croppedPhoto(source, normalizedRect: CGRect(x: 2, y: 2, width: 1, height: 1)))
    }
}
