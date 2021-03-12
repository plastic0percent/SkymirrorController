//
//  Connection.swift
//  Skymirror Controller
//
//  Created by 张迈允 on 2021/3/6.
//

import Foundation
import SwiftyBluetooth
import CoreBluetooth

typealias ConnectionCallback = (_ result: Result<Void, Error>) -> Void

enum ConnectionError {
    case noDeviceError
    case malformedResponse(whichOne: String)
}

extension ConnectionError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .noDeviceError:
            return "You should connect first"
        case .malformedResponse(let whichOne):
            return "Value at \(whichOne) is unexpected"
        }
    }
}

// Get a human-readable name of the peripheral
func getDeviceName(peripheral: Peripheral) -> String {
    if peripheral.name != nil {
        return peripheral.name!
    }
    return peripheral.identifier.uuidString
}

class ConnectionController {
    // The Peripheral in use
    private var usingPeripheral: Peripheral?
    public var automaticLog: [BLELogEntry]?
    // States
    private var notifications = [[String]: Bool]()
    // Lock for writer
    let writeSemaphore = DispatchSemaphore(value: 1)

    init(ifLog: Bool = false) {
        self.automaticLog = ifLog ? [] : nil
    }

    /// Scan all devices, whenever state changes, stateChange is called
    func scan(stateChange: @escaping (Result<(Peripheral, Int?), Error>) -> Void) {
        SwiftyBluetooth.scanForPeripherals(
            withServiceUUIDs: nil,
            timeoutAfter: 15
        ) { scanResult in
            switch scanResult {
            case .scanStarted:
                // No need to handle this
                break
            case .scanResult(let peripheral, _, let RSSI):
                stateChange(.success((peripheral, RSSI)))
            case .scanStopped(_, let error):
                if error != nil {
                    stateChange(.failure(error!))
                }
            }
        }
    }

    func setPeripheral(peripheral: Peripheral) {
        self.usingPeripheral = peripheral
    }

    /// Connect to a peripheral and set appropriate variables
    func connect(completion: @escaping ConnectionCallback) {
        if self.usingPeripheral == nil {
            return completion(.failure(ConnectionError.noDeviceError))
        }
        self.usingPeripheral!.connect(withTimeout: 15, completion: completion)
    }

    /// Scan for services
    func scanServices(completion: @escaping (_ result: Result<[CBService], Error>) -> Void) {
        if self.usingPeripheral == nil {
            return completion(.failure(ConnectionError.noDeviceError))
        }
        self.usingPeripheral!.discoverServices(withUUIDs: nil) { result in
            switch result {
            case .success(let services):
                return completion(.success(services))
            case .failure(let error):
                return completion(.failure(error))
            }
        }
    }

    /// Scan for characteristics
    func scanCharacs(
        fromServiceWithUUID: String,
        completion: @escaping (_ result: Result<[CBCharacteristic], Error>) -> Void
    ) {
        if self.usingPeripheral == nil {
            return completion(.failure(ConnectionError.noDeviceError))
        }
        self.usingPeripheral!.discoverCharacteristics(
            withUUIDs: nil,
            ofServiceWithUUID: fromServiceWithUUID
        ) { result in
            switch result {
            case .success(let services):
                return completion(.success(services))
            case .failure(let error):
                return completion(.failure(error))
            }
        }
    }

