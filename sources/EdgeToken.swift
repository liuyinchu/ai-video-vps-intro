// SPDX-License-Identifier: LGPL-3.0-only
// Swift port of the public edge-tts Sec-MS-GEC v2 token implementation.
// Upstream: https://github.com/rany2/edge-tts/blob/master/src/edge_tts/drm.py
// Upstream authors: rany and the edge-tts contributors.
// License: https://github.com/rany2/edge-tts/blob/master/LICENSE
//
// This file is distributed under the GNU Lesser General Public License v3.
// It is provided without warranty, including merchantability or fitness for
// a particular purpose. See https://www.gnu.org/licenses/lgpl-3.0.html.
//
// Implements the current public client protocol only. It performs no network
// requests, authentication retries, or changes to an access-denied response.

private let edgeTrustedClientToken = "6A5AA1D4EAFF4E9FB37E23D68491D6F4"
private let edgeInitial: [UInt32] = [
    0x6A09E667, 0xBB67AE85, 0x3C6EF372, 0xA54FF53A,
    0x510E527F, 0x9B05688C, 0x1F83D9AB, 0x5BE0CD19
]
private let edgeInitialState: [UInt32] = [
    0xFD9FBEA2, 0x91243CE7, 0xBE499094, 0xCD2E1E0A,
    0x6C006F49, 0x04BD35AB, 0xFEB0A7E4, 0x03EFFBD2
]
private let edgeRoundConstants: [UInt32] = [
    0x428A2F98, 0x71374491, 0xB5C0FBCF, 0xE9B5DBA5,
    0x3956C25B, 0x59F111F1, 0x923F82A4, 0xAB1C5ED5,
    0xD807AA98, 0x12835B01, 0x243185BE, 0x550C7DC3,
    0x72BE5D74, 0x80DEB1FE, 0x9BDC06A7, 0xC19BF174,
    0xE49B69C1, 0xEFBE4786, 0x0FC19DC6, 0x240CA1CC,
    0x2DE92C6F, 0x4A7484AA, 0x5CB0A9DC, 0x76F988DA,
    0x983E5152, 0xA831C66D, 0xB00327C8, 0xBF597FC7,
    0xC6E00BF3, 0xD5A79147, 0x06CA6351, 0x14292967,
    0x27B70A85, 0x2E1B2138, 0x4D2C6DFC, 0x53380D13,
    0x650A7354, 0x766A0ABB, 0x81C2C92E, 0x92722C85,
    0xA2BFE8A1, 0xA81A664B, 0xC24B8B70, 0xC76C51A3,
    0xD192E819, 0xD6990624, 0xF40E3585, 0x106AA070,
    0x19A4C116, 0x1E376C08, 0x2748774C, 0x34B0BCB5,
    0x391C0CB3, 0x4ED8AA4A, 0x5B9CCA4F, 0x682E6FF3,
    0x748F82EE, 0x78A5636F, 0x84C87814, 0x8CC70208,
    0x90BEFFFA, 0xA4506CEB, 0xBEF9A3F7, 0xC67178F2
]
private let edgeCSCoefficients: [(UInt32, UInt32)] = [
    (0xE82E91B1, 0xB32700D0), (0x44DE24C6, 0x88DFF51D),
    (0x3BEB65BC, 0x29514038), (0xC89C5933, 0xB328CBDF),
    (0x8D1EC211, 0xD405B4D5), (0x314EF5D5, 0x26E55F3C),
    (0xE92491B1, 0x607801C6), (0xF0A5B9D5, 0x82B2C1FB),
    (0x06064CF3, 0xFA51A3DA), (0xDA79FA60, 0x207CC464),
    (0xBED20560, 0x3C3C74F3), (0x89F9C9F8, 0xD2D14B61),
    (0x35FA38C6, 0xBB04A2C1), (0xCB49E3C6, 0xC5626167)
]

