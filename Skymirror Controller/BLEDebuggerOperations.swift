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

struct OperationsView: View {
    @Binding var connection: ConnectionController
    @Binding var characteristic: CBCharacteristic
    @Binding var bleAlert: String?

    var body: some View {
        ScrollView {
            let props = characteristic.properties.forEachProp(action: {prop in return (UUID(), prop)})
            ForEach(props, id: \.0) {
                switch $0.1 {
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
                    WriteNoResponseOperationView(
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
                Divider()
            }
        }
    }
}
