//
//  NotifyView.swift
//  Skymirror Controller
//
//  Created by 张迈允 on 2021/3/12.
//

import SwiftUI
import CoreBluetooth

struct NotifyOperationView: View, UseAlert {
    @Binding var connection: ConnectionController
    @Binding var characteristic: CBCharacteristic
    @Binding var bleAlert: String?
    @State private var registeredNotify: Bool = false
    var bleAlertBinding: Binding<String?> { $bleAlert }

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
        let serviceUUID = self.characteristic.service!.CBUUIDRepresentation.uuidString
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
            fromServiceWithUUID: self.characteristic.service!.CBUUIDRepresentation.uuidString
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
