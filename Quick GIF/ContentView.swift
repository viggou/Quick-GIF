//
//  ContentView.swift
//  Quick GIF
//
//  Created by Viggo Lekdorf on 15/05/2025.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WebKit
import Combine

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

struct ContentView: View {
    @State private var selectedPaths: [String] = []
    @State private var framerate: String = "10"
    @State private var resolution: String = "640"
    @State private var status: String = ""
    @State private var gifPreviewPath: String?
    @State private var outputPath: String = (NSTemporaryDirectory() as NSString).appendingPathComponent("output.gif")
    @State private var importedCount: Int = 0
    @State private var isInProgress: Bool = false
    @State private var progress: Double = 0.0
    
    let allowedExtensions = [
        "png", "jpg", "jpeg", "bmp", "tiff", "tif", "gif", "webp", "pbm", "pgm", "ppm", "tga", "sgi", "jp2", "j2k", "jpf", "jpx", "j2c", "icns", "heic", "heif"
    ]
    
    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            VStack(spacing: 10) {
                Text("Quick GIF").font(.title).padding(.top)
                Text("Quickly generate a GIF using ffmpeg")
            }
            
            VStack(spacing: 20) {
                Button("Select images or folder") {
                    selectFiles()
                }
                
                Text("\(importedCount) file(s) imported")
                
                HStack {
                    Text("Framerate:")
                    TextField("10", text: $framerate)
                        .frame(width: 60)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onReceive(Just(framerate)) { newValue in
                            let filtered = newValue.filter { ("0"..."9").contains($0) }
                            if filtered != newValue {
                                self.framerate = String(filtered)
                            }
                        }
                }
                
                HStack {
                    Text("Resolution (width):")
                    TextField("640", text: $resolution)
                        .frame(width: 60)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onReceive(Just(resolution)) { newValue in
                            let filtered = newValue.filter { ("0"..."9").contains($0) }
                            if filtered != newValue {
                                self.resolution = String(filtered)
                            }
                        }
                }
                
                Button("Generate GIF") {
                    generateGIF()
                }
                .disabled(selectedPaths.isEmpty)
                
                if isInProgress {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(width: 200)
                }
                
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .padding(.top, 5)
                
                if let gifPath = gifPreviewPath {
                    VStack(spacing: 10) {
                        Text("Preview:")
                        
                        AnimatedGIFView(gifPath: gifPath)
                            .frame(width: 360, height: 360)
                            .cornerRadius(8)
                        
                        Button("Export") {
                            exportFile()
                        }
                    }
                }
            }
            .padding(10)
            .frame(width: 400)
            Spacer()
        }
    }
    
    func detectMajorityFileFormat(from paths: [String]) -> String? {
        let extensions = paths.compactMap { URL(fileURLWithPath: $0).pathExtension.lowercased() }
        let countedSet = NSCountedSet(array: extensions)
        let majority = countedSet.max { countedSet.count(for: $0) < countedSet.count(for: $1) }
        return majority as? String
    }
    
    func updateImportedCountFromSelection() {
        importedCount = 0
        
        if selectedPaths.count == 1 {
            let url = URL(fileURLWithPath: selectedPaths[0])
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path(), isDirectory: &isDir), isDir.boolValue {
                if let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
                    let images = contents.filter { allowedExtensions.contains($0.pathExtension.lowercased()) }
                    importedCount = images.count
                    return
                }
            }
        }
        // fallback if individual files are selected
        importedCount = selectedPaths.filter {
            allowedExtensions.contains(URL(fileURLWithPath: $0).pathExtension.lowercased())
        }.count
    }
    
    func selectFiles() {
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = true
            panel.canChooseDirectories = true
            panel.canChooseFiles = true
            panel.allowedContentTypes = [.image]
            
            if panel.runModal() == .OK {
                selectedPaths = panel.urls.map { $0.path }
                updateImportedCountFromSelection()
            }
        }
    }
    
    func generateGIF() {
        guard !selectedPaths.isEmpty else {
            status = "No files selected"
            return
        }
        
        outputPath = (NSTemporaryDirectory() as NSString).appendingPathComponent("output_\(UUID().uuidString).gif")
        var filesToAnalyze = selectedPaths
        importedCount = 0
        var isDir: ObjCBool = false
        
        // if folder, check files inside
        if selectedPaths.count == 1 {
            let url = URL(fileURLWithPath: selectedPaths[0])
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                if let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
                    filesToAnalyze = contents
                        .filter { allowedExtensions.contains($0.pathExtension.lowercased()) }
                        .map { $0.path }
                    importedCount = filesToAnalyze.count
                }
            }
        }
        else {
            filesToAnalyze = selectedPaths.filter { allowedExtensions.contains(URL(fileURLWithPath: $0).pathExtension.lowercased()) }
            importedCount = filesToAnalyze.count
        }
        
        let uniqueExts = Set(filesToAnalyze.map { URL(fileURLWithPath: $0).pathExtension.lowercased() })
        let majorityExt = detectMajorityFileFormat(from: filesToAnalyze) ?? "png"
        
        // treat file formats with multiple extensions the same
        let fileTypeGroup: [String]
        if majorityExt == "jpg" || majorityExt == "jpeg" {
            fileTypeGroup = ["jpg", "jpeg"]
        }
        else if majorityExt == "tif" || majorityExt == "tiff" {
            fileTypeGroup = ["tif", "tiff"]
        }
        else {
            fileTypeGroup = [majorityExt]
        }
        
        let inputFiles = filesToAnalyze.filter {
            fileTypeGroup.contains(URL(fileURLWithPath: $0).pathExtension.lowercased())
        }
        
        // copy images to temp directory
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ffmpeg_input")
        try? FileManager.default.removeItem(at: tempDir)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        for (index, path) in inputFiles.enumerated() {
            let source = URL(fileURLWithPath: path)
            let dest = tempDir.appendingPathComponent(String(format: "img%03d.%@", index, majorityExt))
            do {
                try FileManager.default.copyItem(at: source, to: dest)
            } catch {
                print("Error copying \(source) to \(dest): \(error)")
            }
        }
        
        if uniqueExts.count > 1 {
            status = "Warning: Mixed image formats detected. Using: \(majorityExt)"
            print("Warning: Mixed image formats detected. Using: \(majorityExt)")
        }
        
        guard !majorityExt.isEmpty else {
            status = "Error: could not determine file format"
            return
        }
        print("Using file format: \(majorityExt)")
        
        let inputImages = "\(tempDir.path)/img%03d.\(majorityExt)"
        
        guard let ffmpegPath = Bundle.main.path(forResource: "ffmpeg", ofType: "") else {
            status = "ffmpeg binary not found in bundle."
            return
        }
        
        guard let _ = Int(framerate), let _ = Int(resolution) else {
            status = "Invalid framerate or resolution"
            return
        }
        
        let args = [
            "-y", // always overwrite
            "-framerate", framerate,
            "-i", inputImages,
            "-vf", "scale=w='if(gt(a,1),\(resolution),-2)':h='if(gt(a,1),-2,\(resolution))':force_original_aspect_ratio=decrease,pad=\(resolution):\(resolution):(ow-iw)/2:(oh-ih)/2:color=0x00000000",
            "-loop", "0",
            outputPath
        ]
        
        let task = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        task.launchPath = ffmpegPath
        task.arguments = args
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let text = String(data: data, encoding: .utf8) {
                print("[stdout] \(text)")
            }
            if data.isEmpty {
                handle.readabilityHandler = nil
                try? handle.close()
            }
        }
        
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let text = String(data: data, encoding: .utf8) {
                print("[stderr] \(text)")
            }
            if data.isEmpty {
                handle.readabilityHandler = nil
                try? handle.close()
            }
        }
        
        task.terminationHandler = { process in
            DispatchQueue.main.async {
                isInProgress = false
                progress = 1.0
                if process.terminationStatus == 0 {
                    status = "GIF created at \(outputPath)"
                    gifPreviewPath = outputPath
                    print("Finished.")
                }
                else {
                    status = "ffmpeg failed with exit code \(process.terminationStatus)."
                    print("Error: ffmpeg failed with exit code \(process.terminationStatus).")
                }
            }
        }
        
        guard !isInProgress else {
            status = "Already generating. Please wait."
            return
        }
        guard framerate != "0" else {
            status = "Framerate cannot be zero."
            return
        }
        guard resolution != "0" else {
            status = "Resolution cannot be zero."
            return
        }
        
        do {
            isInProgress = true
            progress = 0.0
            
            let steps = max(importedCount, 10)
            let delay = min(0.1, 3.0 / Double(steps))
            
            DispatchQueue.global(qos: .background).async {
                for i in 0...steps {
                    Thread.sleep(forTimeInterval: delay)
                    DispatchQueue.main.async {
                        progress = Double(i) / Double(steps)
                    }
                }
            }
            
            print("Running ffmpeg with args:")
            print(args.joined(separator: " "))
            for arg in args {
                print("ARG: \(arg)")
            }
            
            if FileManager.default.fileExists(atPath: outputPath) {
                try? FileManager.default.removeItem(atPath: outputPath)
            }
            
            try task.run()
        }
        catch {
            status = "Failed to run ffmpeg: \(error.localizedDescription)"
            isInProgress = false
        }
    }
    
    func exportFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.gif]
        panel.nameFieldStringValue = "output.gif"
        
        guard panel.runModal() == .OK, let exportURL = panel.url else {
            status = "Export cancelled"
            return
        }
        
        do {
            if FileManager.default.fileExists(atPath: exportURL.path) {
                try FileManager.default.removeItem(at: exportURL)
            }
            try FileManager.default.copyItem(atPath: outputPath, toPath: exportURL.path)
            status = "GIF exported to \(exportURL.path)"
        }
        catch {
            status = "Failed to export GIF: \(error.localizedDescription)"
            print("Failed to export GIF: \(error.localizedDescription)")
        }
    }
}

#Preview {
    ContentView()
}
