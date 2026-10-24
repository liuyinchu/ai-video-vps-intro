import Foundation
import CryptoKit
import AppKit
import AVFoundation
import CoreGraphics
import CoreVideo
import ImageIO
import UniformTypeIdentifiers

// Shared with Scenes.swift. Time values are seconds from the beginning of the film.
struct Caption: Codable {
    let scene: Int
    let text: String
    let start: Double
    let duration: Double
}
struct SceneSpan: Codable {
    let id: Int
    let title: String
    let start: Double
    let duration: Double
}
struct Timeline: Codable {
    let captions: [Caption]
    let scenes: [SceneSpan]
    let duration: Double
}
struct ScriptLine: Codable { let text: String; let speech: String? }
struct ScriptScene: Codable { let id: Int; let title: String; let lines: [ScriptLine] }
struct Script: Codable { let scenes: [ScriptScene] }
struct AudioClip: Codable {
    let path: String
    let start: Double
    let duration: Double
    let speech: String
}
struct AudioPlan: Codable { let clips: [AudioClip] }

let width = 1920
let height = 1080
let frameRate: Int32 = 30
let fm = FileManager.default
let root = URL(fileURLWithPath: fm.currentDirectoryPath, isDirectory: true)

struct VideoError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
func fail(_ message: String) -> VideoError { VideoError(message: message) }
func url(_ path: String) -> URL {
    path.hasPrefix("/") ? URL(fileURLWithPath: path) : root.appendingPathComponent(path)
}
func mkdir(_ path: String) throws {
    try fm.createDirectory(at: url(path), withIntermediateDirectories: true)
}
func removeIfExists(_ file: URL) throws {
    if fm.fileExists(atPath: file.path) { try fm.removeItem(at: file) }
}
func saveJSON<T: Encodable>(_ value: T, _ path: String) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    try encoder.encode(value).write(to: url(path), options: .atomic)
}
func readJSON<T: Decodable>(_ type: T.Type, _ path: String) throws -> T {
    try JSONDecoder().decode(type, from: Data(contentsOf: url(path)))
}
func seconds(_ time: CMTime) -> Double { CMTimeGetSeconds(time) }
func mediaTime(_ value: Double) -> CMTime { CMTime(seconds: value, preferredTimescale: 60000) }
func log(_ message: String) { print(message); fflush(stdout) }

// AVFoundation completion handlers can be dispatched to the main queue. Pump it while waiting.
func waitForCompletion(_ finished: @escaping () -> Bool, timeout: Double = 7200) throws {
    let deadline = Date().addingTimeInterval(timeout)
    while !finished() {
        if Date() > deadline { throw fail("Timed out waiting for AVFoundation.") }
        RunLoop.current.run(until: Date().addingTimeInterval(0.025))
    }
}
final class CompletionFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    var done: Bool { lock.lock(); defer { lock.unlock() }; return value }
    func finish() { lock.lock(); value = true; lock.unlock() }
}

func srtTime(_ value: Double) -> String {
    let total = max(0, Int((value * 1000).rounded()))
    return String(format: "%02d:%02d:%02d,%03d", total / 3600000,
                  (total / 60000) % 60, (total / 1000) % 60, total % 1000)
}

enum NarrationEngine { case neural, system }
struct VoiceInfo: Codable {
    let name: String
    let voice: String
    let type: String
    let provider: String
    let rate: String
    let language: String
    let synthesisUnit: String
    let clipCount: Int
    let durationSeconds: Double
    let generatedAt: String
}
func validatedAudioDuration(_ path: String) throws -> Double {
    let asset = AVURLAsset(url: url(path))
    let duration = seconds(asset.duration)
    guard duration.isFinite && duration > 0, !asset.tracks(withMediaType: .audio).isEmpty else {
        throw fail("Speech audio is empty or invalid: \(path)")
    }
    return duration
}
func normalizedNeuralSpeech(_ text: String) -> String {
    var result = text
    for (pattern, replacement) in [("V\\s+P\\s+S", "VPS"), ("C\\s+P\\s+U", "CPU"), ("V\\s+P\\s+N", "VPN")] {
        result = result.replacingOccurrences(of: pattern, with: replacement, options: [.regularExpression, .caseInsensitive])
    }
    return result
}
func neuralCacheKey(text: String, voice: String, rate: String) throws -> String {
    let data = try JSONSerialization.data(withJSONObject: ["text": text, "voice": voice, "rate": rate], options: [.sortedKeys])
    return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}
