import Foundation
import CoreGraphics
import CoreText

// Original vector artwork. All coordinates use a 1920 × 1080 design canvas.
let ink = color(0x142524)
let paper = color(0xF5F3EB)
let muted = color(0x60716B)
let accent = color(0xDBEF64)
let teal = color(0x79D5C5)
let white = color(0xFFFFFF)
let lineColor = color(0xD9DFD4)

func color(_ value: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((value >> 16) & 255) / 255,
            green: CGFloat((value >> 8) & 255) / 255,
            blue: CGFloat(value & 255) / 255, alpha: alpha)
}
func clamp(_ x: Double) -> Double { min(1, max(0, x)) }
func ease(_ x: Double) -> CGFloat { let v = clamp(x); return CGFloat(1 - pow(1 - v, 3)) }
func box(_ c: CGContext, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat,
         _ fill: CGColor, _ radius: CGFloat = 24, border: CGColor? = nil, stroke: CGFloat = 2) {
    let p = CGPath(roundedRect: CGRect(x:x,y:y,width:w,height:h), cornerWidth:radius,cornerHeight:radius,transform:nil)
    c.addPath(p); c.setFillColor(fill); c.fillPath()
    if let b = border { c.addPath(p); c.setStrokeColor(b); c.setLineWidth(stroke); c.strokePath() }
}
func dot(_ c: CGContext, _ x: CGFloat, _ y: CGFloat, _ radius: CGFloat, _ fill: CGColor) {
    c.setFillColor(fill); c.fillEllipse(in:CGRect(x:x-radius,y:y-radius,width:2*radius,height:2*radius))
}
func line(_ c: CGContext, _ points: [CGPoint], _ stroke: CGColor, _ width: CGFloat = 4) {
    guard let first = points.first else { return }
    c.beginPath(); c.move(to:first); for p in points.dropFirst() { c.addLine(to:p) }
    c.setLineWidth(width); c.setLineCap(.round); c.setLineJoin(.round); c.setStrokeColor(stroke); c.strokePath()
}
func text(_ c: CGContext, _ s: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat,
          _ fill: CGColor = ink, bold: Bool = false, align: String = "left") {
    let name = bold ? "PingFangSC-Semibold" : "PingFangSC-Regular"
    let f = CTFontCreateWithName(name as CFString, size, nil)
    let attrs: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): f,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): fill
    ]
    let l = CTLineCreateWithAttributedString(NSAttributedString(string:s, attributes:attrs))
    let w = CGFloat(CTLineGetTypographicBounds(l,nil,nil,nil))
    let dx: CGFloat = align == "center" ? -w/2 : (align == "right" ? -w : 0)
    c.saveGState(); c.translateBy(x:x+dx,y:y+size); c.scaleBy(x:1,y:-1)
    c.textMatrix = .identity; c.textPosition = .zero; CTLineDraw(l,c); c.restoreGState()
}
func tag(_ c: CGContext, _ s: String, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, dark: Bool = false) {
    box(c,x,y,w,48,dark ? ink : accent,24)
    text(c,s,x+w/2,y+7,24,dark ? white : ink,bold:true,align:"center")
}
func heading(_ c: CGContext, _ small: String, _ title: String, _ sub: String? = nil) {
    text(c,small,120,172,25,muted,bold:true)
    text(c,title,120,218,78,ink,bold:true)
    if let s = sub { text(c,s,123,326,31,muted) }
}
func server(_ c: CGContext, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, tint: CGColor = teal, active: Double = 0) {
    box(c,x,y,w,h,ink,28)
    for i in 0..<3 {
        let yy = y+26+CGFloat(i)*(h-52)/3
        box(c,x+22,yy,w-44,(h-70)/3,color(0x30443F),12)
        dot(c,x+43,yy+22,5,tint)
        for j in 0..<3 { box(c,x+w-68+CGFloat(j)*12,yy+17,5,12,color(0x6E827A),2) }
    }
    if active > 0 { dot(c,x+w-21,y+17,5,accent) }
}
func laptop(_ c: CGContext, _ x: CGFloat, _ y: CGFloat, _ scale: CGFloat = 1, closed: Bool = false) {
    c.saveGState(); c.translateBy(x:x,y:y); c.scaleBy(x:scale,y:scale)
    if !closed {
        box(c,15,0,350,230,ink,20)
        box(c,30,17,320,194,white,9)
        box(c,49,38,282,25,lineColor,5)
        dot(c,60,50,3,muted); dot(c,73,50,3,muted)
        box(c,49,82,125,107,teal,8); box(c,189,82,140,16,lineColor,5)
        box(c,189,111,115,10,lineColor,4); box(c,189,136,135,10,lineColor,4)
        box(c,189,163,85,26,accent,6)
    } else {
        box(c,14,204,351,22,muted,7)
    }
    box(c,0,226,380,22,ink,8); box(c,153,226,72,7,muted,3)
    c.restoreGState()
}
func phone(_ c: CGContext, _ x: CGFloat, _ y: CGFloat, _ scale: CGFloat = 1) {
    c.saveGState(); c.translateBy(x:x,y:y); c.scaleBy(x:scale,y:scale)
    box(c,0,0,154,278,ink,29); box(c,10,13,134,251,white,19)
    box(c,51,19,52,9,ink,5); box(c,25,53,104,68,teal,8)
    box(c,25,140,84,11,lineColor,4); box(c,25,165,104,10,lineColor,4)
    box(c,25,190,79,10,lineColor,4); box(c,25,221,104,25,accent,6)
    c.restoreGState()
}
func check(_ c: CGContext, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat = 26, tint: CGColor = ink) {
    line(c,[CGPoint(x:x,y:y+size*0.5),CGPoint(x:x+size*0.35,y:y+size*0.86),CGPoint(x:x+size,y:y)],tint,5)
}
func building(_ c: CGContext, _ x: CGFloat, _ y: CGFloat, _ kind: Int, _ t: Double) {
    box(c,x,y,350,245,kind == 2 ? ink : color(0xE7EBDF),20,border:kind == 2 ? ink : lineColor)
    for row in 0..<2 { for col in 0..<3 {
        let xx = x+25+CGFloat(col)*104; let yy = y+25+CGFloat(row)*104
        let chosen = kind == 1 && row == 0 && col == 1
        box(c,xx,yy,90,88,chosen ? accent : (kind == 2 ? color(0x3E5550) : white),11)
        if kind == 0 {
            for k in 0..<3 { dot(c,xx+22+CGFloat(k)*23,yy+35,8,muted) }
            box(c,xx+16,yy+56,57,10,lineColor,4)
        } else {
            box(c,xx+18,yy+18,22,25,kind == 2 ? teal : muted,4)
            box(c,xx+51,yy+18,22,25,kind == 2 ? teal : muted,4)
            box(c,xx+34,yy+54,24,34,chosen ? ink : (kind == 2 ? teal : lineColor),4)
        }
    }}
}

