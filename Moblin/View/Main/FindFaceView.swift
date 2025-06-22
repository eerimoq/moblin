import SwiftUI

struct FindFaceView: View {
    var body: some View {
        HStack {
            Spacer()
            VStack {
                Spacer()
                VStack {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 30))
                    Text("Find a face")
                }
                .foregroundColor(.white)
                .padding(5)
                .background(backgroundColor)
                .cornerRadius(5)
                Spacer()
            }
            Spacer()
        }
    }
}