func neuralClip(text: String, voice: String, rate: String) throws -> (path: String, duration: Double, cached: Bool) {
    let key = try neuralCacheKey(text: text, voice: voice, rate: rate)
    let path = "build/audio/neural/\(key).mp3"
    if fm.fileExists(atPath: url(path).path), let duration = try? validatedAudioDuration(path) {
        return (path, duration, true)
    }
    let executable = url("build/edge-voice")
    guard fm.isExecutableFile(atPath: executable.path) else {
        throw fail("Neural voice client is missing. Run ./build.sh build-voice first. No system-voice fallback is used.")
    }
    let temporaryStem = "build/audio/neural/.pending-\(UUID().uuidString)"
    let temporaryAudio = url(temporaryStem + ".mp3")
    let temporaryMetadata = url(temporaryStem + ".json")
    let temporaryLog = url(temporaryStem + ".log")
    defer {
        try? removeIfExists(temporaryAudio)
        try? removeIfExists(temporaryMetadata)
        try? removeIfExists(temporaryLog)
    }
    guard fm.createFile(atPath: temporaryLog.path, contents: nil) else { throw fail("Cannot create neural voice diagnostic log.") }
    let errorHandle = try FileHandle(forWritingTo: temporaryLog)
    defer { try? errorHandle.close() }
    let process = Process()
    process.executableURL = executable
    process.arguments = ["--text", text, "--output", temporaryAudio.path, "--voice", voice, "--rate=\(rate)", "--metadata", temporaryMetadata.path]
    process.standardError = errorHandle
    try process.run()
    process.waitUntilExit()
    try errorHandle.synchronize()
    let errorText = (try? String(contentsOf: temporaryLog, encoding: .utf8)) ?? ""
    guard process.terminationStatus == 0 else {
        throw fail("Neural speech synthesis failed (exit \(process.terminationStatus)): \(errorText). No system-voice fallback is used.")
    }
    let duration = try validatedAudioDuration(temporaryAudio.path)
    // Only promote a successfully decoded file; failed requests never poison the cache.
    try Data(contentsOf: temporaryAudio).write(to: url(path), options: .atomic)
    if fm.fileExists(atPath: temporaryMetadata.path) {
        try Data(contentsOf: temporaryMetadata).write(to: url("build/audio/neural/\(key).metadata.json"), options: .atomic)
    }
    return (path, duration, false)
}
func systemClip(text: String, voice: String, rate: String, index: Int) throws -> (path: String, duration: Double) {
    let path = String(format: "build/audio/%03d.aiff", index)
    try removeIfExists(url(path))
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
    process.arguments = ["-v", voice, "-r", rate, "-o", url(path).path, text]
    let errors = Pipe()
    process.standardError = errors
    try process.run()
    process.waitUntilExit()
    let errorText = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    guard process.terminationStatus == 0 else { throw fail("System speech synthesis failed: \(errorText)") }
    return (path, try validatedAudioDuration(path))
}
func synthesize(engine: NarrationEngine = .neural) throws {
    let script = try readJSON(Script.self, "script.json")
    guard !script.scenes.isEmpty else { throw fail("script.json has no scenes.") }
    guard Set(script.scenes.map { $0.id }).count == script.scenes.count else {
        throw fail("Scene IDs must be unique.")
    }
    try mkdir("build/audio/neural")
    try mkdir("output")
    var captions: [Caption] = []
    var spans: [SceneSpan] = []
    var clips: [AudioClip] = []
    var cursor = 0.0
    var clipIndex = 0
    let neural = engine == .neural
    let environment = ProcessInfo.processInfo.environment
    let rate = neural ? (environment["NEURAL_RATE"] ?? "-5%") : (environment["VOICE_RATE"] ?? "155")
    let voice = neural ? (environment["NEURAL_VOICE"] ?? "zh-CN-XiaoxiaoNeural") : (environment["VOICE_NAME"] ?? "Tingting")
    log("Narration voice: \(voice) · rate \(rate) · \(neural ? "Microsoft Edge Read Aloud" : "macOS say")")
    for (sceneIndex, scene) in script.scenes.enumerated() {
        guard !scene.lines.isEmpty else { throw fail("Scene \(scene.id) has no narration lines.") }
        let sceneStart = cursor
        if sceneIndex == 0 { cursor += neural ? 0.6 : 0.7 }
        for (lineIndex, line) in scene.lines.enumerated() {
            let rawSpeech = line.speech ?? line.text
            let spoken = neural ? normalizedNeuralSpeech(rawSpeech) : rawSpeech
            guard !spoken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw fail("Empty narration in scene \(scene.id).")
            }
            let path: String
            let duration: Double
            let cached: Bool
            if neural {
                let clip = try neuralClip(text: spoken, voice: voice, rate: rate)
                path = clip.path
                duration = clip.duration
                cached = clip.cached
            } else {
                let clip = try systemClip(text: spoken, voice: voice, rate: rate, index: clipIndex)
                path = clip.path
                duration = clip.duration
                cached = false
            }
            let lastLine = lineIndex == scene.lines.count - 1
            let lastScene = sceneIndex == script.scenes.count - 1
            let pause = lastLine ? (lastScene ? 1.2 : (neural ? 0.35 : 0.4)) : (neural ? 0.12 : 0.14)
            captions.append(Caption(scene: scene.id, text: line.text, start: cursor, duration: duration + pause))
            clips.append(AudioClip(path: path, start: cursor, duration: duration, speech: spoken))
            log(String(format: "Voice %02d · scene %d · %.2fs%@ · %@", clipIndex + 1, scene.id, duration, cached ? " · cached" : "", line.text))
            cursor += duration + pause
            clipIndex += 1
        }
        spans.append(SceneSpan(id: scene.id, title: scene.title, start: sceneStart, duration: cursor - sceneStart))
    }
    let timeline = Timeline(captions: captions, scenes: spans, duration: cursor)
    try saveJSON(timeline, "build/timeline.json")
    try saveJSON(AudioPlan(clips: clips), "build/audio-plan.json")
    let srt = captions.enumerated().map { index, caption in
        "\(index + 1)\n\(srtTime(caption.start)) --> \(srtTime(caption.start + caption.duration))\n\(caption.text)\n"
    }.joined(separator: "\n")
    try srt.write(to: url("output/vps-explained.zh-CN.srt"), atomically: true, encoding: .utf8)
    let info = VoiceInfo(name: neural ? (voice == "zh-CN-XiaoxiaoNeural" ? "微软晓晓" : voice) : voice,
                         voice: voice, type: neural ? "neural" : "system",
                         provider: neural ? "Microsoft Edge Read Aloud" : "macOS say", rate: rate,
                         language: "zh-CN", synthesisUnit: "sentence", clipCount: clips.count,
                         durationSeconds: cursor, generatedAt: ISO8601DateFormatter().string(from: Date()))
    try saveJSON(info, "output/voice.json")
    log(String(format: "Narration ready: %d scenes, %d captions, %.2f seconds.", spans.count, captions.count, cursor))
}