    /// Register notification
    func addNotify(ofCharacWithUUID: String,
                   fromServiceWithUUID: String,
                   completion: @escaping ConnectionCallback,
                   onReceive: @escaping (_ value: Data) -> Void) {
        if self.usingPeripheral == nil {
            return completion(.failure(ConnectionError.noDeviceError))
        }
        // Add BLE notification callback
        NotificationCenter.default.addObserver(forName: Peripheral.PeripheralCharacteristicValueUpdate,
                                               object: self.usingPeripheral!,
                                               queue: nil) { notification in
            if notification.userInfo == nil {
                return completion(.failure(ConnectionError.malformedResponse(whichOne: "notification")))
            }
            let charac = notification.userInfo!["characteristic"] as? CBCharacteristic
            if let error = notification.userInfo?["error"] as? SBError {
                return completion(.failure(error))
            }
            if charac == nil {
                return completion(.failure(ConnectionError.malformedResponse(whichOne: "notification.userInfo")))
            }
            if charac!.isNotifying {
                self.addToLog(data: charac!.value!)
                onReceive(charac!.value!)
            }
        }

        // Enable notification
        self.usingPeripheral!.setNotifyValue(
            toEnabled: true,
            forCharacWithUUID: ofCharacWithUUID,
            ofServiceWithUUID: fromServiceWithUUID,
            completion: {result in
                switch result {
                case .success:
                    self.notifications[[ofCharacWithUUID, fromServiceWithUUID]] = true
                    return completion(.success(()))
                case .failure(let error):
                    return completion(.failure(error))
                }
            }
        )
    }

    /// Check if notification is registered
    func ifNotify(ofCharacWithUUID: String, fromServiceWithUUID: String) -> Bool {
        return self.notifications[[ofCharacWithUUID, fromServiceWithUUID]] ?? false
    }

    /// Remove registered notification
    func rmNotify(ofCharacWithUUID: String,
                  fromServiceWithUUID: String,
                  completion: @escaping ConnectionCallback
    ) {
        if self.usingPeripheral == nil {
            return completion(.success(()))
        }
        NotificationCenter.default.removeObserver(
            self, // Not really sure if this is the correct way to call this
            name: Peripheral.PeripheralCharacteristicValueUpdate,
            object: self.usingPeripheral!
        )
        // NotificationCenter.default.removeObserver
        self.usingPeripheral!.setNotifyValue(
            toEnabled: false,
            forCharacWithUUID: ofCharacWithUUID,
            ofServiceWithUUID: fromServiceWithUUID,
            completion: {result in
                switch result {
                case .success:
                    self.notifications[[ofCharacWithUUID, fromServiceWithUUID]] = false
                    return completion(.success(()))
                case .failure(let error):
                    return completion(.failure(error))
                }
            }
        )
    }

    /// Disconnect the device
    func disconnect(completion: @escaping ConnectionCallback) {
        self.usingPeripheral?.disconnect(completion: completion)
        // Avoid writing to disconnected devices
        self.usingPeripheral = nil
    }

    /// Add to some data to BLE ContentLogger referring to this Peripheral
    func addToLog(data: Data) {
        self.automaticLog?.append(BLELogEntry(
            deviceUUID: usingPeripheral!.identifier,
            characUUID: usingPeripheral!.identifier,
            content: data
        ))
    }

    /// Read data from the device
    func read(
        ofCharacWithUUID: String,
        fromServiceWithUUID: String,
        completion: @escaping (_ data: Result<Data, Error>) -> Void
    ) {
        if self.usingPeripheral == nil {
            return completion(.failure(ConnectionError.noDeviceError))
        }
        self.usingPeripheral!.readValue(
            ofCharacWithUUID: ofCharacWithUUID,
            fromServiceWithUUID: fromServiceWithUUID,
            completion: {result in
                if case let .success(data) = result {
                    self.addToLog(data: data)
                }
                completion(result)
            }
        )
    }

    /// Write data to the device
    func write(
        data: Data,
        ofCharacWithUUID: String,
        fromServiceWithUUID: String,
        completion: @escaping ConnectionCallback
    ) {
        if self.usingPeripheral == nil {
            return completion(.failure(ConnectionError.noDeviceError))
        }
        self.writeSemaphore.wait()
        usingPeripheral!.writeValue(
            ofCharacWithUUID: ofCharacWithUUID,
            fromServiceWithUUID: fromServiceWithUUID,
            value: data,
            completion: {result in
                self.writeSemaphore.signal()
                completion(result)
            }
        )
    }
}
