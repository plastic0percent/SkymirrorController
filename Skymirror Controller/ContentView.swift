//
//  ContentView.swift
//  Skymirror Controller
//
//  Created by 张迈允 on 2021/3/5.
//

import SwiftUI
import SwiftyBluetooth
import CoreBluetooth

struct ContentView: View {
    // Whether the fish repeller beeper is on
    @State private var fishRepellerOn = false
    // Whether frequency is being edited
    @State private var isFreqEditing = false
    // Current-set frequency
    @State private var freqVal = 0.0
    // Whether motor speed is being edited
    @State private var isMotorEditing = false
    // Current-set motor speed
    @State private var motorVal = 1500.0
    // Whether direction is being edited
    @State private var isTurningEditing = false
    // Current-set turing position
    @State private var turningVal = 38.5
    // Whether an Alert relating to BLE is shown
    @State private var isShowBleAlert = false;
    // The Alert message
    @State private var bleAlertMsg: String = "";
    // Whether the Scan pad is shown
    @State private var isShowScanPad = true;
    // Dictionary of (UUID: Peripheral)
    // Dictionary is used to avoid duplicate results
    @State private var foundDevices = [UUID: Peripheral]()
    // Status of Skymirror
    @State private var statusList: [(String, String)] = []
    private var skymirrorController = SkymirrorController()
    
    /// Toggle BLE device scan area
    func toggleScanPad() {
        isShowScanPad = !isShowScanPad
    }
    
    /// Create an alert with a Dismiss button
    func createAlert(message: String) {
        isShowBleAlert = true
        bleAlertMsg = message
    }
    
    /// Used as closures to create alerts when functions fail
    func okOrAlert(result: Result<Void, Error>) {
        if case let .failure(error) = result {
            createAlert(message: error.localizedDescription)
        }
    }
    
    /// Convert functions with a completion callback to simple functions which alerts on failure
    func wrapperAlertCb(origFunc: @escaping (_ completion: @escaping ConnectionCallback) -> Void) -> (() -> Void) {
        return {() -> Void in
            origFunc(self.okOrAlert)
        }
    }
    
    /// Request status from Skymirror and update state
    private func reqStatusUpdate() {
        // Send information request
        self.skymirrorController.requestInfo(completion: okOrAlert)
        // Separate calls since they are not always correlated
        self.skymirrorController.genStatusList(completion: {result in
            switch result {
            case .success(let gotStatusList):
                statusList = gotStatusList
            case .failure(let error):
                createAlert(message: error.localizedDescription)
            }
        })
    }
    
    private func scanAction() {
        skymirrorController.connection.scan(stateChange: {result in
            switch result {
            case .success(let item):
                foundDevices[item.0] = item.1
            case .failure(let error):
                createAlert(message: error.localizedDescription)
            }
        })
    }
    
    // MARK: View starts here
    
    var body: some View {
        // Title
        VStack {
            HStack {
                Text("Skymirror Controller").font(.title)
                // Connection selection
                Button(action: {() -> Void in
                    toggleScanPad()
                }) {
                    Text(isShowScanPad ? "Hide" : "Connect")
                    Image(systemName: "iphone.radiowaves.left.and.right")
                }
            }
            if isShowScanPad {
                // The scanning tab
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
                            let peripheral = foundDevices[$0]!;
                            let name = getDeviceName(peripheral: peripheral);
                            Button(action: {() -> Void in
                                skymirrorController.connect(
                                    peripheral: peripheral,
                                    completion: {result in
                                        switch result {
                                        case .success:
                                            // Update the information every second
                                            Timer.scheduledTimer(
                                                withTimeInterval: 1.0,
                                                repeats: true,
                                                block: {_ in self.reqStatusUpdate()}
                                            )
                                            // Hide scan bar
                                            isShowScanPad = false
                                            break
                                        case .failure(let error):
                                            self.createAlert(message: error.localizedDescription)
                                        }
                                    })
                            }, label: {
                                Text(name)
                            })
                        }
                    }
                }
            }
        }.alert(isPresented: $isShowBleAlert) { () -> Alert in
            let button = Alert.Button.default(Text("Dismiss"))
            return Alert(title: Text("BLE Warning"),
                         message: Text(bleAlertMsg),
                         dismissButton: button
            )
        }
        
        // MARK: Data columns
        VStack {
            Divider()
            // Place this notice if not connected
            if statusList.isEmpty {
                Text("Welcome to Skymirror Controller")
                Text("Press \"Scan\" to look for a device")
            }
            let columns: [GridItem] =
                Array(repeating: .init(.flexible()), count: 2)
            ScrollView {
                LazyVGrid(columns: columns) {
                    ForEach(statusList, id: \.0) {
                        let title = $0.0
                        let value = $0.1
                        // Data caption
                        Text("\(title)")
                            .bold()
                            .font(.system(size: 18))
                        // Data value
                        Text("\(value)")
                            .font(.system(size: 16, weight: .light))
                    }
                }
            }
        }
        
        // MARK: Fish repeller control
        VStack {
            Divider()
            // Fish repeller toggle
            HStack {
                Spacer()
                Toggle(isOn: $fishRepellerOn) {
                    Text("Fish Repeller")
                }
                Spacer()
            }
            
            // Allow editing frequency only when on
            if fishRepellerOn {
                Divider()
                Text("Frequency")
                HStack {
                    Spacer()
                    Slider(
                        value: $freqVal,
                        in: 0...7679,
                        onEditingChanged: { editing in
                            isFreqEditing = editing
                            if editing == false {
                                // Commit value
                                skymirrorController.setFrequency(frequency: freqVal, completion: okOrAlert)
                            }
                        }
                    )
                    Text(String(format: "%.2f", freqVal))
                        .foregroundColor(isFreqEditing ? .red : .blue)
                    Spacer()
                }
            }
        }
        
        // MARK: Motor control
        VStack {
            Divider()
            Text("Main Motor")
            HStack {
                Spacer()
                Slider(
                    value: $motorVal,
                    in: 1500...2000,
                    onEditingChanged: { editing in
                        isMotorEditing = editing
                        if editing == false {
                            // Commit value
                            skymirrorController.setEscSpeed(speed: motorVal, completion: okOrAlert)
                        }
                    }
                )
                Text(String(format: "%.2f", motorVal))
                    .foregroundColor(isMotorEditing ? .red : .blue)
                Spacer()
            }
        }
        
        // MARK: Turning control
        VStack {
            Divider()
            Text("Direction")
            HStack {
                Spacer()
                Text("L")
                Slider(
                    value: $turningVal,
                    in: 23...54,
                    onEditingChanged: { editing in
                        isTurningEditing = editing
                        if editing == false {
                            // Commit value
                            skymirrorController.setTurningValue(value: turningVal, completion: okOrAlert)
                        }
                    }
                )
                Text("R")
                Spacer()
            }
            Text(String(format: "%.2f", turningVal))
                .foregroundColor(isTurningEditing ? .red : .blue)
        }
        
        // MARK: Calibration control
        VStack {
            Divider()
            HStack {
                // Calibrate sensor
                Button(action: wrapperAlertCb(origFunc: skymirrorController.calibrate)) {
                    Text("Calibrate Sensor")
                }
                // Re-setup
                Button(action: wrapperAlertCb(origFunc: skymirrorController.boardSetup)) {
                    Text("Setup")
                }
            }
        }
        
        // MARK: Footnote
        VStack {
            Divider()
            Text("Copyright \u{00a9} 2021, Plastic 0%. All rights reserved.")
                .font(.footnote)
                .foregroundColor(.gray)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