func renderContext(_ ctx: CGContext, time: Double, timeline: Timeline) {
    let oldContext = NSGraphicsContext.current
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    drawFrame(ctx, time: time, timeline: timeline)
    NSGraphicsContext.current = oldContext
}
func createContext() throws -> CGContext {
    guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                              bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else {
        throw fail("Cannot create a 1920×1080 drawing context.")
    }
    return ctx
}
func savePNG(_ image: CGImage, to output: URL) throws {
    try fm.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw fail("Cannot open PNG destination: \(output.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw fail("Cannot save PNG: \(output.path)") }
}
func preview(_ time: Double, _ path: String) throws {
    let timeline = try readJSON(Timeline.self, "build/timeline.json")
    let ctx = try createContext()
    renderContext(ctx, time: min(max(time, 0), max(0, timeline.duration - 1.0 / Double(frameRate))), timeline: timeline)
    guard let image = ctx.makeImage() else { throw fail("Cannot create preview image.") }
    try savePNG(image, to: url(path))
    log("Preview saved: \(path)")
}

func renderSilent(_ timeline: Timeline) throws -> URL {
    let output = url("build/video-silent.mp4")
    try removeIfExists(output)
    let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
    let compression: [String: Any] = [
        AVVideoAverageBitRateKey: 7_000_000,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        AVVideoExpectedSourceFrameRateKey: frameRate,
        AVVideoMaxKeyFrameIntervalKey: frameRate * 2
    ]
    let settings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height,
        AVVideoCompressionPropertiesKey: compression
    ]
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
    input.expectsMediaDataInRealTime = false
    let attributes: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
        kCVPixelBufferCGImageCompatibilityKey as String: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
    ]
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attributes)
    guard writer.canAdd(input) else { throw fail("Cannot add H.264 video track.") }
    writer.add(input)
    guard writer.startWriting() else { throw fail("Cannot start video writer: \(writer.error?.localizedDescription ?? "unknown error")") }
    writer.startSession(atSourceTime: .zero)
    guard let pool = adaptor.pixelBufferPool else { throw fail("Video pixel buffer pool is unavailable.") }
    let frameCount = Int(ceil(timeline.duration * Double(frameRate)))
    var lastProgress = -1
    let started = Date()
    for frame in 0..<frameCount {
        while !input.isReadyForMoreMediaData {
            if writer.status == .failed { throw fail("Video writer failed: \(writer.error?.localizedDescription ?? "unknown error")") }
            RunLoop.current.run(until: Date().addingTimeInterval(0.002))
        }
        try autoreleasepool {
            var pixelBuffer: CVPixelBuffer?
            let result = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
            guard result == kCVReturnSuccess, let buffer = pixelBuffer else { throw fail("Cannot allocate video frame (\(result)).") }
            CVPixelBufferLockBaseAddress(buffer, [])
            defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
            guard let base = CVPixelBufferGetBaseAddress(buffer),
                  let ctx = CGContext(data: base, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else {
                throw fail("Cannot create frame drawing context.")
            }
            renderContext(ctx, time: Double(frame) / Double(frameRate), timeline: timeline)
            guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: frameRate)) else {
                throw fail("Cannot append frame \(frame): \(writer.error?.localizedDescription ?? "unknown error")")
            }
        }
        let progress = frame * 100 / frameCount
        if progress / 5 != lastProgress / 5 || frame == 0 {
            log(String(format: "Rendering %3d%% · frame %d/%d · %.1fs elapsed", progress, frame + 1, frameCount, Date().timeIntervalSince(started)))
            lastProgress = progress
        }
    }
    writer.endSession(atSourceTime: CMTime(value: Int64(frameCount), timescale: frameRate))
    input.markAsFinished()
    let flag = CompletionFlag()
    writer.finishWriting { flag.finish() }
    try waitForCompletion { flag.done }
    guard writer.status == .completed else { throw fail("Video encoding failed: \(writer.error?.localizedDescription ?? "unknown error")") }
    log(String(format: "Silent video encoded in %.1f seconds.", Date().timeIntervalSince(started)))
    return output
}

