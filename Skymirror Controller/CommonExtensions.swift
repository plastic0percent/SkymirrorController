//
//  CommonExtensions.swift
//  Skymirror Controller
//
//  Created by 张迈允 on 2021/3/11.
//

import Foundation
import CoreBluetooth

// Extension to create Data from Hex
extension String {
    enum ExtendedEncoding {
        case hex
        case HEX
    }

    // https://stackoverflow.com/a/56870030
    func data(using encoding: ExtendedEncoding) -> Data? {
        let hexStr = self.dropFirst(self.hasPrefix("0x") ? 2 : 0)

        guard hexStr.count % 2 == 0 else { return nil }

        var newData = Data(capacity: hexStr.count/2)

        var indexIsEven = true
        for idx in hexStr.indices {
            if indexIsEven {
                let byteRange = idx...hexStr.index(after: idx)
                guard let byte = UInt8(hexStr[byteRange], radix: 16) else { return nil }
                newData.append(byte)
            }
            indexIsEven.toggle()
        }
        return newData
    }

    init?(data: Data, encoding: Encoding, filter: (UInt8) -> UInt8 = {dat in return dat}) {
        self.init(
            data: Data(data.map {
                filter($0)
            }),
            encoding: encoding
        )
    }

    init(data: Data, encoding: ExtendedEncoding) {
        self.init(
            data.map {
                String(format: encoding == .hex ? "%02hhx" : "%02hhX", $0)
            }.joined()
        )
    }
}

/// `xxd` style filter
func xxdFilter(chr: UInt8, encoding: String.Encoding) -> UInt8 {
    if chr <= 0x1f // ASCII control
        // || chr == 0x20 // space
        || chr == 0x7f // DEL
        || String.init(data: Data([chr]), encoding: encoding) == nil {
        return 0x2E // '.'
    }
    return chr
}

/// Extensions to read the properties better
extension CBCharacteristicProperties {
    /// Enumerate over all properties
    func forEachProp<ReturnValue>(
        action: (_ prop: CharacProp) -> ReturnValue) -> [ReturnValue] {
        var result: [ReturnValue] = []
        // Index of the current bit
        var bitIndex = 0
        // The properties
        var prop = self.rawValue
        // Map between property and bit position
        let types: [CharacProp] = [
            .broadcast, .read, .writeNoResponse, .write,
            .notify, .indicate, .signedWrite, .extended
        ]
        while prop != 0 {
            if prop & 0x01 != 0 {
                result.append(action(types[bitIndex]))
            }
            bitIndex += 1
            prop >>= 1
        }
        return result
    }

    /// Interpret CBCharacteristicProperties into descriptive string
    func interpretProperties() -> String {
        var result = String.init()
        _ = self.forEachProp(action: {prop in
            switch prop {
            case .broadcast:
                result.append("BC ")
            case .read:
                result.append("RD ")
            case .writeNoResponse:
                result.append("WW ")
            case .write:
                result.append("WR ")
            case .notify:
                result.append("NO ")
            case .indicate:
                result.append("IN ")
            case .signedWrite:
                result.append("SW ")
            case .extended:
                result.append("EX ")
            }
        })
        return result
    }
}
