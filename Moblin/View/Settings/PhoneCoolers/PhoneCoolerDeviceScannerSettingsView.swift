//
//  PhoneCoolerDeviceScannerSettingsView.swift
//  Moblin
//
//  Created by Krister Berntsen on 09/06/2025.
//

import SwiftUI

struct PhoneCoolerDeviceScannerSettingsView: View {
    
    @EnvironmentObject var model: Model
    //@ObservedObject private var scanner = heartRateScanner
    @Environment(\.dismiss) var dismiss
    var onChange: (String) -> Void
    @State var selectedId: String
    
    var body: some View {
        Text("test")
    }
    
}
