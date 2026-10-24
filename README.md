# VPS：你租在远方的一台电脑

面向普通大众的中文动态图解短片：从“电脑关机后网站为什么还能访问”讲起，解释 VPS 的定义、虚拟化、租房类比、资源共享、用途、维护责任，以及 VPS 与 VPN 的区别。

- 1920 × 1080，16:9，30 fps，H.264 + AAC
- 中文旁白、烧录中文字幕，另附 SRT
- 当前配音：微软晓晓，zh-CN-XiaoxiaoNeural，普通话女声
- 语速：-5%；音高保持默认
- 时长与媒体检查结果：output/verification.json
- 原创矢量图解，无第三方图片、视频或背景音乐素材

## 成品

- output/vps-explained.mp4：最新完整视频
- output/vps-explained-xiaoxiao.mp4：晓晓配音版，便于区分版本
- output/vps-explained.zh-CN.srt：最新独立字幕
- output/xiaoxiao-preview.mp3：晓晓开场试音
- output/voice.json：实际声音、服务、语速和生成时间
- output/vps-cover.png：发布封面（内置图像生成）
- output/video-description.txt：发布标题、简介与标签
- output/cover-prompt.txt：完整生成提示词
- output/verification.json：尺寸、帧率、时长、音频解码与采样检查结果
- output/frames/：从最终 MP4 提取的九个场景中点
- script.json：完整旁白脚本

## 在远端重建

所有制作操作均在本仓库执行：

    ssh yangshuyun@10.10.10.1
    cd ~/workspace/dev/ai-video/test-1024-astra
    ./build.sh build
    ./build.sh synthesize
    ./build.sh render
    ./build.sh verify

神经语音合成需要联网访问 Microsoft Edge Read Aloud 服务，会把本片旁白文字发送给该服务。使用远端已有的 Swift、Foundation、CoreGraphics、CoreText 和 AVFoundation，不安装第三方依赖。

每句配音按文字、声音及语速的 SHA256 缓存。已有有效音频直接复用；仅修改画面时直接 render。字幕及场景时间根据实际配音时长生成。

调整语速：

    NEURAL_RATE=-5% ./build.sh synthesize

单独生成试音：

    ./build.sh build-voice
    build/edge-voice --text "VPS，中文叫虚拟专用服务器。" \
      --output output/voice-test.mp3 --voice zh-CN-XiaoxiaoNeural --rate=-5%

预览某一时间点：

    ./build.sh preview 37 output/preview.png

原始系统声音只通过显式命令 synthesize-system 使用；云端合成失败会报错，不会自动更换声音。第一版视频、字幕与时间线备份在 build/previous-tingting/。

## 文件结构

- sources/Scenes.swift：图形、中文排版、场景动画、字幕和进度条
- sources/main.swift：句级语音缓存、时间线、MP4 编码、音视频合成与检查
- sources/NeuralVoice.swift：使用系统 URLSession 的 Read Aloud 客户端
- sources/EdgeToken.swift：现行公开客户端协议的令牌计算
- build.sh：编译及命令入口
- build/：中间文件与缓存，已忽略
- output/：成品，媒体文件及预览图不纳入 Git
- THIRD_PARTY_NOTICES.md、licenses/：第三方源码来源与许可

## 内容依据

以下官方资料用于概念核对；没有引用原文或给出购买推荐。核对日期：2026-10-24。

1. [Google Cloud：What is a virtual private server (VPS)?](https://cloud.google.com/learn/what-is-a-virtual-private-server)
   定义、用途、共享主机 / VPS / 独立服务器的区别、托管与非托管责任。
2. [AWS：What is VPS?](https://aws.amazon.com/what-is/vps/)
   物理服务器划分为多个虚拟环境；用户部署自己的软件与服务。
3. [DigitalOcean：Choosing the Right Droplet Plan](https://docs.digitalocean.com/products/droplets/concepts/choosing-a-plan/)
   共享与独享 CPU 方案并存；共享 CPU 性能可能受其他工作负载影响。
4. [AWS：What is VPN?](https://aws.amazon.com/what-is/vpn/)
   VPN 是加密网络连接技术，区别于运行程序的服务器。
5. [Microsoft：Language and voice support](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/language-support)
   微软普通话神经语音名称及语言支持。

租房仅为类比；独立运行环境不等于全部物理硬件独占；可以持续运行不代表永不宕机；运维责任依具体托管方案而定。

