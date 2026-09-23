import CoreText
import SwiftUI

private struct FontFamilyPickerView: View {
    @Binding var font: SettingsFont
    var onChange: () -> Void
    @State private var fontFamilies: [String] = []

    var body: some View {
        Form {
            Section {
                List {
                    HStack {
                        Text("System")
                        Spacer()
                        Button {
                            font = SettingsFont()
                            onChange()
                        } label: {
                            if font.family == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    ForEach(fontFamilies, id: \.self) { family in
                        HStack {
                            Text(family)
                                .font(.custom(family, size: 17))
                            Spacer()
                            Button {
                                font = SettingsFont(family: family,
                                                    style: UIFont.fontNames(forFamilyName: family)
                                                        .first ?? "")
                                onChange()
                            } label: {
                                if font.family == family {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Family")
        .onAppear {
            if fontFamilies.isEmpty {
                fontFamilies = Self.loadFontFamilies()
            }
        }
    }

    private static func loadFontFamilies() -> [String] {
        var families = Set(UIFont.familyNames)
        let collection = CTFontCollectionCreateFromAvailableFonts(nil)
        if let descriptors =
            CTFontCollectionCreateMatchingFontDescriptors(collection) as? [CTFontDescriptor]
        {
            for descriptor in descriptors {
                if let family = CTFontDescriptorCopyAttribute(
                    descriptor,
                    kCTFontFamilyNameAttribute
                ) as? String {
                    families.insert(family)
                }
            }
        }
        return families.sorted()
    }
}

func fontStyleName(family: String, fontName: String) -> String {
    let prefix = family.replace(" ", "")
    let name = fontName.replace("-", "")
    if name.hasPrefix(prefix) {
        let suffix = String(name.dropFirst(prefix.count))
        return suffix.isEmpty ? "Regular" : suffix
    }
    return fontName
}

private struct FontStylePickerView: View {
    let fontFamily: String
    @Binding var font: SettingsFont
    var onChange: () -> Void

    private func fontStyles() -> [String] {
        UIFont.fontNames(forFamilyName: fontFamily)
    }

    var body: some View {
        List {
            ForEach(fontStyles(), id: \.self) { style in
                HStack {
                    Text(fontStyleName(family: fontFamily, fontName: style))
                        .font(.custom(style, size: 17))
                    Spacer()
                    Button {
                        font.style = style
                        onChange()
                    } label: {
                        if font.style == style {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
        .navigationTitle("Style")
    }
}

struct FontSettingsView: View {
    @Binding var font: SettingsFont
    var onChange: () -> Void

    var body: some View {
        NavigationLink {
            FontFamilyPickerView(font: $font, onChange: onChange)
        } label: {
            HStack {
                Text("Family")
                Spacer()
                GrayTextView(text: font.familyString())
            }
        }
        if let family = font.family {
            NavigationLink {
                FontStylePickerView(fontFamily: family, font: $font, onChange: onChange)
            } label: {
                HStack {
                    Text("Style")
                    Spacer()
                    GrayTextView(text: font.styleString())
                }
            }
            .disabled(UIFont.fontNames(forFamilyName: family).count == 1)
        }
    }
}
