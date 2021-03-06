//
//  ContentView.swift
//  Skymirror Controller
//
//  Created by 张迈允 on 2021/3/5.
//

import SwiftUI
import SwiftyBluetooth
import CoreBluetooth

enum DataError: Error{
    case malformedDate(received: String)
    case jsonError(message: String)
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
}

// Get a data value from the received payload
func getData(key: String, payload: Data) throws -> String {
    print(payload.base64EncodedString())
    let decoded: DataResponse
    do{
        decoded = try JSONDecoder()
            .decode(DataResponse.self, from: payload)
    } catch DecodingError.dataCorrupted(let error) {
        let description = error.underlyingError?.localizedDescription ?? "Unknown Error"
        print("JSON Error: \(description)")
        print("\(String(data: payload, encoding: .ascii)!)")
        throw DataError.jsonError(message: description)
    }
    switch key {
    case "time":
        let timeStrUTC = decoded.time
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        let gotDate = formatter.date(from: timeStrUTC)
        if gotDate == nil {
            throw DataError.malformedDate(received: timeStrUTC)
        }
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: gotDate!)
    case "accel":
        return String(format: "%.2fx %.2fy %.2fz ms^-2",
                      decoded.accel[0],
                      decoded.accel[1],
                      decoded.accel[2]
        )
    case "speed":
        return String(format: "%.2fx %.2fy %.2fz ms^-1",
                      decoded.speed[0],
                      decoded.speed[1],
                      decoded.speed[2]
        )
    case "displ":
        return String(format: "%.2fx %.2fy %.2fz m",
                      decoded.displ[0],
                      decoded.displ[1],
                      decoded.displ[2]
        )
    case "pressure":
        return String(format: "%.2f kPa", decoded.pressure)
    case "depth":
        return String(format: "%.2f m", decoded.depth)
    case "lat":
        return "\(decoded.lat)"
    case "lon":
        return "\(decoded.lon)"
    default:
        return ""
    }
}

