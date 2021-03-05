//
//  ContentView.swift
//  Skymirror Controller
//
//  Created by 张迈允 on 2021/3/5.
//

import SwiftUI

class NumberInput: ObservableObject {
    @Published var valueStr = "" {
        didSet {
            let filtered = valueStr.filter { $0.isNumber }
            
            if valueStr != filtered {
                valueStr = filtered
            }
        }
    }
}

struct ContentView: View {
    @State private var fishRepellerOn = false
    @State private var isFreqEditing = false
    @ObservedObject var freqVal = NumberInput()
    @State private var isMotorEditing = false
    @State private var motorVal = 1500.0
    @State private var isTurningEditing = false
    @State private var turningVal = 38.0
    
    var body: some View {
        // Title
        Text("Skymirror Controller").font(/*@START_MENU_TOKEN@*/.title/*@END_MENU_TOKEN@*/)
        
        // Fish repeller toggle
        Toggle(isOn: $fishRepellerOn) {
            Text("Fish Repeller")
        }
        
        if fishRepellerOn {
            TextField(
                "Frequency",
                text: $freqVal.valueStr
            ) { isEditing in
                self.isFreqEditing = isEditing
            } //onCommit: {
            //validate(name: freqVal)
            //}
            .keyboardType(.decimalPad)
            .disableAutocorrection(true)
            .border(Color(UIColor.separator))
            Text(freqVal.valueStr)
                .foregroundColor(isFreqEditing ? .red : .blue)
            
        }
        
        // Motor control
        VStack {
            Text("Main Motor")
            Slider(
                value: $motorVal,
                in: 1500...2000,
                onEditingChanged: { editing in
                    isMotorEditing = editing
                }
            )
            Text("\(motorVal)")
                .foregroundColor(isMotorEditing ? .red : .blue)
        }
        // Turning control
        VStack {
            Text("Direction")
            Slider(
                value: $turningVal,
                in: 23...54,
                onEditingChanged: { editing in
                    isTurningEditing = editing
                }
            )
            Text("\(turningVal)")
                .foregroundColor(isTurningEditing ? .red : .blue)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
