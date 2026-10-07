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
    
    private var session: NFCNDEFReaderSession!
    private var isWriting = false
    private var ndefMessage: NFCNDEFMessage!
    private var writeHandler: ((Error?) -> Void)?
    var readHandler: ((String?, String?, Error?) -> Void)?
    
    
    func startWriteSession(inviteURL: URL, writeHandler: ((Error?) -> Void)?) {
        self.writeHandler = writeHandler
        isWriting = true
        guard let payload = NFCNDEFPayload.wellKnownTypeURIPayload(url: inviteURL) else {
            finishWriting(error: FolderInviteError.invalidLink)
            return
        }
        ndefMessage = NFCNDEFMessage(records: [payload])
        startSession()
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
            return
        }
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session.alertMessage = isWriting ? "iPhoneの上部をNFCカードに近づけてください。" : "スキャン中"
        session.begin()
        
    }
    func stopReadSession() {
        session.invalidate()
        session = nil
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
    }
    
    // 必須ではないけどコンソールになんかでる
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard tags.count == 1, let tag = tags.first else {
            session.alertMessage = "NFCカードを1枚だけ近づけてください。"
            session.restartPolling()
            return
        }
        session.connect(to: tag) { error in
            if let error = error {
                self.fail(session: session, error: error)
                return
            }
            tag.queryNDEFStatus { status, capacity, error in
                if let error = error {
                    self.fail(session: session, error: error)
                    return
                }
                if self.isWriting, status == .readWrite {
                    guard self.ndefMessage.length <= capacity else {
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
        DispatchQueue.main.async {
            let handler = self.writeHandler
            self.writeHandler = nil
            handler?(error)
        }
    }

    private func fail(session: NFCNDEFReaderSession, message: String) {
        fail(session: session, error: NSError(domain: "PicTune.NFC", code: 2,
             userInfo: [NSLocalizedDescriptionKey: message]))
    }

    private func fail(session: NFCNDEFReaderSession, error: Error) {
        if isWriting { finishWriting(error: error) }
        session.invalidate(errorMessage: error.localizedDescription)
    }

    private func write(tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        tag.writeNDEF(self.ndefMessage) { error in
            if let error = error {
                self.fail(session: session, error: error)
                return
            }
            self.finishWriting(error: nil)
            session.alertMessage = "フォルダを保存しました。"
            session.invalidate()
        }
    }

    private func read(tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        tag.readNDEF { [unowned self] message, error in
            session.alertMessage = "読み取りできました！"
            session.invalidate()
            let text = message?.records.compactMap {
                switch $0.typeNameFormat {
                case .nfcWellKnown:
                    if let url = $0.wellKnownTypeURIPayload() {
                        return url.absoluteString
                    }
                    if let text = String(data: $0.payload, encoding: .utf8) {
                        return text
                    }
                    return nil
                default:
                    return nil
                }
            }.joined(separator: "\n\n")
            DispatchQueue.main.async {
                self.readHandler?(text,text,error)
            }
        }
    }
}

