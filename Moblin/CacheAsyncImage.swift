//
//  CacheAsyncImage.swift
//
//  Created by Costantino Pistagna on 08/02/23.
//

import SwiftUI

struct CacheAsyncImage<Content, Content2>: View where Content: View, Content2: View {
    private let url: URL?
    private let scale: CGFloat
    private let transaction: Transaction?
    private let contentPhase: ((AsyncImagePhase) -> Content)?
    private let contentImage: ((Image) -> Content)?
    private let placeholder: (() -> Content2)?

    init(url: URL?,
         scale: CGFloat = 1.0,
         transaction: Transaction = Transaction(),
         @ViewBuilder content: @escaping (AsyncImagePhase) -> Content)
    {
        self.url = url
        self.scale = scale
        self.transaction = transaction
        contentPhase = content
        contentImage = nil
        placeholder = nil
    }

    init(url: URL?,
         scale: CGFloat = 1,
         @ViewBuilder content: @escaping (Image) -> Content,
         @ViewBuilder placeholder: @escaping () -> Content2)
    {
        self.url = url
        self.scale = scale
        contentImage = content
        self.placeholder = placeholder
        contentPhase = nil
        transaction = nil
    }

    var body: some View {
        if let cached = ImageCache[url] {
            if contentPhase != nil {
                contentPhase?(.success(cached))
            } else if contentImage != nil {
                contentImage?(cached)
            }
        } else {
            if contentPhase != nil {
                AsyncImage(url: url,
                           scale: scale,
                           transaction: transaction ?? Transaction(),
                           content: { cacheAndRender(phase: $0) })
            } else if contentImage != nil && placeholder != nil {
                AsyncImage(url: url,
                           scale: scale,
                           content: { cacheAndRender(image: $0) },
                           placeholder: placeholder!)
            }
        }
    }

    private func cacheAndRender(image: Image) -> some View {
        ImageCache[url] = image
        return contentImage?(image)
    }

    private func cacheAndRender(phase: AsyncImagePhase) -> some View {
        if case let .success(image) = phase {
            ImageCache[url] = image
        }
        return contentPhase?(phase)
    }
}

private enum ImageCache {
    private static var cache: [URL: Image] = [:]
    static subscript(url: URL?) -> Image? {
        get {
            guard let url else { return nil }
            return ImageCache.cache[url]
        }
        set {
            guard let url else { return }
            ImageCache.cache[url] = newValue
        }
    }
}
