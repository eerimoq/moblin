//
//  CacheAsyncImage.swift
//
//  Created by Costantino Pistagna on 08/02/23.
//

import SwiftUI

struct CacheAsyncImage<Content, Content2>: View where Content: View, Content2: View {
    private let url: URL
    private let scale: CGFloat
    private let content: (Image) -> Content
    private let placeholder: () -> Content2

    init(url: URL,
         scale: CGFloat = 1,
         @ViewBuilder content: @escaping (Image) -> Content,
         @ViewBuilder placeholder: @escaping () -> Content2)
    {
        self.url = url
        self.scale = scale
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        if let image = ImageCache[url] {
            content(image)
        } else {
            AsyncImage(url: url,
                       scale: scale,
                       content: { cacheAndRender(image: $0) },
                       placeholder: placeholder)
        }
    }

    private func cacheAndRender(image: Image) -> some View {
        ImageCache[url] = image
        return content(image)
    }
}

private enum ImageCache {
    private static var cache: [URL: Image] = [:]
    static subscript(url: URL) -> Image? {
        get {
            return ImageCache.cache[url]
        }
        set {
            ImageCache.cache[url] = newValue
        }
    }
}
