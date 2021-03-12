//
//  IndicateView.swift
//  Skymirror Controller
//
//  Created by 张迈允 on 2021/3/12.
//

import SwiftUI
import CoreBluetooth

struct IndicateOperationView: View {
    @Binding var connection: ConnectionController
    @Binding var characteristic: CBCharacteristic
    @Binding var bleAlert: String?

    var body: some View {
        Text("Indicate").font(.subheadline)
    }
}