// Get a human-readable name of the peripheral
func getDeviceName(peripheral: Peripheral) -> String {
    if peripheral.name != nil {
        return peripheral.name!
    }
    return peripheral.identifier.uuidString
}
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
    @State private var showBleAlert = false;
    // The Alert message
    @State private var bleAlertMsg: String = "";
    // Dictionary of (UUID: Peripheral)
    // Dictionary is used to avoid duplicate results
    @State private var foundDevices = [UUID: Peripheral]()
    // The Peripheral in use
    @State private var usingPeripheral: Peripheral? = nil
    // Whether the Scan pad is shown
    @State private var showScanPad = true;
    // Payload from the board
    @State private var receivedPayload: Data = "".data(using: .ascii)!;
    // Which payload is expected, 0 for status, 1 for image
    @State private var expectedPayload: UInt8 = 0;
    // Status payload, from receivedPayload
    @State private var statusPayload: Data = """
{
"time": "2021-01-05T16:00:00",
"accel": [0.0, 0.0, 0.0],
"speed": [0.0, 0.0, 0.0],
"displ": [0.0, 0.0, 0.0],
"pressure": 10.0,
"depth": 10.0,
"lat": 31.607759,
"lon": 120.736709
}
""".data(using: .ascii)!
    
    // Scan devices
    func scan() {
        SwiftyBluetooth.scanForPeripherals(
            withServiceUUIDs: nil,
            timeoutAfter: 15
        ) { scanResult in
            switch scanResult {
            case .scanStarted:
                // No need to handle this
                break
            case .scanResult(let peripheral, _, _):
                foundDevices[peripheral.identifier] = peripheral;
            case .scanStopped(_, let error):
                if error != nil {
                    showBleAlert = true
                    bleAlertMsg = error!.errorDescription!
                }
            }
        }
    }
    
    
    // Connect to a peripheral and set appropriate variables
    func connect(peripheral: Peripheral) {
        peripheral.connect(withTimeout: 15) { result in
            switch result {
            case .success:
                // Record the peripheral
                usingPeripheral = peripheral
                NotificationCenter.default.addObserver(forName: Peripheral.PeripheralCharacteristicValueUpdate,
                                                       object: peripheral,
                                                       queue: nil) { notification in
                    let charac = notification.userInfo!["characteristic"] as! CBCharacteristic
                    if let error = notification.userInfo?["error"] as? SBError {
                        showBleAlert = true
                        bleAlertMsg = error.localizedDescription
                        return
                    }
                    if charac.isNotifying {
                        let val = charac.value!
                        receivedPayload.append(val)
                        // Continue to process until EOT is received
                        let eotpos = receivedPayload.firstIndex(of: 0x04)
                        if eotpos != nil {
                            if expectedPayload == 0 {
                                // Update status payload, remove things after EOT
                                statusPayload = receivedPayload[0..<eotpos!]
                                print("Received data: \(statusPayload.base64EncodedString())")
                                // Clear received payload
                                receivedPayload.removeAll(keepingCapacity: true)
                            }
                        }
                    }
                }
                
                // We can then set a characteristic's notification value to true and start receiving updates to that characteristic
                peripheral.setNotifyValue(toEnabled: true, forCharacWithUUID: "FFE1", ofServiceWithUUID: "FFE0") { result in
                    // If there were no errors, you will now receive Notifications when that characteristic value gets updated.
                    print("Notification: \(result)")
                }
                // Update the information every second
                Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { timer in
                    request_info()
                })
                return
            case .failure(let error):
                showBleAlert = true
                bleAlertMsg = error.localizedDescription
                return
            }
        }
    }
    
    // Write data to the FFE2 characteristc
    func write(cmd: UInt8, arg: UInt8) {
        if usingPeripheral == nil {
            showBleAlert = true
            bleAlertMsg = "You should connect first"
            return
        }
        let payload: UInt16 = UInt16(cmd)<<8 + UInt16(arg)
        usingPeripheral!.writeValue(
            ofCharacWithUUID: "FFE2",
            fromServiceWithUUID: "FFE0",
            value: withUnsafeBytes(of: payload.bigEndian) { Data($0) }
        ) { result in
            switch result {
            case .success:
                return
            case .failure(let error):
                showBleAlert = true
                bleAlertMsg = error.localizedDescription
                return
            }
        }
    }
    
    // Send calibrate signal
    func calibrate() {
        write(cmd: 0x00, arg: 0x00)
    }
    
    // Send re-setup signal
    func board_setup() {
        write(cmd: 0xff, arg: 0x00)
    }
    
    // Request information
    func request_info() {
        expectedPayload = 0;
        write(cmd: 0x02, arg: 0x00)
    }
    
    // Request image
    func request_image() {
        expectedPayload = 1;
        write(cmd: 0x01, arg: 0x01)
    }
    
    // MARK: View starts here
    
    var body: some View {
        // Title
        VStack {
            HStack {
                Text("Skymirror Controller").font(.title)
                // Connection selection
                Button(action: {() -> Void in
                    showScanPad = !showScanPad;
                }) {
                    Text(showScanPad ? "Hide" : "Connect")
                    Image(systemName: "iphone.radiowaves.left.and.right")
                }
            }
            if showScanPad {
                // The scanning tab
                ScrollView {
                    LazyVStack {
                        // "Scan" button
                        Button(action: scan) {
                            Text("Scan")
                            Image(systemName: "magnifyingglass")
                        }
                        // Show all found devices
                        ForEach(Array(foundDevices.keys), id: \.self) {
                            let peripheral = foundDevices[$0]!;
                            let name = getDeviceName(peripheral: peripheral);
                            Button(action: {() -> Void in
                                connect(peripheral: peripheral)
                            }, label: {
                                Text(name)
                            })
                        }
                    }
                }
            }
        }.alert(isPresented: $showBleAlert) { () -> Alert in
            let button = Alert.Button.default(Text("Dismiss"))
            return Alert(title: Text("BLE Warning"),
                         message: Text(bleAlertMsg),
                         dismissButton: button
            )
        }
        
        // MARK: Data columns
        VStack {
            Divider()
            
            // Show data
            let datas = [
                ("Time", "time"),
                ("Acceleration", "accel"),
                ("Speed", "speed"),
                ("Displacement", "displ"),
                ("Water Pressure", "pressure"),
                ("Water Depth", "depth"),
                ("Latitude", "lat"),
                ("Longitude", "lon")
            ]
            
            let columns: [GridItem] =
                Array(repeating: .init(.flexible()), count: 2)
            ScrollView {
                LazyVGrid(columns: columns) {
                    ForEach(datas, id: \.1) {
                        let title = $0.0
                        let value = try? getData(key: $0.1,
                                                 payload: statusPayload
                        )
                        // Data caption
                        Text("\(title)")
                            .bold()
                            .font(.system(size: 18))
                        // Data value
                        Text("\(value ?? "Error")")
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
                                write(cmd: 0x40,
                                      arg: UInt8(freqVal / 30))
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
                            write(cmd: 0x50,
                                  arg: UInt8(motorVal / 10))
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
                            write(cmd: 0x60,
                                  arg: UInt8(turningVal))
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
                Button(action: calibrate) {
                    Text("Calibrate Sensor")
                }
                // Re-setup
                Button(action: board_setup) {
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

