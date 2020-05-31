import Foundation
import CoreNFC


// https://github.com/travisgoodspeed/goodtag/wiki/RF430TAL152H
// https://github.com/travisgoodspeed/GoodV/blob/master/app/src/main/java/com/kk4vcz/goodv/NfcRF430TAL.java
// https://github.com/travisgoodspeed/goodtag/blob/master/firmware/gcmpatch.c
//
// "The Inner Guts of a Connected Glucose Sensor for Diabetes"
// https://www.youtube.com/watch?v=Y9vtGmxh1IQ
// https://github.com/cryptax/talks/blob/master/BlackAlps-2019/glucose-blackalps2019.pdf
//
// "NFC Exploitation with the RF430RFL152 and 'TAL152" in PoC||GTFO 0x20
// https://archive.org/stream/pocorgtfo20#page/n6/mode/1up


class NFCReader: NSObject, NFCTagReaderSessionDelegate {

    var tagSession: NFCTagReaderSession?

    /// Main app delegate to use its log()
    var main: MainDelegate!

    var isNFCAvailable: Bool {
        return NFCTagReaderSession.readingAvailable
    }
    
    func startSession() {
        // execute in the .main queue because of main.log
        tagSession = NFCTagReaderSession(pollingOption: [.iso15693], delegate: self, queue: .main)
        tagSession?.alertMessage = "Hold the top of your iPhone near the Libre sensor"
        tagSession?.begin()
    }

