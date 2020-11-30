import Foundation
import CryptoKit


extension Data {
    var hex: String { self.reduce("", { $0 + String(format: "%02x", $1)}) }
    var string: String { String(decoding: self, as: UTF8.self) }
    var hexAddress: String { String(self.reduce("", { $0 + String(format: "%02X", $1) + ":"}).dropLast(1)) }
    var sha1: String { Insecure.SHA1.hash(data: self).makeIterator().reduce("", { $0 + String(format: "%02x", $1)}) }

    func hexDump(address: Int = -1, header: String = "") -> String {
        var offset = startIndex
        var offsetEnd = offset
        var str = header.isEmpty ? "" : "\(header)\n"
        while offset < endIndex {
            _ = formIndex(&offsetEnd, offsetBy: 8, limitedBy: endIndex)
            if address != -1 { str += String(format: "%04X", address + offset) + "  " }
            str += "\(self[offset ..< offsetEnd].reduce("", { $0 + String(format: "%02X", $1) + " "}))"
            str += String(repeating: "   ", count: 8 - distance(from: offset, to: offsetEnd))
            str += "\(self[offset ..< offsetEnd].reduce(" ", { $0 + ((isprint(Int32($1)) != 0) ? String(Unicode.Scalar($1)) : "." ) }))\n"
            _ = formIndex(&offset, offsetBy: 8, limitedBy: endIndex)
        }
        str.removeLast()
        return str
    }

    var crc16: UInt16 {
        var crc: UInt32 = 0xffff
        for byte in self {
            for i in 0...7 {
                crc <<= 1
                if ((crc >> 16) & 1) ^ (UInt32(byte >> i) & 1) == 1 {
                    crc ^= 0x1021
                }
            }
        }
        return UInt16(crc & 0xffff)
    }

}


extension UInt16 {
    init(_ high: UInt8, _ low: UInt8) {
        self = UInt16(high) << 8 + UInt16(low)
    }

    /// init from bytes[low...high]
    init(_ bytes: [UInt8]) {
        self = UInt16(bytes[bytes.startIndex + 1]) << 8 + UInt16(bytes[bytes.startIndex])
    }

    /// init from data[low...high]
    init(_ data: Data) {
        self = UInt16(data[data.startIndex + 1]) << 8 + UInt16(data[data.startIndex])
    }
}


extension String {
    var base64: String? { self.data(using: .utf8)?.base64EncodedString() }
    var base64Data: Data? { Data(base64Encoded: self) }
    var sha1: String { self.data(using: .ascii)!.sha1 }

    var bytes: [UInt8] {
        var bytes = [UInt8]()
        if !self.contains(" ") {
            var offset = self.startIndex
            while offset < self.endIndex {
                let hex = self[offset...index(after: offset)]
                bytes.append(UInt8(hex, radix: 16)!)
                formIndex(&offset, offsetBy: 2)
            }
        } else {
            /// Convert the NFCReader hex dump
            for line in self.split(separator: "\n") {
                let column = line.contains("  ") ? line.components(separatedBy: "  ")[1] : String(line)
                for hex in column.split(separator: " ").suffix(8) {
                    bytes.append(UInt8(hex, radix: 16)!)
                }
            }
        }
        return bytes
    }

    func matches(_ pattern: String) -> Bool {
        self.split(separator: " ").contains { substring in
            pattern.split(separator: " ").contains { substring.lowercased().contains($0.lowercased()) }
        }
    }
}


extension Int {
    var formattedInterval: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: TimeInterval(self * 60))!
    }
    var shortFormattedInterval: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day]
        formatter.unitsStyle = .short
        let days = formatter.string(from: TimeInterval(self * 60))!
        formatter.allowedUnits = [.hour]
        formatter.unitsStyle = .abbreviated
        let hours = formatter.string(from: TimeInterval((self * 60) % 86400))!
        return "\(days) \(hours)"
    }
}


extension Date {
    var shortTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "H:mm"
        return formatter.string(from: self)
    }
    var shortDateTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM-dd HH:mm"
        return formatter.string(from: self)
    }
    var dateTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM-dd HH:mm:ss"
        return formatter.string(from: self)
    }
    var local: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withFullTime, .withDashSeparatorInDate, .withColonSeparatorInTime, .withSpaceBetweenDateAndTime, .withColonSeparatorInTimeZone]
        formatter.timeZone = TimeZone.current
        return formatter.string(from: self)
    }
}
