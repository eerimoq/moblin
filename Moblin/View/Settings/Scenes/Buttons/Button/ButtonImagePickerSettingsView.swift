import SwiftUI

var imageSystemNames = [
    "mic",
    "mic.fill",
    "mic.slash",
    "mic.slash.fill",
    "film.fill",
    "film",
    "popcorn.fill",
    "popcorn",
    "gift",
    "gift.fill",
    "trash",
    "trash.fill",
    "paperplane",
    "paperplane.fill",
    "externaldrive.fill",
    "externaldrive",
    "arrowshape.right.fill",
    "arrowshape.left",
    "arrowshape.left.fill",
    "arrowshape.right",
    "figure.stand",
    "figure.2.arms.open",
    "figure.walk",
    "figure.wave",
    "tennis.racket",
    "trophy.fill",
    "trophy",
    "peacesign",
    "globe",
    "globe.americas",
    "globe.europe.africa",
    "globe.asia.australia.fill",
    "globe.central.south.asia",
    "globe.central.south.asia.fill",
    "sun.min.fill",
    "globe.americas.fill",
    "globe.europe.africa.fill",
    "globe.asia.australia",
    "sun.min",
    "tornado",
    "flashlight.on.fill",
    "flashlight.off.fill",
    "lightbulb",
    "lightbulb.fill",
    "moonphase.waxing.crescent",
    "moonphase.waning.crescent",
    "drop",
    "drop.fill",
    "speedometer",
    "dice",
    "dice.fill",
    "plus.magnifyingglass",
    "minus.magnifyingglass",
    "photo.artframe",
    "megaphone",
    "megaphone.fill",
    "music.mic",
    "person.3",
    "person.3.fill",
    "person.3.sequence",
    "person.3.sequence.fill",
    "figure.walk.motion",
    "rays",
    "slowmo",
    "zzz",
    "cloud.drizzle",
    "cloud.drizzle.fill",
    "tropicalstorm",
    "hurricane",
    "aqi.low",
    "aqi.medium",
    "water.waves",
    "swift",
    "circle.hexagongrid",
    "suit.heart",
    "suit.heart.fill",
    "star",
    "star.fill",
    "wand.and.rays",
    "wand.and.stars",
    "pianokeys",
    "theatermasks",
    "theatermasks.fill",
    "deskclock",
    "calendar.badge.clock",
    "book",
    "book.fill",
    "cricket.ball",
    "cricket.ball.fill",
    "medal",
    "medal.fill",
    "snowflake",
    "flame",
    "flame.fill",
    "rectangle.portrait",
    "rectangle.portrait.fill",
    "heart",
    "heart.fill",
    "bolt.heart",
    "bolt.heart.fill",
    "teddybear",
    "teddybear.fill",
    "pawprint",
    "pawprint.fill",
    "message",
    "message.fill",
    "sunset",
    "record.circle",
    "play",
    "play.circle",
    "play.tv",
    "antenna.radiowaves.left.and.right",
    "person.wave.2",
    "dot.radiowaves.left.and.right",
    "waveform",
    "apple.logo",
    "party.popper",
    "sportscourt",
    "frying.pan",
    "leaf",
    "timelapse",
    "wind.snow",
    "chair.lounge",
    "sparkles",
    "bandage",
    "bolt",
    "dumbbell",
    "balloon.2",
    "bubbles.and.sparkles",
    "figure.water.fitness",
    "figure.pickleball",
    "figure.racquetball",
    "figure.volleyball",
    "syringe",
    "fish",
    "ant",
    "circle.hexagonpath",
    "figure.soccer",
    "skateboard",
    "fireworks",
    "baseball.diamond.bases",
]

private let columns = [
    GridItem(.adaptive(minimum: 40), alignment: .center),
]

struct ButtonImagePickerSettingsView: View {
    @Environment(\.dismiss) var dismiss
    var title: String
    @State var selectedImageSystemName: String
    @State var filter: String = ""
    var onChange: (String) -> Void

    var body: some View {
        VStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        TextField("Icons", text: $filter)
                            .textInputAutocapitalization(.never)
                    }
                }
                Section {
                    ScrollView(showsIndicators: false) {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(imageSystemNames.filter { name in
                                filter.isEmpty || name.contains(filter.lowercased())
                            }, id: \.self) { imageSystemName in
                                Button {
                                    dismiss()
                                    onChange(imageSystemName)
                                    selectedImageSystemName = imageSystemName
                                } label: {
                                    if selectedImageSystemName == imageSystemName {
                                        Image(systemName: imageSystemName)
                                            .foregroundColor(.primary)
                                            .frame(width: 40, height: 40)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 5)
                                                    .stroke(.primary)
                                                    .foregroundColor(.primary)
                                            )
                                    } else {
                                        Image(systemName: imageSystemName)
                                            .foregroundColor(.primary)
                                            .frame(width: 40, height: 40)
                                    }
                                }
                            }
                        }
                    }
                    .padding([.top], 10)
                }
            }
        }
        .navigationTitle(title)
        .toolbar {
            SettingsToolbar()
        }
    }
}