func combineAudio(silent: URL, timeline: Timeline) throws {
    let plan = try readJSON(AudioPlan.self, "build/audio-plan.json")
    let video = AVURLAsset(url: silent)
    guard let sourceVideo = video.tracks(withMediaType: .video).first else { throw fail("Silent video has no video track.") }
    let composition = AVMutableComposition()
    guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
          let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
        throw fail("Cannot create final audio/video tracks.")
    }
    try videoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: video.duration), of: sourceVideo, at: .zero)
    videoTrack.preferredTransform = sourceVideo.preferredTransform
    for clip in plan.clips {
        let audio = AVURLAsset(url: url(clip.path))
        guard let sourceAudio = audio.tracks(withMediaType: .audio).first else { throw fail("Audio track missing: \(clip.path)") }
        try audioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: audio.duration), of: sourceAudio, at: mediaTime(clip.start))
    }
    let output = url("output/vps-explained.mp4")
    try removeIfExists(output)
    guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
        throw fail("Cannot create final MP4 exporter.")
    }
    exporter.outputURL = output
    exporter.outputFileType = .mp4
    exporter.shouldOptimizeForNetworkUse = true
    exporter.timeRange = CMTimeRange(start: .zero, duration: video.duration)
    log("Combining narration and video…")
    let flag = CompletionFlag()
    exporter.exportAsynchronously { flag.finish() }
    try waitForCompletion { flag.done }
    guard exporter.status == .completed else { throw fail("Final MP4 export failed: \(exporter.error?.localizedDescription ?? "unknown error")") }
    log("Final video saved: output/vps-explained.mp4")
}