    public func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        main.log("NFC: session did become active")
    }

    public func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        if let readerError = error as? NFCReaderError {
            if readerError.code != .readerSessionInvalidationErrorUserCanceled {
                main.log("NFC: \(readerError.localizedDescription)")
                session.invalidate(errorMessage: "Connection failure: \(readerError.localizedDescription)")
            }
        }
    }

    public func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        main.log("NFC: did detect tags")

        guard let firstTag = tags.first else { return }
        guard case .iso15693(let tag) = firstTag else { return }

        session.alertMessage = "Scan complete"

        let blocks = 43
        let requestBlocks = 3

        let requests = Int(ceil(Double(blocks) / Double(requestBlocks)))
        let remainder = blocks % requestBlocks
        var dataArray = [Data](repeating: Data(), count: blocks)

        session.connect(to: firstTag) { error in
            if error != nil {
                self.main.log("NFC: \(error!.localizedDescription)")
                session.invalidate(errorMessage: "Connection failure: \(error!.localizedDescription)")
                return
            }

            // https://www.st.com/en/embedded-software/stsw-st25ios001.html#get-software

            tag.getSystemInfo(requestFlags: [.address, .highDataRate]) { (dfsid: Int, afi: Int, blockSize: Int, memorySize: Int, icRef: Int, error: Error?) in
                if error != nil {
                    session.invalidate(errorMessage: "Error while getting system info: " + error!.localizedDescription)
                    self.main.log("NFC: error while getting system info: \(error!.localizedDescription)")
                    return
                }

                // https://github.com/NightscoutFoundation/xDrip/blob/master/app/src/main/java/com/eveningoutpost/dexdrip/NFCReaderX.java

                // TODO
                if self.main.settings.debugLevel > 0 {
                    self.readRaw(tag: tag, 0xF860, 24) // FRAM raw start address, max 3 blocks
                }

                tag.customCommand(requestFlags: [.highDataRate], customCommandCode: 0xA1, customRequestParameters: Data()) { (customResponse: Data, error: Error?) in
                    if error != nil {
                        // session.invalidate(errorMessage: "Error while getting patch info: " + error!.localizedDescription)
                        self.main.log("NFC: error while getting patch info: \(error!.localizedDescription)")
                    }

                    for i in 0 ..< requests {

                        tag.readMultipleBlocks(requestFlags: [.highDataRate, .address], blockRange: NSRange(UInt8(i * requestBlocks)...UInt8(i * requestBlocks + (i == requests - 1 ? remainder - 1: requestBlocks - 1)))) { (blockArray, error) in

                            if error != nil {
                                self.main.log("NFC: error while reading multiple blocks (#\(i * requestBlocks) - #\(i * requestBlocks + (i == requests - 1 ? remainder - 1: requestBlocks - 1))) : \(error!.localizedDescription)")
                                session.invalidate(errorMessage: "Error while reading multiple blocks: \(error!.localizedDescription)")
                                if i != requests - 1 { return }

                            } else {
                                for j in 0 ..< blockArray.count {
                                    dataArray[i * requestBlocks + j] = blockArray[j]
                                }
                            }


                            if i == requests - 1 {

                                session.invalidate()

                                var sensor: Sensor
                                if  self.main.app.sensor != nil {
                                    sensor = self.main.app.sensor
                                } else {
                                    sensor = Sensor()
                                    self.main.app.sensor = sensor
                                }

                                var fram = Data()

                                self.main.app.lastReadingDate = Date()
                                sensor.lastReadingDate = self.main.app.lastReadingDate

                                var msg = ""
                                for (n, data) in dataArray.enumerated() {
                                    if data.count > 0 {
                                        fram.append(data)
                                        msg += "NFC block #\(String(format:"%02d", n)): \(data.reduce("", { $0 + String(format: "%02X", $1) + " "}).dropLast())\n"
                                    }
                                }
                                if !msg.isEmpty { self.main.log(String(msg.dropLast())) }

                                let uid = tag.identifier.hex
                                self.main.log("NFC: IC identifier: \(uid)")

                                var manufacturer = String(tag.icManufacturerCode)
                                if manufacturer == "7" {
                                    manufacturer.append(" (Texas Instruments)")
                                }
                                self.main.log("NFC: IC manufacturer code: \(manufacturer)")
                                self.main.log("NFC: IC serial number: \(tag.icSerialNumber.hex)")

                                self.main.log(String(format: "NFC: IC reference: 0x%X", icRef))

                                self.main.log(String(format: "NFC: block size: %d", blockSize))
                                self.main.log(String(format: "NFC: memory size: %d blocks", memorySize))

                                sensor.uid = Data(tag.identifier.reversed())
                                self.main.log("NFC: sensor uid: \(sensor.uid.hex)")
                                self.main.log("NFC: sensor serial number: \(sensor.serial)")

                                let patchInfo = customResponse
                                sensor.patchInfo = Data(patchInfo)
                                if customResponse.count > 0 {
                                    self.main.log("NFC: patch info: \(patchInfo.hex)")
                                    self.main.log("NFC: sensor type: \(sensor.type.rawValue)")

                                    self.main.settings.patchUid = sensor.uid
                                    self.main.settings.patchInfo = sensor.patchInfo
                                }

                                if fram.count > 0 {
                                    sensor.fram = Data(fram)
                                }

                                self.main.status("\(sensor.type)  +  NFC")
                                self.main.parseSensorData(sensor)
                            }
                        }
                    }
                }
            }
        }
    }


    func readRaw(tag: NFCISO15693Tag, _ address: UInt16, _ bytes: UInt8) {
        tag.customCommand(requestFlags: [.highDataRate], customCommandCode: 0xA3, customRequestParameters: Data("ADC2".bytes.reversed() + "2175".bytes.reversed() + [UInt8(address & 0x00FF), UInt8(address >> 8), bytes / 2])) { (customResponse: Data, error: Error?) in

            let data = customResponse

            if error != nil {
                // session.invalidate(errorMessage: "Error while reading raw memory: " + error!.localizedDescription)
                self.main.log("NFC: error while reading raw memory at 0x\(String(format: "%04X", address)): \(error!.localizedDescription)")
            } else {
                var offset = data.startIndex
                var offsetEnd = offset
                var msg = "NFC memory dump:\n"
                while offset < data.endIndex {
                    _ = data.formIndex(&offsetEnd, offsetBy: 8, limitedBy: data.endIndex)
                    msg += String(format: "%04X", address + UInt16(offset)) + "  \(data[offset ..< offsetEnd].reduce("", { $0 + String(format: "%02X", $1) + " "}).dropLast())\n"
                    _ = data.formIndex(&offset, offsetBy: 8, limitedBy: data.endIndex)
                }
                self.main.log(msg)
            }
        }
    }

}
