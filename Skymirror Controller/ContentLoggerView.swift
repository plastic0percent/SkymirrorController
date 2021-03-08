//
//  ContentLoggerView.swift
//  Skymirror Controller
//
//  Created by 张迈允 on 2021/3/8.
//

import SwiftUI

struct ContentLoggerView: View {
    // UTF-8 or ASCII
    @State private var isUTF8 = false
    @Binding var logs: [BLELogEntry]
    
    var body: some View {
        VStack {
            // Options bar
            HStack {
                Spacer()
                // Encoding toggle, use button to display better
                Button(action: {
                    isUTF8 = !isUTF8
                }) {
                    Text("Use " + (isUTF8 ? "ASCII" : "UTF-8"))
                }
                Spacer()
                // Clear button
                Button(action: {
                    logs.removeAll()
                }) {
                    Text("Clear")
                }
                Spacer()
            }
            .frame(height: 100)
            // Scroll view of all logs
            ScrollView {
                ForEach(logs, id: \.id) {
                    let item = $0
                    HStack {
                        Text("[\(item.deviceUUID):\(item.characUUID)]")
                        Spacer()
                        Text("\(String.init(data: item.content, encoding: .hex))")
                        Divider()
                        Text("\(String.init(data: item.content, encoding: isUTF8 ? .utf8 : .ascii) ?? "")")
                    }
                }
            }
        }
        .navigationBarTitle(Text("Content Log"), displayMode: .inline)
    }
}
