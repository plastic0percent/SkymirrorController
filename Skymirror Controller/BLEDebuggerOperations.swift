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

struct BroadcastOperationView: View {
    @Binding var connection: ConnectionController
    @Binding var characteristic: CBCharacteristic
    @Binding var bleAlert: String?

    var body: some View {
        Text("Broad cast").font(.subheadline)
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
                    let resultStr = String.init(data: result, encoding: .utf8, filter: {chr in
                        return xxdFilter(chr: chr, encoding: .utf8)
                    })
                    if resultStr != nil {
                        Text("UTF-8: \"\(resultStr!)\"")
                    }
                    Text("HEX: \(String.init(data: result, encoding: .HEX))")
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

    /// Commit text
    private func textCommit() {
        let data = self.isHex
            ? inputValue.data(using: .hex)
            : inputValue.data(using: .utf8)
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
    }

    var body: some View {
        VStack {
            // Title
            HStack {
                Text("Write to characteristic").font(.subheadline)
            }
            // Input area
            HStack {
                Spacer()
                Toggle(isOn: $isHex) {
                    Text("As HEX Value")
                }
                Divider()
                TextField("Value", text: $inputValue, onCommit: textCommit)
                Spacer()
            }
        }
    }
}

struct NotifyOperationView: View {
    @Binding var connection: ConnectionController
    @Binding var characteristic: CBCharacteristic
    @Binding var bleAlert: String?
    @State private var registeredNotify: Bool = false

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

    /// Toggle the registered state
    private func toggleRegistered(result: Result<Void, Error>) {
        if case .success = result {
            self.registeredNotify = !self.registeredNotify
        }
        okOrAlert(result: result)
    }

    /// Action to toggle notification state
    private func toggleNotifyAction() {
        let characUUID = self.characteristic.CBUUIDRepresentation.uuidString
        let serviceUUID = self.characteristic.service.CBUUIDRepresentation.uuidString
        if registeredNotify {
            self.connection.rmNotify(
                ofCharacWithUUID: characUUID,
                fromServiceWithUUID: serviceUUID,
                completion: toggleRegistered
            )
        } else {
            self.connection.addNotify(
                ofCharacWithUUID: characUUID,
                fromServiceWithUUID: serviceUUID,
                completion: toggleRegistered,
                onReceive: {_ in}
            )
        }
    }

    /// Check whether notification is registered
    private func bodyOnAppear() {
        self.registeredNotify = connection.ifNotify(
            ofCharacWithUUID: self.characteristic.CBUUIDRepresentation.uuidString,
            fromServiceWithUUID: self.characteristic.service.CBUUIDRepresentation.uuidString
        )
    }

    var body: some View {
        VStack {
            // Title
            HStack {
                Text("Notify").font(.subheadline)
            }
            HStack {
                Button(action: toggleNotifyAction, label: {
                    Text(self.registeredNotify
                            ? "Unregister notifications"
                            :"Register notifications"
                    )
                })
            }
        }
        .onAppear(perform: bodyOnAppear)
    }
}

struct IndicateOperationView: View {
    @Binding var connection: ConnectionController
    @Binding var characteristic: CBCharacteristic
    @Binding var bleAlert: String?

    var body: some View {
        Text("Indicate").font(.subheadline)
    }
}

struct SignedWriteOperationView: View {
    @Binding var connection: ConnectionController
    @Binding var characteristic: CBCharacteristic
    @Binding var bleAlert: String?

    var body: some View {
        Text("Signed write").font(.subheadline)
    }
}

struct ExtendedOperationView: View {
    @Binding var connection: ConnectionController
    @Binding var characteristic: CBCharacteristic
    @Binding var bleAlert: String?

    var body: some View {
        Text("Extended").font(.subheadline)
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
        case .write, .writeNoResponse:
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
                Divider()
            }
        }
    }
}
