//
//  WriteView.swift
//  Skymirror Controller
//
//  Created by 张迈允 on 2021/3/12.
//

import SwiftUI
import CoreBluetooth

struct UnifiedWriteOperationView: View, UseAlert {
    @State private var isHex = false
    @State private var inputValue = ""
    @Binding var connection: ConnectionController
    @Binding var characteristic: CBCharacteristic
    @Binding var bleAlert: String?
    var bleAlertBinding: Binding<String?> { $bleAlert }

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

struct WriteOperationView: View {
    @Binding var connection: ConnectionController
    @Binding var characteristic: CBCharacteristic
    @Binding var bleAlert: String?

    var body: some View {
        // Title
        HStack {
            Text("Write to characteristic").font(.subheadline)
        }
        UnifiedWriteOperationView(connection: $connection, characteristic: $characteristic, bleAlert: $bleAlert)
    }
}

struct WriteNoResponseOperationView: View {
    @Binding var connection: ConnectionController
    @Binding var characteristic: CBCharacteristic
    @Binding var bleAlert: String?

    var body: some View {
        // Title
        HStack {
            Text("Write to characteristic without response").font(.subheadline)
        }
        UnifiedWriteOperationView(connection: $connection, characteristic: $characteristic, bleAlert: $bleAlert)
    }
}
