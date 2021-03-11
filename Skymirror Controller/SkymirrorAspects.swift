//
//  SkymirrorAspects.swift
//  Skymirror Controller
//
//  Created by 张迈允 on 2021/3/6.
//

import Foundation
import SwiftUI
import SwiftyBluetooth

enum DataError: Error {
    case malformedDate(received: String)
    case jsonError(message: String)

}

extension DataError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .malformedDate(let received):
            return "Malformed date: \(received)"
        case .jsonError(let message):
            return message
        }
    }
}

enum ExpectedPayload {
    case imageData
    case statusData
}

struct DataResponse: Decodable {
    let time: String
    let accel: [Float]
    let speed: [Float]
    let displ: [Float]
    let pressure: Float
    let depth: Float
    let lat: Float
    let lon: Float

    init() {
        self.time = "2021-01-05T16:00:00"
        self.accel = [0.0, 0.0, 0.0]
        self.speed = [0.0, 0.0, 0.0]
        self.displ = [0.0, 0.0, 0.0]
        self.pressure = 10.0
        self.depth = 10.0
        self.lat = 31.607759
        self.lon = 120.736709
    }
}

class SkymirrorController {
    // BLE Connection
    public var connection = ConnectionController(ifLog: true)
    // Payload from BLE
    private var receivedPayload = Data.init()
    // Which payload is expected, 0 for status, 1 for image
    private var expectedPayload: ExpectedPayload = .statusData
    // Status payload, from receivedPayload
    private var decodedStatusPayload = DataResponse()

    /// Scan for devices, getting only an ID and the peripheral
    func scan(stateChange: @escaping (Result<(UUID, Peripheral), Error>) -> Void) {
        self.connection.scan(stateChange: {result in
            switch result {
            case .success((let peripheral, _)):
                stateChange(.success((peripheral.identifier, peripheral)))
            case .failure(let error):
                stateChange(.failure(error))
            }
        })
    }

    /// Connect the underlying BLE device
    func connect(peripheral: Peripheral, completion: @escaping ConnectionCallback) {
        self.connection.setPeripheral(peripheral: peripheral)
        self.connection.connect(completion: {result in
            switch result {
            case .success:
                self.connection.addNotify(
                    ofCharacWithUUID: "FFE1",
                    fromServiceWithUUID: "FFE0",
                    completion: completion,
                    onReceive: {val in
                        self.receivedPayload.append(val)
                        // Continue to process until ETX is received
                        let etxpos = self.receivedPayload.firstIndex(of: 0x03)
                        if etxpos != nil {
                            let stxpos = self.receivedPayload.firstIndex(of: 0x02)
                            if stxpos != nil {
                                // If no start symbol, drop this whole message
                                // Process payload, remove things before SOT and after EOT
                                let processedPayload = self.receivedPayload[stxpos!+1..<etxpos!]
                                // Process actual payload
                                switch self.expectedPayload {
                                // XXX: Possible data race when setting payload
                                case .imageData:
                                    break
                                case .statusData:
                                    // Only decode once received
                                    do {
                                        self.decodedStatusPayload = try JSONDecoder()
                                            .decode(DataResponse.self, from: processedPayload)
                                    } catch {
                                        let description = error.localizedDescription
                                        return completion(.failure(DataError.jsonError(message: description)))
                                    }
                                }
                            }
                            // Remove processed payload
                            self.receivedPayload.removeSubrange(0...etxpos!)
                        }
                    })
            case .failure(let error):
                completion(.failure(error))
            }
        })
    }

    /// Disconnect the underlying BLE device
    func disconnect(completion: @escaping ConnectionCallback) {
        self.connection.disconnect(completion: completion)
    }

    /// Write data to the FFE2 characteristc
    func write(cmd: UInt8, arg: UInt8, completion: @escaping ConnectionCallback) {
        let payloadData = Data([cmd, arg])
        connection.write(
            data: payloadData,
            ofCharacWithUUID: "FFE2",
            fromServiceWithUUID: "FFE0",
            completion: completion
        )
    }

