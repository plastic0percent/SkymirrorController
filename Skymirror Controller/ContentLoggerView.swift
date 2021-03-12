//
//  ContentLoggerView.swift
//  Skymirror Controller
//
//  Created by 张迈允 on 2021/3/8.
//

import Foundation
import SwiftUI

struct ContentLoggerView: View {
    // UTF-8 or ASCII
    @State private var isUTF8 = false
    @Binding var logs: [BLELogEntry]

    var body: some View {
        // Options bar
        HStack {
            Spacer()
            // Encoding toggle, use button to display better
            Button(action: {
                isUTF8 = !isUTF8
            }, label: {
                Text("Use " + (isUTF8 ? "ASCII" : "UTF-8"))
            })
            Spacer()
            // Clear button
            Button(action: {
                logs.removeAll()
            }, label: {
                Text("Clear")
            })
            Spacer()
        }
        .frame(height: 100)
        // Scroll view of all logs
        ScrollView {
            ForEach(logs) {
                let item = $0
                HStack {
                    Text("[\(item.deviceUUID):\(item.characUUID)]")
                        .font(.system(size: 13, weight: .ultraLight))
                        .padding(.leading)
                    Spacer()
                }
                Divider()
                HStack {
                    VStack(alignment: .leading) {
                        let encoding: String.Encoding = isUTF8 ? .utf8 : .ascii
                        let decodedArmored = String.init(
                            data: item.content,
                            encoding: encoding,
                            filter: {chr in
                                return xxdFilter(chr: chr, encoding: encoding)
                            }
                        ) ?? ""
                        Text("\(String.init(data: item.content, encoding: .HEX))")
                            .font(Font.custom("Courier New", size: 16))
                        Text("\(decodedArmored)")
                            .font(Font.custom("Courier New", size: 16))
                    }
                    .padding(.leading)
                    Spacer()
                }
                Divider()
            }
        }
        .navigationBarTitle(Text("Content Log"), displayMode: .inline)
    }
}

extension ContentLoggerView {
    init(connection: Binding<ConnectionController>) {
        self.init(logs: Binding(connection.automaticLog)!)
    }
}
