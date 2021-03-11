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
    @State private var connection = ConnectionController(ifLog: true)
    @State private var foundDevices = [UUID: (Peripheral, Int?)]()
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
        // First clear all items
        foundDevices.removeAll(keepingCapacity: true)
        // And scan
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
        ScrollView {
            NavigationLink(destination: BLEDebuggerDeviceView(
                connection: $connection,
                bleAlert: $bleAlert
            ),
            isActive: $isLinkActive) {
                EmptyView()
            }
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
                    let peripheral = foundDevices[$0]!.0
                    let rssiString = foundDevices[$0]!.1 == nil ? "unknown" : "\(foundDevices[$0]!.1!)"
                    Button(action: {
                        connection.setPeripheral(peripheral: peripheral)
                        connection.connect(completion: {result in
                            switch result {
                            case .success:
                                // Go to Services page
                                isLinkActive = true
                            case .failure(let error):
                                createAlert(message: error.localizedDescription)
                            }
                        })
                    }, label: {
                        // Show device information
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Name: \(peripheral.name ?? "unknown")")
                                    .font(.system(size: 17))
                                    .padding(.leading)
                                Text("UUID: \(peripheral.identifier.uuidString)")
                                    .font(.system(size: 12, weight: .light))
                                    .padding(.leading)
                            }
                            Spacer()
                            Text("RSSI: \(rssiString)")
                                .font(.system(size: 11))
                                .padding(.trailing)
                        }
                    })
                    Divider()
                }
            }
        }
        .navigationBarTitle(Text("BLE Debugger"), displayMode: .inline)
        .onAppear {
            // If leaving from the previous view, disconnect everything
            connection.disconnect(completion: okOrAlert)
        }
    }
}

struct BLEDebuggerDeviceView: View {
    // Discovered services, use dictionary to avoid duplicates
    @State private var services = [String: (CBService, [CBCharacteristic])]()
    // Whether the link to the next view is active
    @State private var isLinkActive = false
    // The selected service
    @State private var selectedCharac: CBCharacteristic?
    // Whether this is the first entry to this view from BLEDebuggerMainView
    // The difference is that the post connect actions are only run upon the first entry
    @State var firstEntry = true
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

    /// Post-connect actions
    private func postConnectActions(
        characteristcs: [CBCharacteristic]
    ) {
        for characteristc in characteristcs {
            _ = characteristc.properties.forEachProp(action: {prop in
                switch prop {
                case .notify:
                    // Register notifications so that they appear in logs
                    let characUUID = characteristc.CBUUIDRepresentation.uuidString
                    let serviceUUID = characteristc.service.CBUUIDRepresentation.uuidString
                    if self.connection.ifNotify(
                        ofCharacWithUUID: characUUID,
                        fromServiceWithUUID: serviceUUID
                    ) == false {
                        self.connection.addNotify(
                            ofCharacWithUUID: characUUID,
                            fromServiceWithUUID: serviceUUID,
                            completion: {_ in}, onReceive: {_ in})
                    }
                default:
                    break
                }
            })
        }
    }

    /// On appear actions of the device view
    private func deviceOnAppear() {
        // First clear all flags
        self.isLinkActive = false
        // Construct a list of all services and their characteristics
        connection.scanServices { result in
            switch result {
            case .success(let servs):
                var waiting = servs.count
                for service in servs {
                    connection.scanCharacs(
                        fromServiceWithUUID: service.CBUUIDRepresentation.uuidString,
                        completion: {result in
                            switch result {
                            case .success(let characs):
                                self.services[service.CBUUIDRepresentation.uuidString] = (service, characs)
                                if self.firstEntry {
                                    self.postConnectActions(characteristcs: characs)
                                    waiting -= 1
                                }
                                if waiting == 0 {
                                    // Make sure the post-connect actions are not run
                                    // when returning from the peripherals
                                    self.firstEntry = false
                                }
                            case .failure(let error):
                                self.createAlert(message: error.localizedDescription)
                            }
                        })
                }
            case .failure(let error):
                self.createAlert(message: error.localizedDescription)
            }
        }
    }

    /// Make character view since integrating it will make it too complicated
    @ViewBuilder
    func characView(characs: [CBCharacteristic]) -> some View {
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
                VStack(alignment: .leading) {
                    // First row: name
                    HStack {
                        if "\(characName)" != characUUID {
                            Text("Name: \(characName)")
                                .font(.system(size: 17))
                        }
                        Spacer()
                    }
                    .padding(.leading)
                    // Second row: UUID
                    HStack {
                        Text("UUID: \(characUUID)")
                            .font(.system(size: 12, weight: .light))
                        Spacer()
                    }
                    .padding(.leading)
                    // Second row: properties and values
                    HStack {
                        Text("Properties: \(characProp.interpretProperties())")
                            .font(.system(size: 12, weight: .light))
                        if characVal != nil {
                            let strVal = String.init(
                                data: characVal!,
                                encoding: .utf8,
                                filter: {chr in
                                    xxdFilter(chr: chr, encoding: .utf8)
                                }
                            )
                            if strVal != nil {
                                Text("Value: \(strVal!)")
                                    .font(.system(size: 12, weight: .light))
                            }
                        }
                        Spacer()
                    }
                    .padding(.leading)
                }
            })
            Divider()
            Spacer()
        }
    }

    // MARK: Device View

    var titleTrailingItems: some View {
        // Show log
        NavigationLink(
            "Log",
            destination: ContentLoggerView(connection: $connection)
        )
    }

    var body: some View {
        ScrollView {
            NavigationLink(destination: BLEDebuggerCharacView(
                characteristic: $selectedCharac,
                connection: $connection,
                bleAlert: $bleAlert
            ),
            isActive: $isLinkActive) {
                EmptyView()
            }
            LazyVStack {
                // Show all found services
                ForEach(Array(services.keys), id: \.self) {
                    let service = services[$0]!.0
                    let serviceName = service.CBUUIDRepresentation
                    let serviceUUID = $0
                    let characs = services[$0]!.1

                    // Show service information
                    HStack {
                        Text("\(serviceName)" != serviceUUID
                                ? "\(serviceName) [\(serviceUUID)]:"
                                : "Service [\(serviceUUID)]:"
                        )
                        .font(.system(size: 13, weight: .ultraLight))
                        .padding(.leading)
                        Spacer()
                    }
                    Divider()
                    characView(characs: characs)
                }
            }
        }
        .navigationBarTitle(Text("Peripheral"), displayMode: .inline)
        .navigationBarItems(trailing: titleTrailingItems)
        .onAppear(perform: deviceOnAppear)
    }
}

struct BLEDebuggerCharacView: View {
    // This characteristic
    @Binding var characteristic: CBCharacteristic?
    @Binding var connection: ConnectionController
    @Binding var bleAlert: String?

    // MARK: Characteristic View

    var body: some View {
        ScrollView {
            LazyVStack {
                OperationsView(
                    connection: $connection,
                    characteristic: Binding($characteristic)!,
                    bleAlert: $bleAlert
                )
            }
        }
        .navigationBarTitle(Text("Characteristic"), displayMode: .inline)
    }
}
