import Network
import SwiftUI

private struct UrlSettingsView: View {
    let model: Model
    @Environment(\.dismiss) var dismiss
    @ObservedObject var stream: SettingsRtspClientStream
    @Binding var url: String
    @State var value: String
    let allowedSchemes: [String]?
    @State private var changed: Bool = false
    @State private var submitted: Bool = false
    @State private var error: String?
    @State private var presentingHelp: Bool = false

    private func submitUrl() {
        guard !submitted else {
            return
        }
        value = cleanUrl(url: value)
        if isValidUrl(url: value, allowedSchemes: allowedSchemes) != nil {
            dismiss()
            return
        }
        submitted = true
        url = value
        model.reloadRtspClient()
        dismiss()
    }

    var body: some View {
        Form {
            Section {
                MultiLineTextFieldView(value: $value)
                    .textInputAutocapitalization(.never)
                    .onSubmit {
                        submitUrl()
                    }
                    .submitLabel(.done)
                    .onChange(of: value) { _ in
                        error = isValidUrl(url: value, allowedSchemes: allowedSchemes)
                        changed = true
                        if value.contains("\n") {
                            value = value.replacingOccurrences(of: "\n", with: "")
                            submitUrl()
                        }
                    }
                    .disableAutocorrection(true)
            } footer: {
                if let error {
                    FormFieldError(error: error)
                }
            }
            Section {
                TextButtonView("Examples") {
                    presentingHelp = true
                }
                .sheet(isPresented: $presentingHelp) {
                    NavigationView {
                        Form {
                            Section("TP-Link") {
                                UrlCopyView("rtsp://username:password@192.168.1.83/stream1")
                            }
                        }
                        .navigationTitle("Examples")
                        .toolbar {
                            CloseToolbar(presenting: $presentingHelp)
                        }
                    }
                }
            }
        }
        .onDisappear {
            if changed && !submitted {
                submitUrl()
            }
        }
        .navigationTitle("URL")
    }
}

struct RtspClientStreamSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var rtspClient: SettingsRtspClient
    @ObservedObject var stream: SettingsRtspClientStream

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    NameEditView(name: $stream.name, existingNames: rtspClient.streams)
                }
                Section {
                    NavigationLink {
                        UrlSettingsView(model: model,
                                        stream: stream,
                                        url: $stream.url,
                                        value: stream.url,
                                        allowedSchemes: ["rtsp"])
                    } label: {
                        TextItemLocalizedView(name: "URL", value: stream.url, sensitive: true)
                    }
                }
                Section {
                    Picker("Transport", selection: $stream.transport) {
                        ForEach(SettingsRtspTransport.allCases, id: \.self) {
                            Text($0.toString())
                        }
                    }
                    .onChange(of: stream.transport) { _ in
                        model.reloadRtspClient()
                    }
                }
                Section {
                    TextEditNavigationView(
                        title: String(localized: "Latency"),
                        value: String(stream.latency),
                        onChange: {
                            guard let latency = Int32($0) else {
                                return String(localized: "Not a number")
                            }
                            guard latency >= 5 else {
                                return String(localized: "Too small")
                            }
                            guard latency <= 10000 else {
                                return String(localized: "Too big")
                            }
                            return nil
                        },
                        onSubmit: {
                            guard let latency = Int32($0) else {
                                return
                            }
                            stream.latency = latency
                            model.reloadRtspClient()
                        },
                        footers: [String(localized: "5 or more milliseconds. 2000 ms by default.")],
                        keyboardType: .numbersAndPunctuation,
                        valueFormat: { "\($0) ms" }
                    )
                } footer: {
                    Text("The higher, the lower risk of stuttering.")
                }
            }
            .navigationTitle("Stream")
        } label: {
            Toggle(isOn: $stream.enabled) {
                HStack {
                    Text(stream.name)
                }
            }
            .onChange(of: stream.enabled) { _ in
                model.reloadRtspClient()
            }
        }
    }
}