func sceneArt(_ c: CGContext, _ id: Int, _ t: Double, _ duration: Double) {
    let intro = ease(t/0.8)
    c.saveGState(); c.setAlpha(intro); c.translateBy(x:0,y:22*(1-intro))
    switch id {
    case 0:
        tag(c,"从一个日常问题开始",120,188,282)
        text(c,"电脑关了，",120,275,102,ink,bold:true)
        text(c,"网站还在？",120,401,102,ink,bold:true)
        text(c,"答案，藏在远方的机房。",124,577,34,muted)
        box(c,940,196,850,620,color(0xE6ECDD),40)
        text(c,"你的电脑",1060,696,27,muted,align:"center")
        laptop(c,938,488,0.68,closed:t>2.1)
        phone(c,1287,449,0.8)
        server(c,1481,292,231,312,active:t)
        tag(c,"远端服务运行中",1431,642,290,dark:true)
        line(c,[CGPoint(x:1413,y:509),CGPoint(x:1444,y:509),CGPoint(x:1444,y:430),CGPoint(x:1461,y:430)],muted,3)
        let p = CGFloat((t*0.5).truncatingRemainder(dividingBy:1))
        dot(c,1413+48*p,509-79*p,7,accent)
        text(c,"机房",1596,235,26,muted,align:"center")
    case 1:
        text(c,"认识三个字母",120,190,27,muted,bold:true)
        text(c,"VPS",109,232,240,ink,bold:true)
        box(c,120,520,730,10,accent,5)
        text(c,"虚拟专用服务器",120,572,68,ink,bold:true)
        text(c,"Virtual Private Server",123,670,31,muted)
        box(c,1030,226,750,567,ink,40)
        tag(c,"通过网络租用",1253,271,304)
        server(c,1298,375,220,269,tint:accent,active:t)
        text(c,"一台你能管理的虚拟电脑",1405,705,37,white,bold:true,align:"center")
        for i in 0..<3 {
            let p = CGFloat((t*0.23+Double(i)/3).truncatingRemainder(dividingBy:1))
            dot(c,920+91*p,500,5,muted)
        }
    case 2:
        heading(c,"拆开看，就不神秘了","一台物理服务器，多个虚拟环境")
        box(c,120,385,1680,423,color(0xE6EBDD),32,border:lineColor)
        let labels = ["其他用户","你的 VPS","其他用户"]
        for i in 0..<3 {
            let reveal = ease((t-0.35-Double(i)*0.22)/0.7)
            c.saveGState(); c.setAlpha(reveal); c.translateBy(x:0,y:26*(1-reveal))
            let x:CGFloat = 164+CGFloat(i)*550
            box(c,x,425,490,226,i == 1 ? ink : white,24)
            tag(c,labels[i],x+125,449,240,dark:i != 1)
            text(c,"自己的系统",x+245,523,30,i == 1 ? white : muted,bold:true,align:"center")
            text(c,"自己的软件与服务",x+245,574,26,i == 1 ? teal : muted,align:"center")
            line(c,[CGPoint(x:x+245,y:654),CGPoint(x:x+245,y:696)],muted,3)
            let flow = CGFloat((t*0.45+Double(i)*0.2).truncatingRemainder(dividingBy:1))
            dot(c,x+245,693-36*flow,6,i == 1 ? ink : muted)
            c.restoreGState()
        }
        box(c,164,698,1578,72,teal,16)
        text(c,"底层：同一台物理服务器的硬件",953,713,31,ink,bold:true,align:"center")
    case 3:
        heading(c,"一个不完全、但好懂的类比","租房，也有不同的方式")
        let names = ["共享主机","VPS","独立服务器"]
        let subs = ["合住房间","独立公寓","整栋楼"]
        let notes = ["管理空间较少","可管理自己的系统","租用整台物理服务器"]
        for i in 0..<3 {
            let x:CGFloat = 120+CGFloat(i)*570
            let reveal = ease((t-Double(i)*0.35)/0.8)
            c.saveGState(); c.setAlpha(reveal); c.translateBy(x:0,y:22*(1-reveal))
            box(c,x,369,540,458,i == 1 ? color(0xE4EECB) : white,28,border:i == 1 ? ink : lineColor)
            text(c,names[i],x+270,393,42,ink,bold:true,align:"center")
            building(c,x+95,465,i,t)
            text(c,subs[i],x+270,724,39,ink,bold:true,align:"center")
            text(c,notes[i],x+270,781,22,muted,align:"center")
            c.restoreGState()
        }
    case 4:
        heading(c,"类比的关键在这里","独立空间，也会共享底层资源")
        for i in 0..<3 {
            let x:CGFloat = 120+CGFloat(i)*370
            box(c,x,393,330,200,i == 1 ? ink : white,22,border:lineColor)
            text(c,i == 1 ? "你的 VPS" : "其他 VPS",x+165,432,35,i == 1 ? white : muted,bold:true,align:"center")
            tag(c,"虚拟环境",x+65,505,200,dark:i != 1)
            line(c,[CGPoint(x:x+165,y:594),CGPoint(x:x+165,y:666)],muted,4)
            let flow = CGFloat((t*0.4+Double(i)*0.23).truncatingRemainder(dividingBy:1))
            dot(c,x+165,658-flow*55,7,i == 1 ? ink : teal)
        }
        box(c,120,667,1070,115,teal,23)
        text(c,"物理硬件 · CPU 等资源可能共享",655,704,34,ink,bold:true,align:"center")
        box(c,1260,393,540,390,ink,28)
        text(c,"虚拟隔离",1530,439,58,white,bold:true,align:"center")
        text(c,"≠",1530,514,90,accent,bold:true,align:"center")
        text(c,"整机独占",1530,635,58,white,bold:true,align:"center")
        text(c,"隔离程度与性能，取决于具体方案",120,821,27,muted)
    case 5:
        heading(c,"让程序在远端工作","它能做什么？")
        let titles = ["搭建网站","小程序后台","开发与测试"]
        let desc = ["展示内容，让人访问","处理请求，存取数据","运行代码，验证想法"]
        for i in 0..<3 {
            let x:CGFloat = 120+CGFloat(i)*570
            let reveal = ease((t-Double(i)*0.35)/0.7)
            c.saveGState(); c.setAlpha(reveal); c.translateBy(x:0,y:24*(1-reveal))
            box(c,x,377,540,405,white,28,border:lineColor)
            if i == 0 { laptop(c,x+93,415,0.92) }
            if i == 1 {
                phone(c,x+65,414,0.75); server(c,x+290,436,150,173)
                line(c,[CGPoint(x:x+197,y:513),CGPoint(x:x+270,y:513)],muted,4)
                dot(c,x+204+CGFloat((t*0.6).truncatingRemainder(dividingBy:1))*58,513,6,teal)
            }
            if i == 2 {
                box(c,x+70,416,400,222,ink,18)
                text(c,"</>",x+270,450,90,teal,bold:true,align:"center")
                for j in 0..<3 { box(c,x+100+CGFloat(j)*94,592,76,8,j == 2 ? accent : muted,4) }
            }
            text(c,titles[i],x+270,671,40,ink,bold:true,align:"center")
            text(c,desc[i],x+270,730,24,muted,align:"center")
            c.restoreGState()
        }
        tag(c,"你的电脑关机，远端服务仍可继续运行",476,820,968)
    case 6:
        heading(c,"租用之前，先知道","更自由，也需要你照顾")
        box(c,120,387,650,415,ink,30)
        text(c,"你获得的",175,431,29,teal,bold:true)
        text(c,"可管理的",175,497,62,white,bold:true)
        text(c,"服务器资源",175,579,62,white,bold:true)
        tag(c,"通常不自动包含运维",175,704,540)
        let names = ["安装软件","安全更新","数据备份"]
        let sub = ["让服务跑起来","及时修补漏洞","给数据留退路"]
        for i in 0..<3 {
            let y:CGFloat = 387+CGFloat(i)*141
            let reveal = ease((t-Double(i)*0.3)/0.7)
            c.saveGState(); c.setAlpha(reveal)
            box(c,835,y,965,125,white,22,border:lineColor)
            dot(c,897,y+62,29,i == 1 ? teal : accent)
            check(c,883,y+51,27)
            text(c,names[i],954,y+34,39,ink,bold:true)
            text(c,sub[i],1750,y+43,27,muted,align:"right")
            c.restoreGState()
        }
        text(c,"托管服务包含哪些维护工作，以服务方案为准。",120,835,26,muted)
    case 7:
        heading(c,"别把名字记混了","VPS 和 VPN，是两件事")
        box(c,120,378,800,439,ink,30)
        box(c,1000,378,800,439,white,30,border:lineColor)
        text(c,"VPS",173,418,120,accent,bold:true)
        text(c,"VPN",1052,418,120,ink,bold:true)
        server(c,699,433,148,188,tint:accent)
        let yy:CGFloat = 570
        box(c,1489,yy-55,78,101,lineColor,12)
        box(c,1660,yy-55,78,101,lineColor,12)
        line(c,[CGPoint(x:1567,y:yy-5),CGPoint(x:1660,y:yy-5)],teal,16)
        box(c,1588,yy-32,49,53,ink,9)
        c.setStrokeColor(ink); c.setLineWidth(7)
        c.strokeEllipse(in:CGRect(x:1598,y:yy-50,width:29,height:39))
        text(c,"服务器",175,640,52,white,bold:true)
        text(c,"用来运行程序",175,717,31,teal)
        text(c,"网络连接技术",1055,640,52,ink,bold:true)
        text(c,"用来建立加密连接",1055,717,31,muted)
    default:
        tag(c,"现在，你已经认识 VPS 了",120,187,422)
        text(c,"你租在远方的",120,277,104,ink,bold:true)
        text(c,"一份服务器资源。",120,402,104,ink,bold:true)
        let labels = ["远程租用","运行程序","自己管理"]
        for i in 0..<3 {
            let x:CGFloat = 120+CGFloat(i)*395
            box(c,x,615,360,104,i == 2 ? ink : white,25,border:lineColor)
            text(c,labels[i],x+180,642,39,i == 2 ? white : ink,bold:true,align:"center")
        }
        text(c,"更灵活，也需要你照顾它。",124,778,35,muted)
        server(c,1474,299,278,354,tint:accent,active:t)
        dot(c,1722,303,53,accent); check(c,1694,283,51)
    }
    c.restoreGState()
}

