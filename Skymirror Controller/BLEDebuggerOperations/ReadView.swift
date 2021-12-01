//
//  ReadView.swift
//  Skymirror Controller
//
//  Created by 张迈允 on 2021/3/12.
//

import SwiftUI
import CoreBluetooth

struct ReadOperationView: View, UseAlert {
    @Binding var connection: ConnectionController
    @Binding var characteristic: CBCharacteristic
    @Binding var bleAlert: String?
    @State private var result = Data.init()
    var bleAlertBinding: Binding<String?> { $bleAlert }

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
                        fromServiceWithUUID: characteristic.service!.CBUUIDRepresentation.uuidString,
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
