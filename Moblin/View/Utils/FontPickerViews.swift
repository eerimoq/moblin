import CoreText
import SwiftUI

struct FontFamilyPickerView: View {
    @Binding var selectedFontFamily: String?
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
                            selectedFontFamily = nil
                            onChange()
                        } label: {
                            if selectedFontFamily == nil {
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
                                selectedFontFamily = family
                                onChange()
                            } label: {
                                if selectedFontFamily == family {
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

struct FontStylePickerView: View {
    var fontFamily: String
    @Binding var selectedFontStyle: String
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
                        selectedFontStyle = style
                        onChange()
                    } label: {
                        if selectedFontStyle == style {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
        .navigationTitle("Style")
    }
}