func drawFrame(_ ctx: CGContext, time: Double, timeline: Timeline) {
    ctx.saveGState(); ctx.translateBy(x:0,y:1080); ctx.scaleBy(x:1,y:-1)
    box(ctx,0,0,1920,1080,paper,0)
    // Quiet grid provides visual structure without competing with the narration.
    ctx.setLineWidth(1); ctx.setStrokeColor(color(0xE9EADF))
    for x in stride(from: 1000, to: 1921, by: 80) {
        ctx.move(to:CGPoint(x:x,y:0)); ctx.addLine(to:CGPoint(x:x,y:900))
    }
    for y in stride(from: 20, to: 901, by: 80) {
        ctx.move(to:CGPoint(x:1000,y:y)); ctx.addLine(to:CGPoint(x:1920,y:y))
    }
    ctx.strokePath()
    dot(ctx,131,81,10,ink); text(ctx,"把技术讲明白",155,59,27,ink,bold:true)
    let scene = timeline.scenes.last(where: {$0.start <= time}) ?? timeline.scenes[0]
    let local = max(0,time-scene.start)
    text(ctx,"VPS / 零基础科普",1795,62,24,muted,align:"right")
    line(ctx,[CGPoint(x:120,y:123),CGPoint(x:1800,y:123)],lineColor,2)
    sceneArt(ctx,scene.id,local,scene.duration)
    // One short subtitle at a time, timed to its individual spoken sentence.
    if let caption = timeline.captions.last(where: {$0.start <= time && time < $0.start+$0.duration}) {
        box(ctx,120,922,1680,91,ink,23)
        let size:CGFloat = caption.text.count > 32 ? 38 : 42
        text(ctx,caption.text,960,941,size,white,bold:false,align:"center")
    }
    let totalWidth:CGFloat = 1510
    let gap:CGFloat = 9
    let n = CGFloat(timeline.scenes.count)
    let width = (totalWidth-gap*(n-1))/n
    for (i, sc) in timeline.scenes.enumerated() {
        let x = 120+CGFloat(i)*(width+gap)
        box(ctx,x,1043,width,5,lineColor,2)
        let progress = CGFloat(clamp((time-sc.start)/sc.duration))
        if progress > 0 { box(ctx,x,1043,width*progress,5,ink,2) }
    }
    text(ctx,String(format:"%02d / %02d",scene.id+1,timeline.scenes.count),1800,1023,22,muted,bold:true,align:"right")
    ctx.restoreGState()
}

