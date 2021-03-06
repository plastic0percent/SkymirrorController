//
//  UnifiedLogger.swift
//  Skymirror Controller
//
//  Created by 张迈允 on 2021/3/8.
//

import Foundation

struct BLELogEntry: Identifiable {
    // swiftlint:disable identifier_name
    var id: UUID
    var deviceUUID: String
    var characUUID: String
    var content: Data

    /// Initializer with a generated id
    init(deviceUUID: String, characUUID: String, content: Data) {
        self.id = UUID()
        self.deviceUUID = deviceUUID
        self.characUUID = characUUID
        self.content = content
    }

    init(deviceUUID: UUID, characUUID: UUID, content: Data) {
        self.init(
            deviceUUID: deviceUUID.uuidString,
            characUUID: characUUID.uuidString,
            content: content
        )
    }
}