func render() throws {
    let timeline = try readJSON(Timeline.self, "build/timeline.json")
    guard timeline.duration.isFinite && timeline.duration > 0 else { throw fail("Timeline has an invalid duration.") }
    try mkdir("output")
    let silent = try renderSilent(timeline)
    try combineAudio(silent: silent, timeline: timeline)
}
struct AudioLevels {
    let rms: Double
    let peak: Double
    let sampleCount: Int
}
func decodedAudioLevels(asset: AVAsset, track: AVAssetTrack) throws -> AudioLevels {
    let reader = try AVAssetReader(asset: asset)
    let settings: [String: Any] = [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVLinearPCMBitDepthKey: 32,
        AVLinearPCMIsFloatKey: true,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsNonInterleaved: false
    ]
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
    output.alwaysCopiesSampleData = false
    guard reader.canAdd(output) else { throw fail("Cannot configure audio sample verification.") }
    reader.add(output)
    guard reader.startReading() else { throw fail("Cannot decode final narration: \(reader.error?.localizedDescription ?? "unknown error")") }
    var sumSquares = 0.0
    var peak = 0.0
    var count = 0
    while let buffer = output.copyNextSampleBuffer() {
        try autoreleasepool {
            guard let block = CMSampleBufferGetDataBuffer(buffer) else { throw fail("Decoded narration contains no PCM data.") }
            let length = CMBlockBufferGetDataLength(block)
            guard length > 0, length % MemoryLayout<Float>.size == 0 else { throw fail("Unexpected decoded narration sample format.") }
            var samples = [Float](repeating: 0, count: length / MemoryLayout<Float>.size)
            let status = samples.withUnsafeMutableBytes { pointer in
                CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: pointer.baseAddress!)
            }
            guard status == kCMBlockBufferNoErr else { throw fail("Cannot read decoded narration samples (\(status)).") }
            for sample in samples {
                let value = Double(sample)
                guard value.isFinite else { throw fail("Non-finite sample in final narration.") }
                sumSquares += value * value
                peak = max(peak, abs(value))
            }
            count += samples.count
        }
    }
    guard reader.status == .completed else { throw fail("Narration decoding failed: \(reader.error?.localizedDescription ?? "unknown error")") }
    guard count > 0 else { throw fail("Final narration has no audio samples.") }
    let rms = sqrt(sumSquares / Double(count))
    guard rms > 0.00001, peak > 0.0001 else { throw fail("Final narration is silent (RMS \(rms), peak \(peak)).") }
    return AudioLevels(rms: rms, peak: peak, sampleCount: count)
}
func codecName(_ track: AVAssetTrack) -> String {
    guard let description = track.formatDescriptions.first else { return "unknown" }
    let code = CMFormatDescriptionGetMediaSubType(description as! CMFormatDescription)
    let bytes: [UInt8] = [UInt8((code >> 24) & 255), UInt8((code >> 16) & 255), UInt8((code >> 8) & 255), UInt8(code & 255)]
    return String(bytes: bytes, encoding: .ascii) ?? "unknown"
}

