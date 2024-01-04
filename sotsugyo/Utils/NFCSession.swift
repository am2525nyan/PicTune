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
    
    
    func startWriteSession(UserUid: String, folder: String, writeHandler: ((Error?) -> Void)?) {
        self.writeHandler = writeHandler
        isWriting = true

        // UserUid と folder をスペースで区切って1つの文字列に結合
        let combinedString = "\(UserUid) \(folder)"

        let textPayload = NFCNDEFPayload(
            format: NFCTypeNameFormat.nfcWellKnown,
            type: "T".data(using: .utf8)!,
            identifier: Data(),
            payload: combinedString.data(using: .utf8)!  // スペースで区切った文字列をデータとして設定
        )

        ndefMessage = NFCNDEFMessage(records: [textPayload])
        startSession()
    }
    
    func startReadSession(readHandler: ((String?, String?, Error?) -> Void)?) {
        self.readHandler = readHandler
        isWriting = false
        startSession()
    }


    private func startSession() {
        guard NFCNDEFReaderSession.readingAvailable else {
            return
        }
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session.alertMessage = "スキャン中"
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
    }

    // 必須ではないけどコンソールになんかでる
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        let tag = tags.first!
        session.connect(to: tag) { error in
            tag.queryNDEFStatus() { [unowned self] status, capacity, error in
                if self.isWriting {
                    // 書き込み
                    if status == .readWrite {
                        self.write(tag: tag, session: session)
                        return
                    }
                } else {
                    // 読み込み
                    if status == .readOnly || status == .readWrite {
                        self.read(tag: tag, session: session)
                        return
                    }
                }
                session.invalidate(errorMessage: "タグがおかしいよ")
            }
        }
    }

    private func write(tag: NFCNDEFTag, session: NFCNDEFReaderSession) {
        tag.writeNDEF(self.ndefMessage) { [unowned self] error in
            session.alertMessage = "保存できました！"
            session.invalidate()
            DispatchQueue.main.async {
                self.writeHandler?(error)
            }
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

