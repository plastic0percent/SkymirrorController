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
}

extension ConnectionError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .noDeviceError:
            return "You should connect first"
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
    private var usingPeripheral: Peripheral? = nil
    
    /// Scan all devices, whenever state changes, stateChange is called
    func scan(stateChange: @escaping (Result<(Peripheral, [String: Any], Int?), Error>) -> Void) {
        SwiftyBluetooth.scanForPeripherals(
            withServiceUUIDs: nil,
            timeoutAfter: 15
        ) { scanResult in
            switch scanResult {
            case .scanStarted:
                // No need to handle this
                break
            case .scanResult(let peripheral, let advertisement, let RSSI):
                stateChange(.success((peripheral, advertisement, RSSI)));
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
        if usingPeripheral == nil {
            return completion(.failure(ConnectionError.noDeviceError))
        }
        usingPeripheral!.connect(withTimeout: 15, completion: completion)
    }
    
    /// Scan for services
    func scanServices(completion: @escaping (_ result: Result<[CBService], Error>) -> Void) {
        if usingPeripheral == nil {
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
    func scanCharacs(fromServiceWithUUID: String, completion: @escaping (_ result: Result<[CBCharacteristic], Error>) -> Void) {
        if usingPeripheral == nil {
            return completion(.failure(ConnectionError.noDeviceError))
        }
        self.usingPeripheral!.discoverCharacteristics(withUUIDs: nil, ofServiceWithUUID: fromServiceWithUUID) { result in
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
        if usingPeripheral == nil {
            return completion(.failure(ConnectionError.noDeviceError))
        }
        // Add BLE notification callback
        NotificationCenter.default.addObserver(forName: Peripheral.PeripheralCharacteristicValueUpdate,
                                               object: usingPeripheral,
                                               queue: nil) { notification in
            let charac = notification.userInfo!["characteristic"] as! CBCharacteristic
            if let error = notification.userInfo?["error"] as? SBError {
                return completion(.failure(error))
            }
            if charac.isNotifying {
                onReceive(charac.value!)
            }
        }
        
        // Enable notification
        usingPeripheral!.setNotifyValue(
            toEnabled: true,
            forCharacWithUUID: ofCharacWithUUID,
            ofServiceWithUUID: fromServiceWithUUID
        ) { result in
            print("Notification: \(result)")
        }
        return completion(.success(()))
    }
    
    /// Disconnect the device
    func disconnect(completion: @escaping ConnectionCallback) {
        usingPeripheral?.disconnect(completion: completion)
    }
    
    /// Read data from the device
    func read(ofCharacWithUUID: String, fromServiceWithUUID: String, completion: @escaping (_ data: Result<Data, Error>) -> Void) {
        if usingPeripheral == nil {
            return completion(.failure(ConnectionError.noDeviceError))
        }
        usingPeripheral!.readValue(
            ofCharacWithUUID: ofCharacWithUUID,
            fromServiceWithUUID: fromServiceWithUUID,
            completion: completion
        )
    }
    
    /// Write data to the device
    func write(data: Data, ofCharacWithUUID: String, fromServiceWithUUID: String, completion: @escaping ConnectionCallback) {
        if usingPeripheral == nil {
            return completion(.failure(ConnectionError.noDeviceError))
        }
        usingPeripheral!.writeValue(
            ofCharacWithUUID: ofCharacWithUUID,
            fromServiceWithUUID: fromServiceWithUUID,
            value: data,
            completion: completion
        )
    }
}