private func edgeROR(_ x: UInt32, _ bits: UInt32) -> UInt32 {
    (x >> bits) | (x << (32 - bits))
}
private func edgeROL16(_ x: UInt32) -> UInt32 { (x << 16) | (x >> 16) }
private func edgeSigma0(_ x: UInt32) -> UInt32 {
    edgeROR(x, 7) ^ edgeROR(x, 18) ^ (x >> 3)
}
private func edgeSigma1(_ x: UInt32) -> UInt32 {
    edgeROR(x, 17) ^ edgeROR(x, 19) ^ (x >> 10)
}
private func edgeBEWord(_ bytes: ArraySlice<UInt8>) -> UInt32 {
    bytes.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
}
private func edgeLEWord(_ bytes: ArraySlice<UInt8>) -> UInt32 {
    bytes.reversed().reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
}
private func edgeExpand(_ words: inout [UInt32], from first: Int = 16) {
    for i in first..<64 {
        words.append(edgeSigma1(words[i - 2]) &+ words[i - 7]
            &+ edgeSigma0(words[i - 15]) &+ words[i - 16])
    }
}
private func edgeRounds(_ state: [UInt32], _ words: [UInt32], from first: Int = 0) -> [UInt32] {
    var a = state[0], b = state[1], c = state[2], d = state[3]
    var e = state[4], f = state[5], g = state[6], h = state[7]
    for i in first..<64 {
        let s1 = edgeROR(e, 6) ^ edgeROR(e, 11) ^ edgeROR(e, 25)
        let s0 = edgeROR(a, 2) ^ edgeROR(a, 13) ^ edgeROR(a, 22)
        let choose = g ^ (e & (f ^ g))
        let majority = (a & b) | (c & (a | b))
        let constant: UInt32 = (first == 14 && i == 14) ? 0xC9DC06A7 : edgeRoundConstants[i]
        let t1 = h &+ s1 &+ choose &+ constant &+ words[i]
        let t2 = s0 &+ majority
        h = g; g = f; f = e; e = d &+ t1
        d = c; c = b; b = a; a = t1 &+ t2
    }
    return [a, b, c, d, e, f, g, h]
}
private func edgeSHAInitial(_ data: [UInt8]) -> [UInt32] {
    var words = [UInt32](repeating: 0, count: 14)
    words.append(edgeBEWord(data[0..<3]))
    words.append(edgeBEWord(data[3..<7]))
    // Exactly the fourteen fixed schedule words in upstream drm.py.
    let schedule: [UInt32] = [
        0xEB24BF9E, 0x1558691F, 0xA0C09EE2, 0x0CFA32BA,
        0xA622EE8C, 0xD1DD9491, 0xC0DD25A0, 0xF9E70AB6,
        0xF0C31573, 0x7058CE4E, 0x7188E606, 0x00E5AB33,
        0xD258B060, 0x72766564
    ]
    for i in 16..<30 {
        var value = schedule[i - 16]
        if i - 2 >= 14 {
            value = value &+ (edgeSigma1(words[i - 2]) ^ (i == 16 ? 0x000B92C0 : 0))
        }
        if i - 7 >= 14 { value = value &+ words[i - 7] }
        if i - 15 >= 14 {
            value = value &+ (edgeSigma0(words[i - 15]) ^ (i == 29 ? 0x059C0B80 : 0))
        }
        words.append(value)
    }
    words.append(edgeSigma1(words[28]) &+ words[23] &+ edgeSigma0(words[15])
        &+ words[14] &+ 0xC9DC06A7 &- edgeRoundConstants[14])
    edgeExpand(&words, from: 31)
    let working = edgeRounds(edgeInitialState, words, from: 14)
    return zip(edgeInitial, working).map { $0 &+ $1 }
}
private func edgeSHADigest(_ data: [UInt8]) -> [UInt8] {
    precondition(data.count >= 7)
    let length = 57 + data.count
    var padded = Array(data.dropFirst(7))
    padded.append(0x80)
    padded.append(contentsOf: repeatElement(UInt8(0), count: ((55 - length) % 64 + 64) % 64))
    let bitLength = UInt64(length) * 8
    for shift in stride(from: 56, through: 0, by: -8) {
        padded.append(UInt8(truncatingIfNeeded: bitLength >> UInt64(shift)))
    }
    var state = edgeSHAInitial(Array(data.prefix(7)))
    for offset in stride(from: 0, to: padded.count, by: 64) {
        var words: [UInt32] = []
        for i in stride(from: offset, to: offset + 64, by: 4) {
            words.append(edgeBEWord(padded[i..<(i + 4)]))
        }
        edgeExpand(&words)
        let working = edgeRounds(state, words)
        state = zip(state, working).map { $0 &+ $1 }
    }
    return state.flatMap { word in
        [UInt8(truncatingIfNeeded: word >> 24), UInt8(truncatingIfNeeded: word >> 16),
         UInt8(truncatingIfNeeded: word >> 8), UInt8(truncatingIfNeeded: word)]
    }
}
private func edgeCSDigest(_ data: [UInt8], _ digest: [UInt8]) -> [UInt8] {
    let keyA = edgeLEWord(digest[0..<4]) | 1
    let keyB = edgeLEWord(digest[4..<8]) | 1
    let factors = [keyA &* 0x82893933, keyB &* 0x82893933]
    var terms = edgeCSCoefficients.enumerated().map { $0.element.0 &* factors[$0.offset % 2] }
    var offsets = edgeCSCoefficients.map { $0.1 }
    var padded = [UInt8(0)] + data
    padded.append(contentsOf: repeatElement(UInt8(0), count: (8 - padded.count % 8) % 8))
    for i in 0..<(padded.count / 4) {
        let word = edgeLEWord(padded[(i * 4)..<(i * 4 + 4)])
        var term = word &* (i % 2 == 0 ? keyA : keyB)
        var offset = edgeROL16(word) &* (i % 2 == 0 ? 0xEF0569FB : 0xC31713DB)
        if i == 0 {
            term = term &+ (0xF2F90B1A &* factors[0])
            offset = offset &+ 0x0B1A0000
        }
        terms.append(term)
        offsets.append(offset)
    }
    var swapAcc: UInt32 = 0, swapLast: UInt32 = 0
    var state: UInt32 = 0, acc: UInt32 = 0
    for i in stride(from: 0, to: terms.count, by: 2) {
        let x = terms[i], y = terms[i + 1]
        var t = edgeROL16(offsets[i] &+ x)
        var q = t &* 0x76F50F34
        swapAcc = swapAcc &+ (edgeROL16(q) &* 0xC3EFEA97 &+ q)
        t = edgeROL16(offsets[i + 1] &+ y)
        q = t &* 0x1881CE3C
        swapLast = edgeROL16(q) &* 0x35BD1EC9 &+ q
        swapAcc = swapAcc &+ swapLast
        state = state &* keyA &+ x
        state = edgeROL16(state) &* 0xCF98B111
        state = edgeROL16(state) &* 0x87085B9F
        state = edgeROL16(state) &* 0x12CEB96D
        state = edgeROL16(state) &* 0x257E1D83
        acc = acc &+ state
        t = state &* keyB &+ y
        t = edgeROL16(t) &* 0xA27416F5
        t = edgeROL16(t) &* 0xD38396FF
        state = edgeROL16(edgeROL16(t) &* 0x7C932B89) &* 0xBFA49F69
        acc = acc &+ state
    }
    return [swapLast ^ state, swapAcc ^ acc].flatMap { word in
        [UInt8(truncatingIfNeeded: word), UInt8(truncatingIfNeeded: word >> 8),
         UInt8(truncatingIfNeeded: word >> 16), UInt8(truncatingIfNeeded: word >> 24)]
    }
}
private func edgeHex(_ data: [UInt8]) -> String {
    let digits = Array("0123456789ABCDEF".utf8)
    return String(decoding: data.flatMap { [digits[Int($0 >> 4)], digits[Int($0 & 15)]] }, as: UTF8.self)
}

/// Current edge-tts public Sec-MS-GEC v2 token for Unix seconds.
func edgeToken(timestamp: Double) -> String {
    precondition(timestamp.isFinite && timestamp >= -11_644_473_600)
    let windowsSeconds = timestamp + 11_644_473_600
    let roundedSeconds = (windowsSeconds / 300).rounded(.down) * 300
    let ticks = UInt64(roundedSeconds) * 10_000_000
    let data = Array((String(ticks) + edgeTrustedClientToken).utf8)
    let digest = edgeSHADigest(data)
    return edgeHex(edgeCSDigest(data, digest)) + "-" + edgeHex(digest)
}

