//
//  NFCSession.swift
//  sotsugyo
//
//  Created by saki on 2023/12/20.
//

import Foundation
import CoreNFC
import SwiftUI

final class NFCSession: NSObject, ObservableObject {
    
    private var session: NFCNDEFReaderSession?
    private var isWriting = false
    private var ndefMessage: NFCNDEFMessage?
    private var writeHandler: ((Error?) -> Void)?
    var readHandler: ((String?, String?, Error?) -> Void)?
    
    
    func startWriteSession(UserUid: String, folder: String, writeHandler: ((Error?) -> Void)?) {
        self.writeHandler = writeHandler
        isWriting = true
        
        ndefMessage = Self.folderMessage(for: SharedFolderReference(userID: UserUid, folderID: folder))
        startSession()
    }

    static func folderMessage(for reference: SharedFolderReference) -> NFCNDEFMessage {
        // Older PicTune versions decode the entire payload as UTF-8, including any
        // standard Text header. Keep their single raw record on write until those
        // readers are retired; multiple records also break their joined payload.
        let record = NFCNDEFPayload(format: .nfcWellKnown, type: Data("T".utf8),
                                   identifier: Data(), payload: Data(reference.payload.utf8))
        return NFCNDEFMessage(records: [record])
    }
    
    func startReadSession(readHandler: ((String?, String?, Error?) -> Void)?) {
        self.readHandler = readHandler
        isWriting = false
        startSession()
    }
    
    
    private func startSession() {
        guard NFCNDEFReaderSession.readingAvailable else {
            let error = NSError(domain: "PicTune.NFC", code: 1, userInfo: [NSLocalizedDescriptionKey: "このデバイスではNFCを利用できません。"])
            if isWriting { finishWriting(error: error) }
            else { finishReading(text: nil, error: error) }
            return
        }
        let session = NFCNDEFReaderSession(delegate: self, queue: .main, invalidateAfterFirstRead: false)
        self.session = session
        session.alertMessage = isWriting ? "iPhoneの上部をNFCカードに近づけてください。" : "スキャン中"
        session.begin()
        
    }
    func stopReadSession() {
        session?.invalidate()
        session = nil
        readHandler = nil
    }
}

extension NFCSession: NFCNDEFReaderSessionDelegate {
    
    // 必須
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
    }
    
    // 必須
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        guard self.session === session else { return }
        if isWriting { finishWriting(error: error) }
        else { finishReading(text: nil, error: error) }
        self.session = nil
    }
    
    // 必須ではないけどコンソールになんかでる
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard self.session === session else { return }
        guard tags.count == 1, let tag = tags.first else {
            session.alertMessage = "NFCカードを1枚だけ近づけてください。"
            session.restartPolling()
            return
        }
        session.connect(to: tag) { error in
            guard self.session === session else { return }
            if let error = error {
                self.fail(session: session, error: error)
                return
            }
            tag.queryNDEFStatus { status, capacity, error in
                guard self.session === session else { return }
                if let error = error {
                    self.fail(session: session, error: error)
                    return
                }
                if self.isWriting, status == .readWrite {
                    guard let message = self.ndefMessage, message.length <= capacity else {
                        self.fail(session: session, message: "NFCカードの容量が足りません。")
                        return
                    }
                    self.write(tag: tag, session: session)
                } else if !self.isWriting, status == .readOnly || status == .readWrite {
                    self.read(tag: tag, session: session)
                } else {
                    self.fail(session: session, message: "このNFCカードには保存できません。書き込み可能なカードを使用してください。")
                }
            }
        }
    }

    private func finishWriting(error: Error?) {
        let handler = writeHandler
        writeHandler = nil
        DispatchQueue.main.async { handler?(error) }
    }

    private func fail(session: NFCNDEFReaderSession, message: String) {
        fail(session: session, error: NSError(domain: "PicTune.NFC", code: 2,
             userInfo: [NSLocalizedDescriptionKey: message]))
    }

    private func fail(session: NFCNDEFReaderSession, error: Error) {
        if isWriting { finishWriting(error: error) }
        else { finishReading(text: nil, error: error) }
        session.invalidate(errorMessage: error.localizedDescription)
    }

    private func write(tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        guard let message = ndefMessage else { return }
        tag.writeNDEF(message) { error in
            guard self.session === session else { return }
            if let error = error {
                self.fail(session: session, error: error)
                return
            }
            self.finishWriting(error: nil)
            session.alertMessage = "フォルダを保存しました。"
            session.invalidate()
        }
    }

    private func finishReading(text: String?, error: Error?) {
        let handler = readHandler
        readHandler = nil
        DispatchQueue.main.async { handler?(text, text, error) }
    }

    /// Accept standard NDEF Text records and the raw UTF-8 records written by older versions.
    static func folderPayload(from record: NFCNDEFPayload) -> String? {
        guard record.typeNameFormat == .nfcWellKnown, record.type == Data("T".utf8) else { return nil }
        if let text = String(data: record.payload, encoding: .utf8),
           text.rangeOfCharacter(from: .controlCharacters) == nil,
           SharedFolderReference(payload: text) != nil {
            return text
        }
        if let text = record.wellKnownTypeTextPayload().0,
           text.rangeOfCharacter(from: .controlCharacters) == nil,
           SharedFolderReference(payload: text) != nil {
            return text
        }
        return nil
    }

    private func read(tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        tag.readNDEF { [weak self] message, error in
            guard let self, self.session === session else { return }
            if let error {
                self.fail(session: session, error: error)
                return
            }
            guard let text = message?.records.compactMap(Self.folderPayload(from:)).first else {
                self.fail(session: session, message: "フォルダの情報を読み取れませんでした。")
                return
            }
            self.finishReading(text: text, error: nil)
            session.alertMessage = "読み取りできました！"
            session.invalidate()
        }
    }
}
