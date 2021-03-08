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
    public var automaticLog: [BLELogEntry]?
    // Lock for writer
    let writeSemaphore = DispatchSemaphore(value: 1)
    
    init(ifLog: Bool = false) {
        self.automaticLog = ifLog ? [] : nil
    }
    
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
    func scanCharacs(fromServiceWithUUID: String, completion: @escaping (_ result: Result<[CBCharacteristic], Error>) -> Void) {
        if self.usingPeripheral == nil {
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
        if self.usingPeripheral == nil {
            return completion(.failure(ConnectionError.noDeviceError))
        }
        // Add BLE notification callback
        NotificationCenter.default.addObserver(forName: Peripheral.PeripheralCharacteristicValueUpdate,
                                               object: self.usingPeripheral,
                                               queue: nil) { notification in
            let charac = notification.userInfo!["characteristic"] as! CBCharacteristic
            if let error = notification.userInfo?["error"] as? SBError {
                return completion(.failure(error))
            }
            if charac.isNotifying {
                self.addToLog(data: charac.value!)
                onReceive(charac.value!)
            }
        }
        
        // Enable notification
        self.usingPeripheral!.setNotifyValue(
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
        self.usingPeripheral?.disconnect(completion: completion)
        // Avoid writing to disconnected devices
        self.usingPeripheral = nil
    }
    
    /// Add to some data to BLE ContentLogger refering to this Peripheral
    func addToLog(data: Data) {
        self.automaticLog?.append(BLELogEntry(
            deviceUUID: usingPeripheral!.identifier,
            characUUID: usingPeripheral!.identifier,
            content: data
        ))
    }
    
    /// Read data from the device
    func read(ofCharacWithUUID: String, fromServiceWithUUID: String, completion: @escaping (_ data: Result<Data, Error>) -> Void) {
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
    func write(data: Data, ofCharacWithUUID: String, fromServiceWithUUID: String, completion: @escaping ConnectionCallback) {
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

