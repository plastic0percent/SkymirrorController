//
//  BLEDebuggerOperations.swift
//  Skymirror Controller
//
//  Created by 张迈允 on 2021/3/7.
//

import SwiftUI
import CoreBluetooth

// Characteristic property types
enum CharacProp {
    case broadcast
    case read
    case writeNoResponse
    case write
    case notify
    case indicate
    case signedWrite
    case extended
}

/// Extensions to read the properties better
extension CBCharacteristicProperties {
    /// Enumerate over all properties
    func forEachProp<ReturnValue>(
        action: (_ prop: CharacProp) -> ReturnValue) -> [ReturnValue] {
        var result: [ReturnValue] = []
        // Index of the currect bit
        var bitIndex = 0
        // The properties
        var prop = self.rawValue
        // Map between property and bit position
        let types: [CharacProp] = [.broadcast, .read, .writeNoResponse, .write, .notify, .indicate, .signedWrite, .extended]
        while prop != 0 {
            if prop & 0x01 != 0 {
                result.append(action(types[bitIndex]))
            }
            bitIndex += 1
            prop >>= 1
        }
        return result
    }
    
    /// Interpret CBCharacteristicProperties into descriptive string
    func interpretProperties() -> String {
        var result = String.init()
        let _ = self.forEachProp(action: {prop in
            switch prop {
            case .broadcast:
                result.append("BC ")
                break
            case .read:
                result.append("RD ")
                break
            case .writeNoResponse:
                result.append("WW ")
                break
            case .write:
                result.append("WR ")
                break
            case .notify:
                result.append("NO ")
                break
            case .indicate:
                result.append("IN ")
                break
            case .signedWrite:
                result.append("SW ")
                break
            case .extended:
                result.append("EX ")
                break
            }
        })
        return result
    }
}

struct BroadcastOperationView: View {
    var body: some View {
        Text("Broad cast")
    }
}

struct ReadOperationView: View {
    var body: some View {
        Text("Read")
    }
}

struct WriteNoResponseOperationView: View {
    var body: some View {
        Text("Write without response")
    }
}

struct WriteOperationView: View {
    var body: some View {
        Text("Write")
    }
}

struct NotifyOperationView: View {
    var body: some View {
        Text("Notify")
    }
}

struct IndicateOperationView: View {
    var body: some View {
        Text("Indicate")
    }
}

struct SignedWriteOperationView: View {
    var body: some View {
        Text("Signed write")
    }
}

struct ExtendedOperationView: View {
    var body: some View {
        Text("Extended")
    }
}

struct OperationsView: View {
    @Binding var charac: CBCharacteristic
    
    @ViewBuilder
    private func viewSelector(prop: CharacProp) -> some View{
        switch prop {
        case .broadcast:
            BroadcastOperationView()
        case .read:
            ReadOperationView()
        case .writeNoResponse:
            WriteNoResponseOperationView()
        case .write:
            WriteOperationView()
        case .notify:
            NotifyOperationView()
        case .indicate:
            IndicateOperationView()
        case .signedWrite:
            SignedWriteOperationView()
        case .extended:
            ExtendedOperationView()
        }
    }
    
    @ViewBuilder
    private func viewGenerate() -> some View {
        let items = charac.properties.forEachProp(action: viewSelector)
        ForEach(0..<items.count) {
            items[$0]
        }
    }
    
    var body: some View {
        viewGenerate()
    }
}
