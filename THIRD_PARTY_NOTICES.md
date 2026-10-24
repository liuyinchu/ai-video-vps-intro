# Third-party notices

## edge-tts public client token algorithm

`sources/EdgeToken.swift` is a Swift port of the Sec-MS-GEC v2 algorithm in
`src/edge_tts/drm.py` from [rany2/edge-tts](https://github.com/rany2/edge-tts),
by rany and the edge-tts contributors.

Source revision inspected: `bd44c1d1aaebdc1db7f47456ee12431b42ec7cac`.
[Original source](https://github.com/rany2/edge-tts/blob/bd44c1d1aaebdc1db7f47456ee12431b42ec7cac/src/edge_tts/drm.py).

The upstream project licenses this source under the GNU Lesser General
Public License, version 3 (LGPLv3). The Swift derivative retains that license.
Its changes consist of translation into Swift standard-library types,
wrapping UInt32 arithmetic, an ordinary round loop in place of unrolling,
and the `edgeToken(timestamp: Double) -> String` entry point. It does not
include the upstream Python runtime or network client.

The verbatim upstream notice and LGPLv3 terms are in
[licenses/edge-tts-LICENSE.txt](licenses/edge-tts-LICENSE.txt). The accompanying
GNU GPL version 3 text, incorporated by LGPLv3, is in
[licenses/GPL-3.0.txt](licenses/GPL-3.0.txt).

The MIT section of the verbatim upstream LICENSE applies only to upstream
`srt_composer.py`; that file is not included here. This notice assigns the
LGPLv3 license to the derived `sources/EdgeToken.swift` file and does not
relicense the project's other original source files. Distribution of a
combined executable must also respect the LGPL's applicable linking and
source-availability conditions.

The derivative is provided without warranty; see the complete license texts.

