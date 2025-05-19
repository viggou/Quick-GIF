//
//  AnimatedGIFView.swift
//  Quick GIF
//
//  Created by Viggo Lekdorf on 16/05/2025.
//

import SwiftUI
import WebKit

struct AnimatedGIFView: NSViewRepresentable {
    let gifPath: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground") // make background transparent
        webView.translatesAutoresizingMaskIntoConstraints = false
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: gifPath)) else { return }
        let base64 = data.base64EncodedString()
        let html = """
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            html, body {
                margin: 0;
                padding: 0;
                background-color: transparent;
                height: 100%;
                display: flex;
                justify-content: center;
                align-items: center;
            }
            img {
                max-width: 100%;
                max-height: 100%;
                object-fit: contain;
            }
        </style>
        </head>
        <body>
            <img src="data:image/gif;base64,\(base64)">
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}
