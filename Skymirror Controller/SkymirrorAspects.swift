//
//  SkymirrorAspects.swift
//  Skymirror Controller
//
//  Created by 张迈允 on 2021/3/6.
//

import Foundation
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
    public var connection = ConnectionController()
    // Which payload is expected, 0 for status, 1 for image
    private var expectedPayload: ExpectedPayload = .statusData;
    // Status payload, from receivedPayload
    private var decodedStatusPayload = DataResponse()
    
    /// Connect the underlying BLE device
    func connect(peripheral: Peripheral, completion: @escaping ConnectionCallback) {
        // XXX: Possible data race when setting payload
        self.connection.setOnReceiveComplete(callback: {(payload: Data) -> Void in
            switch self.expectedPayload {
            case .imageData:
                break
            case .statusData:
                // Only decode once received
                do {
                    self.decodedStatusPayload = try JSONDecoder()
                        .decode(DataResponse.self, from: payload)
                } catch {
                    let description = error.localizedDescription
                    return completion(.failure(DataError.jsonError(message: description)))
                }
            }
        })
        self.connection.connect(peripheral: peripheral, completion: completion)
    }
    
    /// Set fish repeller frequency
    func setFrequency(frequency: Double, completion: @escaping ConnectionCallback) {
        connection.write(cmd: 0x40, arg: UInt8(frequency / 30), completion: completion)
    }
    
    /// Set motor ESC speed
    func setEscSpeed(speed: Double, completion: @escaping ConnectionCallback) {
        connection.write(cmd: 0x50, arg: UInt8(speed / 10), completion: completion)
    }
    
    /// Set turning servo value
    func setTurningValue(value: Double, completion: @escaping ConnectionCallback) {
        connection.write(cmd: 0x60, arg: UInt8(value), completion: completion)
    }
    
    /// Send calibrate signal
    func calibrate(completion: @escaping ConnectionCallback) {
        connection.write(cmd: 0x00, arg: 0x00, completion: completion)
    }
    
    /// Send re-setup signal
    func boardSetup(completion: @escaping ConnectionCallback) {
        connection.write(cmd: 0xff, arg: 0x00, completion: completion)
    }
    
    /// Request status information
    func requestInfo(completion: @escaping ConnectionCallback) {
        expectedPayload = .statusData;
        connection.write(cmd: 0x02, arg: 0x00, completion: completion)
    }
    
    /// Request image
    func requestImage(completion: @escaping ConnectionCallback) {
        expectedPayload = .imageData;
        connection.write(cmd: 0x01, arg: 0x01, completion: completion)
    }
    
    /// Get a data value from the received payload
    func getData(key: String, completion: (_ result: Result<String, Error>) -> Void) {
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
            break
        case "accel":
            result = String(format: "%.2fx %.2fy %.2fz",
                            decodedStatusPayload.accel[0],
                            decodedStatusPayload.accel[1],
                            decodedStatusPayload.accel[2]
            )
            break
        case "speed":
            result = String(format: "%.2fx %.2fy %.2fz",
                            decodedStatusPayload.speed[0],
                            decodedStatusPayload.speed[1],
                            decodedStatusPayload.speed[2]
            )
            break
        case "displ":
            result = String(format: "%.2fx %.2fy %.2fz",
                            decodedStatusPayload.displ[0],
                            decodedStatusPayload.displ[1],
                            decodedStatusPayload.displ[2]
            )
            break
        case "pressure":
            result = String(format: "%.2f", decodedStatusPayload.pressure)
            break
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
            ("Acceleration \u{33a8}", "accel"),
            ("Speed \u{33a7}", "speed"),
            ("Displacement m", "displ"),
            ("Water Pressure \u{33aa}", "pressure"),
            ("Water Depth m", "depth"),
            ("Latitude N", "lat"),
            ("Longitude E", "lon")
        ]
        
        for (caption, key) in statusTypes {
            self.getData(key: key, completion: {result in
                switch result {
                case .success(let value):
                    returnValue.append((caption, value))
                    break
                case .failure(let error):
                    return completion(.failure(error))
                }
            })
        }
        completion(.success(returnValue))
    }
}
