//
//  CacheAsyncImage.swift
//
//  Created by Costantino Pistagna on 08/02/23.
//

import SwiftUI

private class Cache {
    private var cache: [URL: Image] = [:]

    func get(_ url: URL) -> Image? {
        return cache[url]
    }

    func set(_ url: URL, _ image: Image) {
        cache[url] = image
    }
}

private let cache = Cache()

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
        if let image = cache.get(url) {
            content(image)
        } else {
            AsyncImage(url: url,
                       scale: scale,
                       content: {
                           cache.set(url, $0)
                           return content($0)
                       },
                       placeholder: placeholder)
        }
    }
}
