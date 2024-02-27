import SwiftUI
import WrappingHStack

let smallFont = Font.system(size: 13)

struct StreamOverlayTextView: View {
    var text: String
    var textColor: Color

    var body: some View {
        Text(text)
            .foregroundColor(textColor)
            .padding([.leading, .trailing], 2)
            .background(Color(white: 0, opacity: 0.6))
            .cornerRadius(5)
    }
}

struct StreamOverlayIconAndTextView: View {
    var icon: String
    var text: String
    var color: Color = .white
    var textColor: Color = .white

    var body: some View {
        HStack(spacing: 1) {
            StreamOverlayTextView(text: text, textColor: textColor)
                .font(smallFont)
            Image(systemName: icon)
                .frame(width: 17, height: 17)
                .font(smallFont)
                .padding([.leading, .trailing], 2)
                .foregroundColor(color)
                .background(Color(white: 0, opacity: 0.6))
                .cornerRadius(5)
        }
        .padding(0)
    }
}

struct MainView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        TabView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ZStack {
                        Image("Preview")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .padding([.bottom], 3)
                        VStack(spacing: 1) {
                            Spacer()
                            HStack {
                                Spacer()
                                StreamOverlayIconAndTextView(
                                    icon: "waveform",
                                    text: "|||||||||",
                                    textColor: .green
                                )
                            }
                            HStack {
                                Spacer()
                                StreamOverlayIconAndTextView(
                                    icon: "speedometer",
                                    text: "3,4 Mbps"
                                )
                            }
                            .padding([.bottom], 4)
                        }
                        .padding([.leading], 3)
                    }
                    WrappingHStack(
                        alignment: .leading,
                        horizontalSpacing: 0,
                        verticalSpacing: 0,
                        fitContentWidth: true
                    ) {
                        Text("19:25 ")
                            .foregroundColor(.gray)
                        Text("erik")
                            .foregroundColor(.yellow)
                        Text(": ")
                        Text("Hello ")
                        Text("all, ")
                        Text("how ")
                        Text("are ")
                        Text("you ")
                        Text("doing?")
                    }
                    WrappingHStack(
                        alignment: .leading,
                        horizontalSpacing: 0,
                        verticalSpacing: 0,
                        fitContentWidth: true
                    ) {
                        Text("19:24 ")
                            .foregroundColor(.gray)
                        Text("99cowS")
                            .foregroundColor(.green)
                        Text(": ")
                        Text("fewokoewf ")
                        Text("weoke ")
                        Text("wfokowekf ")
                        Text("wf ")
                        Text("dwww")
                    }
                    WrappingHStack(
                        alignment: .leading,
                        horizontalSpacing: 0,
                        verticalSpacing: 0,
                        fitContentWidth: true
                    ) {
                        Text("19:23 ")
                            .foregroundColor(.gray)
                        Text("foobar")
                            .foregroundColor(.red)
                        Text(": :)")
                    }
                    WrappingHStack(
                        alignment: .leading,
                        horizontalSpacing: 0,
                        verticalSpacing: 0,
                        fitContentWidth: true
                    ) {
                        Text("19:24 ")
                            .foregroundColor(.gray)
                        Text("99cowS")
                            .foregroundColor(.green)
                        Text(": ")
                        Text("we ")
                        Text("ew")
                    }
                    WrappingHStack(
                        alignment: .leading,
                        horizontalSpacing: 0,
                        verticalSpacing: 0,
                        fitContentWidth: true
                    ) {
                        Text("19:22 ")
                            .foregroundColor(.gray)
                        Text("Kalle")
                            .foregroundColor(.brown)
                        Text(": POG !!!!")
                    }
                }
            }
            .ignoresSafeArea()
            .edgesIgnoringSafeArea([.top, .leading, .trailing])
            VStack(alignment: .leading) {
                HStack {
                    Image(systemName: "waveform")
                    Text("|||||||||")
                        .foregroundColor(.green)
                    Spacer()
                }
                HStack {
                    Image(systemName: "speedometer")
                    Text("3,4 Mbps")
                    Spacer()
                }
                HStack {
                    Image(systemName: "deskclock")
                    Text("58m 34s")
                    Spacer()
                }
                HStack {
                    Image(systemName: "message")
                    Text("5 new")
                    Spacer()
                }
                Spacer()
            }
        }
        .onAppear {
            model.setup()
        }
    }
}
