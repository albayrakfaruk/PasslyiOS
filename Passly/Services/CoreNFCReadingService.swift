import CoreNFC
import Foundation

final class CoreNFCReadingService: NSObject, NFCReadingService, @preconcurrency NFCNDEFReaderSessionDelegate {
    private var continuation: CheckedContinuation<NFCPayload, Error>?
    private var session: NFCNDEFReaderSession?

    func readNDEF() async throws -> NFCPayload {
        guard NFCNDEFReaderSession.readingAvailable else {
            throw PasslyError.nfcUnavailable
        }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
            session.alertMessage = "Scan readable NFC tags. If the tag contains public text or a URL, Passly can turn it into a Wallet pass."
            self.session = session
            session.begin()
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
        self.session = nil
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        guard let record = messages.flatMap(\.records).first else {
            continuation?.resume(throwing: PasslyError.unsupportedSecureNFC)
            continuation = nil
            return
        }

        let payload = decode(record: record)
        continuation?.resume(returning: payload)
        continuation = nil
        self.session = nil
    }

    private func decode(record: NFCNDEFPayload) -> NFCPayload {
        if let known = record.wellKnownTypeTextPayload().0 {
            return NFCPayload(rawText: known, urlString: URL(string: known)?.absoluteString, recordType: "text", scannedAt: .now)
        }
        if let url = record.wellKnownTypeURIPayload() {
            return NFCPayload(rawText: url.absoluteString, urlString: url.absoluteString, recordType: "url", scannedAt: .now)
        }
        let raw = String(data: record.payload, encoding: .utf8)
        return NFCPayload(rawText: raw, urlString: raw.flatMap { URL(string: $0)?.absoluteString }, recordType: String(data: record.type, encoding: .utf8), scannedAt: .now)
    }
}
