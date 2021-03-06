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
    // Payload from BLE
    private var receivedPayload = Data.init()
    // Payload receive complete callback
    private var onReceiveComplete: ((_ payload: Data) -> Void)? = nil
    
    /// Scan devices, whenever state changes, stateChange is called
    func scan(stateChange: @escaping (Result<(UUID, Peripheral), Error>) -> Void) {
        SwiftyBluetooth.scanForPeripherals(
            withServiceUUIDs: nil,
            timeoutAfter: 15
        ) { scanResult in
            switch scanResult {
            case .scanStarted:
                // No need to handle this
                break
            case .scanResult(let peripheral, _, _):
                stateChange(.success((peripheral.identifier, peripheral)));
            case .scanStopped(_, let error):
                if error != nil {
                    stateChange(.failure(error!))
                }
            }
        }
    }
    
    /// Set the onReceiveComplete trigger
    func setOnReceiveComplete(callback: @escaping ((_ payload: Data) -> Void)) {
        self.onReceiveComplete = callback
    }
    
    /// Connect to a peripheral and set appropriate variables
    func connect(peripheral: Peripheral, completion: @escaping ConnectionCallback) {
        peripheral.connect(withTimeout: 15) { result in
            switch result {
            case .success:
                // Record the peripheral
                self.usingPeripheral = peripheral
                // Add BLE notification callback
                NotificationCenter.default.addObserver(forName: Peripheral.PeripheralCharacteristicValueUpdate,
                                                       object: peripheral,
                                                       queue: nil) { notification in
                    let charac = notification.userInfo!["characteristic"] as! CBCharacteristic
                    if let error = notification.userInfo?["error"] as? SBError {
                        return completion(.failure(error))
                    }
                    if charac.isNotifying {
                        let val = charac.value!
                        self.receivedPayload.append(val)
                        // Continue to process until EOT is received
                        let eotpos = self.receivedPayload.firstIndex(of: 0x04)
                        if eotpos != nil {
                            // Process payload, remove things after EOT
                            let processedPayload = self.receivedPayload[0..<eotpos!]
                            print("Received data: \(processedPayload.base64EncodedString())")
                            // Send the trimmed payload
                            if self.onReceiveComplete != nil {
                                self.onReceiveComplete!(processedPayload)
                            }
                            // Clear received payload
                            self.receivedPayload.removeAll(keepingCapacity: true)
                            
                        }
                    }
                }
                
                // Enable notification
                peripheral.setNotifyValue(
                    toEnabled: true,
                    forCharacWithUUID: "FFE1",
                    ofServiceWithUUID: "FFE0"
                ) { result in
                    print("Notification: \(result)")
                }
                return completion(.success(()))
            case .failure(let error):
                return completion(.failure(error))
            }
        }
    }
    
    // Write data to the FFE2 characteristc
    func write(cmd: UInt8, arg: UInt8, completion: @escaping ConnectionCallback) {
        if usingPeripheral == nil {
            return completion(.failure(ConnectionError.noDeviceError))
        }
        let payload: UInt16 = UInt16(cmd)<<8 + UInt16(arg)
        usingPeripheral!.writeValue(
            ofCharacWithUUID: "FFE2",
            fromServiceWithUUID: "FFE0",
            value: withUnsafeBytes(of: payload.bigEndian) { Data($0) }
        ) { result in
            switch result {
            case .success:
                return completion(.success(()))
            case .failure(let error):
                return completion(.failure(error))
            }
        }
    }
}

