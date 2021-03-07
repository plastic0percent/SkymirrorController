//
//  BLEDebuggerViews.swift
//  Skymirror Controller
//
//  Created by 张迈允 on 2021/3/7.
//

import SwiftUI
import SwiftyBluetooth
import CoreBluetooth

struct BLEDebuggerMainView: View {
    @State private var connection = ConnectionController()
    @State private var foundDevices = [UUID: (Peripheral, [String: Any], Int?)]()
    // Whether the link to the next view is active
    @State private var isLinkActive = false
    @Binding var bleAlert: String?
    
    /// Create an alert with a Dismiss button
    func createAlert(message: String) {
        self.bleAlert = message
    }
    
    /// Used as closures to create alerts when functions fail
    func okOrAlert(result: Result<Void, Error>) {
        if case let .failure(error) = result {
            createAlert(message: error.localizedDescription)
        }
    }
    
    // MARK: Debugger Main View
    
    /// Scan for devices wrapper
    private func scanAction() {
        connection.scan(stateChange: {result in
            switch result {
            case .success(let item):
                foundDevices[item.0.identifier] = item
            case .failure(let error):
                createAlert(message: error.localizedDescription)
            }
        })
    }
    
    var body: some View {
        VStack {
            ScrollView {
                LazyVStack {
                    // "Scan" button
                    Button(action: scanAction) {
                        Text("Rescan")
                        Image(systemName: "magnifyingglass")
                    }.onAppear {
                        // Start scan automatically
                        self.scanAction()
                    }
                    // Show all found devices
                    ForEach(Array(foundDevices.keys), id: \.self) {
                        let peripheral = foundDevices[$0]!.0;
                        let rssiString = foundDevices[$0]!.2 == nil ? "unknown" : "\(foundDevices[$0]!.2!)"
                        Button(action: {
                            connection.setPeripheral(peripheral: peripheral)
                            connection.connect(completion: okOrAlert)
                            isLinkActive = true
                        }, label: {
                            // Show device information
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Name: \(peripheral.name ?? "unknown")")
                                        .font(.system(size: 17))
                                    Text("UUID: \(peripheral.identifier.uuidString)")
                                        .font(.system(size: 12, weight: .light))
                                }
                                Spacer()
                                Text("RSSI: \(rssiString)")
                                    .font(.system(size: 11))
                            }
                        })
                        Divider()
                    }
                    // Put the navigation link to the background
                    .background(
                        NavigationLink(destination: BLEDebuggerDeviceView(connection: $connection, bleAlert: $bleAlert),
                                       isActive: $isLinkActive) {
                            EmptyView()
                        }
                        .hidden()
                    )
                }
            }
        }
        .navigationTitle(Text("BLE Debugger"))
    }
}


struct BLEDebuggerDeviceView: View {
    // Discovered services
    @State private var services: [(CBService, [CBCharacteristic])] = []
    // Whether the link to the next view is active
    @State private var isLinkActive = false
    // The selected service
    @State private var selectedCharac: CBCharacteristic? = nil
    @Binding var connection: ConnectionController
    @Binding var bleAlert: String?
    
    /// Create an alert with a Dismiss button
    func createAlert(message: String) {
        self.bleAlert = message
    }
    
    /// Used as closures to create alerts when functions fail
    func okOrAlert(result: Result<Void, Error>) {
        if case let .failure(error) = result {
            createAlert(message: error.localizedDescription)
        }
    }
    
    // MARK: Device View
    var body: some View {
        VStack {
            ScrollView {
                LazyVStack {
                    // Show all found services
                    ForEach(services, id: \.0) {
                        let service = $0.0
                        let serviceName = service.CBUUIDRepresentation
                        let serviceUUID = service.CBUUIDRepresentation.uuidString
                        let characs = service.characteristics ?? []
                        
                        // Show service information
                        HStack {
                            Text("\(serviceName)" != serviceUUID ? "\(serviceName) [\(serviceUUID)]:" : "Service [\(serviceUUID)]:")
                                .font(.system(size: 15))
                            Spacer()
                        }
                        
                        Divider()
                        ForEach(characs, id: \.self) {
                            let charac = $0
                            let characName = charac.CBUUIDRepresentation
                            let characUUID = charac.CBUUIDRepresentation.uuidString
                            let characProp = charac.properties
                            let characVal = charac.value
                            
                            Button(action: {
                                self.selectedCharac = charac
                                isLinkActive = true
                            }, label: {
                                VStack {
                                    // First row: name and UUID
                                    HStack(alignment: .center) {
                                        if "\(characName)" != characUUID {
                                            Text("Name: \(characName)")
                                                .font(.system(size: 17))
                                        }
                                        Spacer()
                                        Text("UUID: \(characUUID)")
                                            .font(.system(size: 12, weight: .light))
                                    }
                                    // Second row: properties and values
                                    HStack {
                                        Text("Properties: \(characProp.interpretProperties())")
                                            .font(.system(size: 12, weight: .light))
                                        if characVal != nil {
                                            let strVal = String.init(data: characVal!, encoding: .utf8)
                                            if strVal != nil {
                                                Text("Value: \(strVal!)")
                                                    .font(.system(size: 12, weight: .light))
                                            }
                                        }
                                        Spacer()
                                    }
                                }
                            })
                            Divider()
                            Spacer()
                        }
                    }
                    // Put the navigation link to the background
                    .background(
                        NavigationLink(destination: BLEDebuggerCharacView(characteristic: $selectedCharac, connection: $connection, bleAlert: $bleAlert),
                                       isActive: $isLinkActive) {
                            EmptyView()
                        }
                        .hidden()
                    )
                }
            }
        }
        .navigationTitle(Text("Services and Characteristics"))
        .onAppear {
            // Construct a list of all services and their characteristics
            connection.scanServices() { result in
                switch result {
                case .success(let servs):
                    for service in servs {
                        connection.scanCharacs(
                            fromServiceWithUUID: service.CBUUIDRepresentation.uuidString,
                            completion: {result in
                                switch result {
                                case .success(let characs):
                                    self.services.append((service, characs))
                                    break
                                case .failure(let error):
                                    self.createAlert(message: error.localizedDescription)
                                    break
                                }
                            })
                    }
                    break
                case .failure(let error):
                    self.createAlert(message: error.localizedDescription)
                    break
                }
            }
        }
        .onDisappear() {
            connection.disconnect(completion: okOrAlert)
        }
    }
}

struct BLEDebuggerCharacView: View {
    // This characteristic
    @Binding var characteristic: CBCharacteristic?
    @Binding var connection: ConnectionController
    @Binding var bleAlert: String?
    
    // MARK: Characteristic View
    var body: some View {
        VStack {
            ScrollView {
                LazyVStack {
                    OperationsView(connection: $connection, characteristic: Binding($characteristic)!, bleAlert: $bleAlert)
                }
            }
        }
        .navigationTitle(Text("Characteristic Operations"))
    }
}

