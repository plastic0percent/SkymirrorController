//
//  BLEDebuggerOperations.swift
//  Skymirror Controller
//
//  Created by 张迈允 on 2021/3/7.
//

import SwiftUI
import CoreBluetooth

// Characteristic property types
enum CharacProp {
    case broadcast
    case read
    case writeNoResponse
    case write
    case notify
    case indicate
    case signedWrite
    case extended
}

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

    init(data: Data, encoding: ExtendedEncoding) {
        self.init(data.map { String(format: encoding == .hex ? "%02hhx" : "%02hhX", $0) }.joined())
    }
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

struct BroadcastOperationView: View {
    @Binding var connection: ConnectionController
    @Binding var characteristic: CBCharacteristic
    @Binding var bleAlert: String?

    var body: some View {
        Text("Broad cast")
    }
}

struct ReadOperationView: View {
    @Binding var connection: ConnectionController
    @Binding var characteristic: CBCharacteristic
    @Binding var bleAlert: String?
    @State private var result = Data.init()

    /// Create an alert with a Dismiss button
    func createAlert(message: String) {
        self.bleAlert = message
    }

    /// Used as closures to create alerts when functions fail
    func okOrAlert(result: Result<Void, Error>) {
        if case let .failure(error) = result {
            createAlert(message: error.localizedDescription)
        }
    }

    var body: some View {
        VStack {
            // Title
            HStack {
                Text("Read from characteristic").font(.subheadline)
            }
            // Input area
            HStack {
                Spacer()
                Button(action: {
                    connection.read(
                        ofCharacWithUUID: characteristic.CBUUIDRepresentation.uuidString,
                        fromServiceWithUUID: characteristic.service.CBUUIDRepresentation.uuidString,
                        completion: {res in
                            switch res {
                            case .success(let data):
                                result = data
                            case .failure(let error):
                                createAlert(message: error.localizedDescription)
                            }
                        })
                }, label: {
                    Text("Read")
                })
                Divider()
                VStack {
                    let resultStr = String.init(data: result, encoding: .utf8)
                    if resultStr != nil {
                        Text("UTF-8: \"\(resultStr!)\"")
                    }
                    Text("HEX: \(String.init(data: result, encoding: .hex))")
                }
                Spacer()
            }
        }
    }
}

struct WriteOperationView: View {
    @State private var isHex = false
    @State private var inputValue = ""
    @Binding var connection: ConnectionController
    @Binding var characteristic: CBCharacteristic
    @Binding var bleAlert: String?

    /// Create an alert with a Dismiss button
    func createAlert(message: String) {
        self.bleAlert = message
    }

    /// Used as closures to create alerts when functions fail
    func okOrAlert(result: Result<Void, Error>) {
        if case let .failure(error) = result {
            createAlert(message: error.localizedDescription)
        }
    }

    var body: some View {
        VStack {
            // Title
            HStack {
                Text("Write to characteristic")
            }
            // Input area
            HStack {
                Spacer()
                Toggle(isOn: $isHex) {
                    Text("As HEX Value")
                }
                Divider()
                TextField("Value", text: $inputValue, onEditingChanged: {_ in }, onCommit: {
                    let data = isHex ? inputValue.data(using: .hex) : inputValue.data(using: .utf8)
                    if data == nil {
                        createAlert(message: "Malformed HEX data: \"\(inputValue)\"")
                    } else {
                        connection.write(
                            data: data!,
                            ofCharacWithUUID: characteristic.CBUUIDRepresentation.uuidString,
                            fromServiceWithUUID: characteristic.service.CBUUIDRepresentation.uuidString,
                            completion: okOrAlert
                        )
                        inputValue = ""
                    }
                })
                Spacer()
            }
        }
    }
}

struct NotifyOperationView: View {
    @Binding var connection: ConnectionController
    @Binding var characteristic: CBCharacteristic
    @Binding var bleAlert: String?

    var body: some View {
        Text("Notify")
    }
}

struct IndicateOperationView: View {
    @Binding var connection: ConnectionController
    @Binding var characteristic: CBCharacteristic
    @Binding var bleAlert: String?

    var body: some View {
        Text("Indicate")
    }
}

struct SignedWriteOperationView: View {
    @Binding var connection: ConnectionController
    @Binding var characteristic: CBCharacteristic
    @Binding var bleAlert: String?

    var body: some View {
        Text("Signed write")
    }
}

struct ExtendedOperationView: View {
    @Binding var connection: ConnectionController
    @Binding var characteristic: CBCharacteristic
    @Binding var bleAlert: String?

    var body: some View {
        Text("Extended")
    }
}

struct OperationsView: View {
    @Binding var connection: ConnectionController
    @Binding var characteristic: CBCharacteristic
    @Binding var bleAlert: String?

    @ViewBuilder
    private func viewSelector(prop: CharacProp) -> some View {
        switch prop {
        case .broadcast:
            BroadcastOperationView(
                connection: $connection,
                characteristic: $characteristic,
                bleAlert: $bleAlert
            )
        case .read:
            ReadOperationView(
                connection: $connection,
                characteristic: $characteristic,
                bleAlert: $bleAlert
            )
        case .writeNoResponse:
            WriteOperationView(
                connection: $connection,
                characteristic: $characteristic,
                bleAlert: $bleAlert
            )
        case .write:
            WriteOperationView(
                connection: $connection,
                characteristic: $characteristic,
                bleAlert: $bleAlert
            )
        case .notify:
            NotifyOperationView(
                connection: $connection,
                characteristic: $characteristic,
                bleAlert: $bleAlert
            )
        case .indicate:
            IndicateOperationView(
                connection: $connection,
                characteristic: $characteristic,
                bleAlert: $bleAlert
            )
        case .signedWrite:
            SignedWriteOperationView(
                connection: $connection,
                characteristic: $characteristic,
                bleAlert: $bleAlert
            )
        case .extended:
            ExtendedOperationView(
                connection: $connection,
                characteristic: $characteristic,
                bleAlert: $bleAlert
            )
        }
    }

    var body: some View {
        ScrollView {
            let props = characteristic.properties.forEachProp(action: {prop in return (UUID(), prop)})
            ForEach(props, id: \.0) {
                viewSelector(prop: $0.1)
            }
        }
    }
}
