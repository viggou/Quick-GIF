//
//  GIFGenerator.swift
//  Quick GIF
//
//  Created by Viggo Lekdorf on 16/05/2025.
//

import Foundation
import AppKit

struct GIFGenerator {
    static func detectMajorityFileFormat(from paths: [String]) -> String? {
        let extensions = paths.compactMap { URL(fileURLWithPath: $0).pathExtension.lowercased() }
        let countedSet = NSCountedSet(array: extensions)
        //let majority = countedSet.max { countedSet.count(for: $0) < countedSet.count(for: $1) }
        //return majority as? String
        return countedSet.max { countedSet.count(for: $0) < countedSet.count(for: $1) } as? String
    }
    
    static func prepareFiles(from selectedPaths: [String], allowedExtensions: [String]) -> (inputFiles: [String], majorityExt: String?, importedCount: Int) {
        var filesToAnalyse = selectedPaths
        var importedCount = 0
        var isDir: ObjCBool = false
        
        // if folder, check files inside
        if selectedPaths.count == 1 {
            let basePath = selectedPaths[0]
            if FileManager.default.fileExists(atPath: basePath, isDirectory: &isDir), isDir.boolValue, let contents = try? FileManager.default.contentsOfDirectory(atPath: basePath) {
                filesToAnalyse = contents.map { URL(fileURLWithPath: basePath).appendingPathComponent($0).path }
            }
        }
        
        filesToAnalyse = filesToAnalyse.filter {
            allowedExtensions.contains(URL(fileURLWithPath: $0).pathExtension.lowercased())
        }
        
        importedCount = filesToAnalyse.count
        let majorityExt = detectMajorityFileFormat(from: filesToAnalyse)
        
        return (filesToAnalyse, majorityExt, importedCount)
    }
    
    static func copyFilesToTempDir(
        files: [String],
        fileExtension: String
    ) -> URL? {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ffmpeg_input")
        try? FileManager.default.removeItem(at: tempDir)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        for (index, path) in files.enumerated() {
            let source = URL(fileURLWithPath: path)
            let dest = tempDir.appendingPathComponent(String(format: "img%03d.%@", index, fileExtension))
            do {
                try FileManager.default.copyItem(at: source, to: dest)
            }
            catch {
                print("Error copying \(source) to \(dest): \(error)")
                return nil
            }
        }
        
        return tempDir
    }
    
    static func runFFmpeg(
        ffmpegPath: String,
        inputPathPattern: String,
        framerate: String,
        resolution: String,
        outputPath: String,
        onStatusUpdate: @escaping (String) -> Void,
        onCompletion: @escaping (Bool) -> Void
    ) {
        let args = [
            "-y",
            "-framerate", framerate,
            "-i", inputPathPattern,
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
            if let text = String(data: handle.availableData, encoding: .utf8), !text.isEmpty {
                print("[stdout] \(text)")
            }
        }
        
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            if let text = String(data: handle.availableData, encoding: .utf8), !text.isEmpty {
                print("[stderr] \(text)")
            }
        }
        
        task.terminationHandler = { process in
            DispatchQueue.main.async {
                let success = process.terminationStatus == 0
                onCompletion(success)
                onStatusUpdate(success ? "GIF created at \(outputPath)" : "ffmpeg failed with code \(process.terminationStatus)")
            }
        }
        
        do {
            if FileManager.default.fileExists(atPath: outputPath) {
                try FileManager.default.removeItem(atPath: outputPath)
            }
            try task.run()
        }
        catch {
            onStatusUpdate("Error running ffmpeg: \(error.localizedDescription)")
            onCompletion(false)
        }
    }
}
