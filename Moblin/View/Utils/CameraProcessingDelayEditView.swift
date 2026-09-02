import SwiftUI

struct CameraProcessingDelayEditView: View {
    let value: Int32
    let onSubmit: (Int32) -> Void

    var body: some View {
        TextEditNavigationView(
            title: String(localized: "Camera processing delay"),
            value: String(value),
            onChange: { value in
                guard let delay = Int32(value), delay >= 0 else {
                    return String(localized: "Must be zero or more milliseconds")
                }
                return nil
            },
            onSubmit: { value in
                guard let delay = Int32(value), delay >= 0 else {
                    return
                }
                onSubmit(delay)
            },
            footers: [
                String(localized: "0 ms by default."),
                String(
                    localized: "Additional delay introduced by this camera before its stream reaches Moblin."
                ),
            ],
            keyboardType: .numbersAndPunctuation,
            valueFormat: { "\($0) ms" }
        )
    }
}
