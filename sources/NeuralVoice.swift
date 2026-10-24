import Foundation

// Wire format follows the public edge-tts client:
// https://github.com/rany2/edge-tts (LGPL-3.0); protocol reference, not a bundled dependency.
// Uses the same public Read Aloud service and does not retry an access denial.

struct VoiceFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
struct VoiceArguments {
    var text = ""
    var output = ""
    var metadata: String?
    var voice = "zh-CN-XiaoxiaoNeural"
    var rate = "-5%"
    init(_ args: [String]) throws {
        var i = 0
        while i < args.count {
            let arg = args[i]
            if arg.hasPrefix("--rate=") { rate = String(arg.dropFirst(7)); i += 1; continue }
            guard i+1 < args.count else { throw VoiceFailure(message:"Missing value for \(arg)") }
            let value = args[i+1]
            switch arg {
            case "--text": text = value
            case "--output": output = value
            case "--voice": voice = value
            case "--rate": rate = value
            case "--metadata": metadata = value
            default: throw VoiceFailure(message:"Unknown option \(arg)")
            }
            i += 2
        }
        guard !text.isEmpty, !output.isEmpty else {
            throw VoiceFailure(message:"Usage: edge-voice --text TEXT --output FILE.mp3 --voice zh-CN-XiaoxiaoNeural --rate=-5% [--metadata FILE.json]")
        }
        guard text.utf8.count < 4096 else { throw VoiceFailure(message:"Please keep each narration segment under 4096 UTF-8 bytes.") }
        guard voice.range(of:"^[a-z]{2}-[A-Z]{2}-[A-Za-z0-9]+Neural$",options:.regularExpression) != nil else {
            throw VoiceFailure(message:"Unsupported voice name format.")
        }
        guard rate.range(of:"^[+-][0-9]+%$",options:.regularExpression) != nil else {
            throw VoiceFailure(message:"Speech rate must look like -5% or +0%.")
        }
    }
}
func xmlEscape(_ value: String) -> String {
    value.replacingOccurrences(of:"&",with:"&amp;").replacingOccurrences(of:"<",with:"&lt;")
        .replacingOccurrences(of:">",with:"&gt;").replacingOccurrences(of:"\"",with:"&quot;")
        .replacingOccurrences(of:"'",with:"&apos;")
}
func timestamp() -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier:"en_US_POSIX")
    f.timeZone = TimeZone(secondsFromGMT:0)
    f.dateFormat = "EEE MMM dd yyyy HH:mm:ss 'GMT+0000 (Coordinated Universal Time)'"
    return f.string(from:Date())
}
func requestID() -> String { UUID().uuidString.replacingOccurrences(of:"-",with:"").lowercased() }
func parseHeaders(_ string: String) -> [String:String] {
    var result: [String:String] = [:]
    for row in string.components(separatedBy:"\r\n") {
        guard let colon = row.firstIndex(of:":") else { continue }
        result[String(row[..<colon]).lowercased()] = String(row[row.index(after:colon)...]).trimmingCharacters(in:.whitespacesAndNewlines)
    }
    return result
}

