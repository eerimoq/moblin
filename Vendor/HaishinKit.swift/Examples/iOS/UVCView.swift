import AVFoundation
import Charts
import HaishinKit
import SwiftUI

@available(iOS 17.0, *)
struct UVCView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject var preference: PreferenceViewModel
    @StateObject private var model = UVCViewModel()

    var body: some View {
        ZStack {
            VStack {
                if preference.viewType == .pip {
                    PiPHKViewRepresentable(previewSource: model)
                } else {
                    MTHKViewRepresentable(previewSource: model)
                }
            }
            VStack {
                HStack(spacing: 16) {
                    Spacer()
                    Button(action: {
                        model.toggleRecording()
                    }, label: {
                        Image(systemName: model.isRecording ?
                                "recordingtape.circle.fill" :
                                "recordingtape.circle")
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                    })
                }
                .frame(height: 50)
                HStack {
                    Spacer()
                    Toggle(isOn: $model.isHDREnabled) {
                        Text("HDR")
                    }.frame(width: 120)
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }.frame(height: 80)
                Spacer()
                HStack {
                    Spacer()
                    switch model.readyState {
                    case .connecting:
                        Spacer()
                    case .open:
                        Button(action: {
                            model.stopPublishing()
                        }, label: {
                            Image(systemName: "stop.circle")
                                .foregroundColor(.white)
                                .font(.system(size: 24))
                        })
                        .frame(width: 60, height: 60)
                        .background(Color.blue)
                        .cornerRadius(30.0)
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 16.0, trailing: 16.0))
                    case .closing:
                        Spacer()
                    case .closed:
                        Button(action: {
                            model.startPublishing(preference)
                        }, label: {
                            Image(systemName: "record.circle")
                                .foregroundColor(.white)
                                .font(.system(size: 24))
                        })
                        .frame(width: 60, height: 60)
                        .background(Color.blue)
                        .cornerRadius(30.0)
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 16.0))
                    }
                }.frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            model.startRunning(preference)
        }
        .onDisappear {
            model.stopRunning()
        }.alert(isPresented: $model.isShowError) {
            Alert(
                title: Text("Error"),
                message: Text(String(describing: model.error)),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

#Preview {
    if #available(iOS 17.0, *) {
        UVCView()
    }
}