func verify() throws {
    let path = "output/vps-explained.mp4"
    let asset = AVURLAsset(url: url(path))
    let timeline = try readJSON(Timeline.self, "build/timeline.json")
    guard let video = asset.tracks(withMediaType: .video).first else { throw fail("Verification failed: no video track.") }
    guard let audio = asset.tracks(withMediaType: .audio).first else { throw fail("Verification failed: no audio track.") }
    let duration = seconds(asset.duration)
    let size = video.naturalSize.applying(video.preferredTransform)
    guard abs(abs(size.width) - Double(width)) < 1, abs(abs(size.height) - Double(height)) < 1 else {
        throw fail("Verification failed: unexpected video dimensions \(size).")
    }
    guard abs(duration - timeline.duration) <= 0.1 else {
        throw fail("Verification failed: duration \(duration) differs from timeline \(timeline.duration).")
    }
    guard audio.estimatedDataRate > 0, video.nominalFrameRate > 0 else { throw fail("Verification failed: empty audio or video.") }
    let levels = try decodedAudioLevels(asset: asset, track: audio)
    log(String(format: "Decoded narration: RMS %.5f, peak %.5f, %d samples.", levels.rms, levels.peak, levels.sampleCount))
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: frameRate)
    generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: frameRate)
    try mkdir("output/frames")
    for scene in timeline.scenes {
        try autoreleasepool {
            let image = try generator.copyCGImage(at: mediaTime(scene.start + scene.duration * 0.5), actualTime: nil)
            try savePNG(image, to: url(String(format: "output/frames/scene-%02d.png", scene.id)))
        }
    }
    let attrs = try fm.attributesOfItem(atPath: url(path).path)
    let byteCount = (attrs[.size] as? NSNumber)?.int64Value ?? 0
    let result: [String: Any] = [
        "file": path, "durationSeconds": duration, "timelineSeconds": timeline.duration,
        "width": Int(abs(size.width)), "height": Int(abs(size.height)),
        "framesPerSecond": video.nominalFrameRate, "hasAudio": true,
        "audioDataRate": audio.estimatedDataRate, "bytes": byteCount,
        "audioRMS": levels.rms, "audioPeak": levels.peak, "decodedAudioSampleCount": levels.sampleCount,
        "videoCodec": codecName(video), "audioCodec": codecName(audio),
        "sceneCount": timeline.scenes.count, "captionCount": timeline.captions.count,
        "verifiedAt": ISO8601DateFormatter().string(from: Date())
    ]
    let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: url("output/verification.json"), options: .atomic)
    log(String(format: "Verified: 1920×1080 · %.0f fps · %.2fs · narration present · %.1f MB · %d scene previews", video.nominalFrameRate, duration, Double(byteCount) / 1_000_000, timeline.scenes.count))
}

func usage() {
    print("""
    VPS explainer video maker (macOS, no third-party dependencies)
    Usage:
      build/make-video synthesize          # Microsoft Xiaoxiao neural narration
      build/make-video synthesize-system   # Explicit legacy macOS voice
      build/make-video render
      build/make-video mux
      build/make-video preview <seconds> <output.png>
      build/make-video verify
    Neural environment: NEURAL_RATE=-5% NEURAL_VOICE=zh-CN-XiaoxiaoNeural
    System environment: VOICE_RATE=155 VOICE_NAME=Tingting
    Run from the repository root, or use ./build.sh <command>.
    """)
}
do {
    let args = Array(CommandLine.arguments.dropFirst())
    guard let command = args.first else { usage(); exit(0) }
    switch command {
    case "synthesize": try synthesize()
    case "synthesize-system": try synthesize(engine: .system)
    case "render": try render()
    case "mux":
        let timeline = try readJSON(Timeline.self, "build/timeline.json")
        try combineAudio(silent: url("build/video-silent.mp4"), timeline: timeline)
    case "preview":
        guard args.count == 3, let time = Double(args[1]), time.isFinite else { throw fail("Usage: preview <seconds> <output.png>") }
        try preview(time, args[2])
    case "verify": try verify()
    case "help", "--help", "-h": usage()
    default: throw fail("Unknown command: \(command)")
    }
} catch {
    fputs("Error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