func synthesizeNeural(_ arguments: VoiceArguments) async throws {
    let token = "6A5AA1D4EAFF4E9FB37E23D68491D6F4"
    let connection = requestID()
    var components = URLComponents(string:"wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1")!
    components.queryItems = [
        URLQueryItem(name:"TrustedClientToken",value:token),
        URLQueryItem(name:"ConnectionId",value:connection),
        URLQueryItem(name:"Sec-MS-GEC",value:edgeToken(timestamp:Date().timeIntervalSince1970)),
        URLQueryItem(name:"Sec-MS-GEC-Version",value:"2-143.0.3650.75")
    ]
    var request = URLRequest(url:components.url!)
    request.timeoutInterval = 25
    request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0",forHTTPHeaderField:"User-Agent")
    request.setValue("chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold",forHTTPHeaderField:"Origin")
    request.setValue("no-cache",forHTTPHeaderField:"Cache-Control")
    request.setValue("no-cache",forHTTPHeaderField:"Pragma")
    request.setValue("en-US,en;q=0.9",forHTTPHeaderField:"Accept-Language")
    request.setValue("muid=\(requestID().uppercased());",forHTTPHeaderField:"Cookie")
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 25
    configuration.timeoutIntervalForResource = 60
    let session = URLSession(configuration:configuration)
    let socket = session.webSocketTask(with:request)
    let deadline = DispatchWorkItem { socket.cancel(with:.goingAway,reason:nil) }
    DispatchQueue.global().asyncAfter(deadline:.now()+60,execute:deadline)
    defer {
        deadline.cancel()
        socket.cancel(with:.normalClosure,reason:nil)
        session.invalidateAndCancel()
    }
    socket.resume()
    let configBody = #"{"context":{"synthesis":{"audio":{"metadataoptions":{"sentenceBoundaryEnabled":"true","wordBoundaryEnabled":"false"},"outputFormat":"audio-24khz-48kbitrate-mono-mp3"}}}}"#
    let config = "X-Timestamp:\(timestamp())\r\nContent-Type:application/json; charset=utf-8\r\nPath:speech.config\r\n\r\n\(configBody)\r\n"
    let parts = arguments.voice.split(separator:"-",maxSplits:2)
    let longVoice = "Microsoft Server Speech Text to Speech Voice (\(parts[0])-\(parts[1]), \(parts[2]))"
    let ssml = "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='en-US'><voice name='\(xmlEscape(longVoice))'><prosody pitch='+0Hz' rate='\(arguments.rate)' volume='+0%'>\(xmlEscape(arguments.text))</prosody></voice></speak>"
    let command = "X-RequestId:\(requestID())\r\nContent-Type:application/ssml+xml\r\nX-Timestamp:\(timestamp())Z\r\nPath:ssml\r\n\r\n\(ssml)"
    var audio = Data()
    var metadata: [[String:Any]] = []
    var completed = false
    do {
        try await socket.send(.string(config))
        try await socket.send(.string(command))
        while !completed {
            let message = try await socket.receive()
            switch message {
            case .string(let data):
                let sections = data.components(separatedBy:"\r\n\r\n")
                let headers = parseHeaders(sections.first ?? "")
                let path = headers["path"] ?? ""
                if path == "turn.end" { completed = true }
                else if path == "audio.metadata", sections.count > 1,
                        let jsonData = sections.dropFirst().joined(separator:"\r\n\r\n").data(using:.utf8),
                        let json = try JSONSerialization.jsonObject(with:jsonData) as? [String:Any],
                        let entries = json["Metadata"] as? [[String:Any]] { metadata.append(contentsOf:entries) }
                else if !["turn.start","response"].contains(path) {
                    throw VoiceFailure(message:"Unexpected speech message: \(path)")
                }
            case .data(let data):
                guard data.count >= 2 else { throw VoiceFailure(message:"Invalid binary speech frame.") }
                let bytes = [UInt8](data.prefix(2))
                let headerLength = Int(bytes[0])*256+Int(bytes[1])
                guard data.count >= 2+headerLength else { throw VoiceFailure(message:"Truncated speech frame.") }
                let headers = parseHeaders(String(data:data.subdata(in:2..<(2+headerLength)),encoding:.utf8) ?? "")
                guard headers["path"] == "audio" else { throw VoiceFailure(message:"Unexpected binary speech message.") }
                let contentType = headers["content-type"]
                guard contentType == nil || contentType == "audio/mpeg" else { throw VoiceFailure(message:"Unexpected audio content type.") }
                audio.append(data.subdata(in:(2+headerLength)..<data.count))
            @unknown default: throw VoiceFailure(message:"Unknown WebSocket message.")
            }
        }
    } catch {
        let status = (socket.response as? HTTPURLResponse)?.statusCode
        let suffix = status.map { " (HTTP \($0))" } ?? ""
        throw VoiceFailure(message:"Read Aloud synthesis failed\(suffix): \(error.localizedDescription)")
    }
    guard completed, audio.count > 1000 else { throw VoiceFailure(message:"Speech service returned no complete audio.") }
    let output = URL(fileURLWithPath:arguments.output)
    try FileManager.default.createDirectory(at:output.deletingLastPathComponent(),withIntermediateDirectories:true)
    try audio.write(to:output,options:.atomic)
    if let path = arguments.metadata {
        let record: [String:Any] = ["voice":arguments.voice,"rate":arguments.rate,"text":arguments.text,"metadata":metadata,"audioBytes":audio.count]
        let json = try JSONSerialization.data(withJSONObject:record,options:[.prettyPrinted,.sortedKeys])
        try json.write(to:URL(fileURLWithPath:path),options:.atomic)
    }
    print("Generated \(arguments.voice): \(audio.count) bytes → \(arguments.output)")
}

@main struct NeuralVoiceCLI {
    static func main() async {
        do { try await synthesizeNeural(VoiceArguments(Array(CommandLine.arguments.dropFirst()))) }
        catch { fputs("Error: \(error.localizedDescription)\n",stderr); exit(1) }
    }
}