    /// Set fish repeller frequency
    func setFrequency(frequency: Double, completion: @escaping ConnectionCallback) {
        self.write(cmd: 0x40, arg: UInt8(frequency / 30), completion: completion)
    }

    /// Set motor ESC speed
    func setEscSpeed(speed: Double, completion: @escaping ConnectionCallback) {
        self.write(cmd: 0x50, arg: UInt8(speed / 10), completion: completion)
    }

    /// Set turning servo value
    func setTurningValue(value: Double, completion: @escaping ConnectionCallback) {
        self.write(cmd: 0x60, arg: UInt8(value), completion: completion)
    }

    /// Send calibrate signal
    func calibrate(completion: @escaping ConnectionCallback) {
        self.write(cmd: 0x00, arg: 0x00, completion: completion)
    }

    /// Send re-setup signal
    func boardSetup(completion: @escaping ConnectionCallback) {
        self.write(cmd: 0xff, arg: 0x00, completion: completion)
    }

    /// Request status information
    func requestInfo(completion: @escaping ConnectionCallback) {
        self.expectedPayload = .statusData
        self.write(cmd: 0x02, arg: 0x00, completion: completion)
    }

    /// Request image
    func requestImage(completion: @escaping ConnectionCallback) {
        self.expectedPayload = .imageData
        self.write(cmd: 0x01, arg: 0x01, completion: completion)
    }

    /// Get a data value from the received payload
    private func getData(key: String, completion: (_ result: Result<String, Error>) -> Void) {
        var result: String
        switch key {
        case "time":
            let timeStrUTC = decodedStatusPayload.time
            let formatter = DateFormatter()
            formatter.timeZone = TimeZone(abbreviation: "UTC")
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            let gotDate = formatter.date(from: timeStrUTC)
            if gotDate == nil {
                return completion(.failure(DataError.malformedDate(received: timeStrUTC)))
            }
            formatter.timeZone = TimeZone.current
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            result = formatter.string(from: gotDate!)
        case "accel":
            result = String(format: "%.2fx %.2fy %.2fz",
                            decodedStatusPayload.accel[0],
                            decodedStatusPayload.accel[1],
                            decodedStatusPayload.accel[2]
            )
        case "speed":
            result = String(format: "%.2fx %.2fy %.2fz",
                            decodedStatusPayload.speed[0],
                            decodedStatusPayload.speed[1],
                            decodedStatusPayload.speed[2]
            )
        case "displ":
            result = String(format: "%.2fx %.2fy %.2fz",
                            decodedStatusPayload.displ[0],
                            decodedStatusPayload.displ[1],
                            decodedStatusPayload.displ[2]
            )
        case "pressure":
            result = String(format: "%.2f", decodedStatusPayload.pressure)
        case "depth":
            result = String(format: "%.2f", decodedStatusPayload.depth)
        case "lat":
            result = "\(decodedStatusPayload.lat)"
        case "lon":
            result = "\(decodedStatusPayload.lon)"
        default:
            result = ""
        }
        completion(.success(result))
    }

    /// Generate status list
    func genStatusList(completion: (_ result: Result<[(String, String)], Error>) -> Void) {
        var returnValue: [(String, String)] = []
        let statusTypes = [
            ("Time", "time"),
            ("Acceleration m/s\u{00b2}", "accel"),
            ("Speed m/s", "speed"),
            ("Displacement m", "displ"),
            ("Water Pressure kPa", "pressure"),
            ("Water Depth m", "depth"),
            ("Latitude N", "lat"),
            ("Longitude E", "lon")
        ]

        for (caption, key) in statusTypes {
            self.getData(key: key, completion: {result in
                switch result {
                case .success(let value):
                    returnValue.append((caption, value))
                case .failure(let error):
                    return completion(.failure(error))
                }
            })
        }
        completion(.success(returnValue))
    }
}
