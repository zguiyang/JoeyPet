import SwiftUI

enum NestFace {
    case calm
    case look
    case happy
    case stretch
    case yawn
    case doze
    case groom
    case sleep
    case blink2
    case blink3
}

enum NestEarStyle {
    case sleep
    case perk
    case twitch
}

enum NestArms {
    case rest
    case up
    case wave
    case groom
}

/// Vector art for the nest pet. Coordinates follow the 320×400 design sheet.
struct NestPetArt {
    let theme: JoeyTheme

    // MARK: - Lying

    /// Loaf-shaped sleep pose reused from the desktop pet's existing `sleep`
    /// artwork. It keeps Joey readable as a bunny instead of the wide blob in
    /// the first nest-animation draft.
    func drawLoaf(
        in context: inout GraphicsContext,
        face: NestFace,
        earTilt: Double = 8,
        earTwitch: Bool = false,
        headOffsetY: CGFloat = 0,
        breath: CGFloat = 1,
        tailAngle: Double = 0,
        opacity: Double = 1
    ) {
        context.drawLayer { layer in
            layer.opacity = opacity
            if breath != 1 {
                layer.translateBy(x: 160, y: 388)
                layer.scaleBy(x: 1, y: breath)
                layer.translateBy(x: -160, y: -388)
            }

            fillEllipse(
                &layer,
                cx: 160,
                cy: 368,
                rx: 96,
                ry: 12,
                color: theme.joeyEye,
                opacity: 0.08
            )

            var tail = Path()
            tail.move(to: CGPoint(x: 266, y: 330))
            tail.addCurve(
                to: CGPoint(x: 288, y: 300),
                control1: CGPoint(x: 292, y: 336),
                control2: CGPoint(x: 302, y: 312)
            )
            tail.addCurve(
                to: CGPoint(x: 265, y: 307),
                control1: CGPoint(x: 278, y: 291),
                control2: CGPoint(x: 264, y: 296)
            )
            layer.drawLayer { tailLayer in
                tailLayer.translateBy(x: 270, y: 315)
                tailLayer.rotate(by: .degrees(tailAngle))
                tailLayer.translateBy(x: -270, y: -315)
                tailLayer.stroke(
                    tail,
                    with: .color(theme.joeyTail),
                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                )
            }

            var body = Path()
            body.move(to: CGPoint(x: 150, y: 250))
            body.addCurve(
                to: CGPoint(x: 266, y: 312),
                control1: CGPoint(x: 204, y: 244),
                control2: CGPoint(x: 258, y: 274)
            )
            body.addCurve(
                to: CGPoint(x: 162, y: 374),
                control1: CGPoint(x: 274, y: 350),
                control2: CGPoint(x: 226, y: 374)
            )
            body.addCurve(
                to: CGPoint(x: 56, y: 312),
                control1: CGPoint(x: 98, y: 374),
                control2: CGPoint(x: 54, y: 350)
            )
            body.addCurve(
                to: CGPoint(x: 150, y: 250),
                control1: CGPoint(x: 58, y: 288),
                control2: CGPoint(x: 90, y: 264)
            )
            body.closeSubpath()
            layer.fill(body, with: .color(theme.joeyBody))

            layer.drawLayer { head in
                head.translateBy(x: 0, y: headOffsetY)

                var leftEar = Path()
                leftEar.move(to: CGPoint(x: 112, y: 268))
                leftEar.addCurve(
                    to: CGPoint(x: 96, y: 220),
                    control1: CGPoint(x: 96, y: 254),
                    control2: CGPoint(x: 88, y: 232)
                )
                leftEar.addCurve(
                    to: CGPoint(x: 124, y: 230),
                    control1: CGPoint(x: 104, y: 209),
                    control2: CGPoint(x: 119, y: 215)
                )
                leftEar.closeSubpath()
                drawTiltedEar(&head, leftEar, pivot: CGPoint(x: 112, y: 268), angle: -earTilt)

                var rightEar = Path()
                rightEar.move(to: CGPoint(x: 152, y: 254))
                rightEar.addCurve(
                    to: CGPoint(x: 160, y: 210),
                    control1: CGPoint(x: 146, y: 236),
                    control2: CGPoint(x: 148, y: 216)
                )
                rightEar.addCurve(
                    to: CGPoint(x: 180, y: 234),
                    control1: CGPoint(x: 172, y: 205),
                    control2: CGPoint(x: 182, y: 218)
                )
                rightEar.closeSubpath()
                drawTiltedEar(
                    &head,
                    rightEar,
                    pivot: CGPoint(x: 152, y: 254),
                    angle: earTilt + (earTwitch ? 12 : 0)
                )

                fillEllipse(
                    &head,
                    cx: 112,
                    cy: 318,
                    rx: 20,
                    ry: 10,
                    color: theme.joeyBlush,
                    opacity: 0.22
                )
                fillEllipse(
                    &head,
                    cx: 170,
                    cy: 314,
                    rx: 16,
                    ry: 8,
                    color: theme.joeyBlush,
                    opacity: 0.16
                )

                if face == .look {
                    drawLoafOpenEyes(&head)
                } else {
                    var leftEye = Path()
                    leftEye.move(to: CGPoint(x: 98, y: 306))
                    leftEye.addCurve(
                        to: CGPoint(x: 122, y: 306),
                        control1: CGPoint(x: 104, y: 314),
                        control2: CGPoint(x: 116, y: 314)
                    )
                    head.stroke(
                        leftEye,
                        with: .color(theme.joeyEye),
                        style: StrokeStyle(lineWidth: 3.6, lineCap: .round)
                    )

                    var rightEye = Path()
                    rightEye.move(to: CGPoint(x: 150, y: 306))
                    rightEye.addCurve(
                        to: CGPoint(x: 174, y: 306),
                        control1: CGPoint(x: 156, y: 314),
                        control2: CGPoint(x: 168, y: 314)
                    )
                    head.stroke(
                        rightEye,
                        with: .color(theme.joeyEye),
                        style: StrokeStyle(lineWidth: 3.6, lineCap: .round)
                    )
                }

                var nose = Path()
                nose.move(to: CGPoint(x: 136, y: 318))
                nose.addCurve(
                    to: CGPoint(x: 141, y: 323.5),
                    control1: CGPoint(x: 141, y: 318),
                    control2: CGPoint(x: 143, y: 321)
                )
                nose.addCurve(
                    to: CGPoint(x: 131, y: 323.5),
                    control1: CGPoint(x: 139.5, y: 325.5),
                    control2: CGPoint(x: 132.5, y: 325.5)
                )
                nose.addCurve(
                    to: CGPoint(x: 136, y: 318),
                    control1: CGPoint(x: 129, y: 321),
                    control2: CGPoint(x: 131, y: 318)
                )
                nose.closeSubpath()
                head.fill(nose, with: .color(theme.joeyNose))

                var mouth = Path()
                mouth.move(to: CGPoint(x: 136, y: 326))
                mouth.addCurve(
                    to: CGPoint(x: 128, y: 329),
                    control1: CGPoint(x: 134, y: 330),
                    control2: CGPoint(x: 130, y: 331)
                )
                head.stroke(
                    mouth,
                    with: .color(theme.joeyMouth),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
            }

            var scarf = Path()
            scarf.move(to: CGPoint(x: 124, y: 340))
            scarf.addCurve(
                to: CGPoint(x: 194, y: 338),
                control1: CGPoint(x: 140, y: 350),
                control2: CGPoint(x: 176, y: 350)
            )
            layer.stroke(
                scarf,
                with: .color(theme.joeyScarf.opacity(0.85)),
                style: StrokeStyle(lineWidth: 8, lineCap: .round)
            )
        }
    }

    private func drawTiltedEar(
        _ context: inout GraphicsContext,
        _ ear: Path,
        pivot: CGPoint,
        angle: Double
    ) {
        context.drawLayer { layer in
            layer.translateBy(x: pivot.x, y: pivot.y)
            layer.rotate(by: .degrees(angle))
            layer.translateBy(x: -pivot.x, y: -pivot.y)
            layer.fill(ear, with: .color(theme.joeyBody))
        }
    }

    private func drawLoafOpenEyes(_ context: inout GraphicsContext) {
        fillEllipse(
            &context,
            cx: 110,
            cy: 304,
            rx: 8,
            ry: 11,
            color: theme.joeyEye
        )
        fillEllipse(
            &context,
            cx: 107,
            cy: 300,
            rx: 2.5,
            ry: 2.5,
            color: .white
        )
        fillEllipse(
            &context,
            cx: 162,
            cy: 304,
            rx: 8,
            ry: 11,
            color: theme.joeyEye
        )
        fillEllipse(
            &context,
            cx: 159,
            cy: 300,
            rx: 2.5,
            ry: 2.5,
            color: .white
        )
    }

    func drawLying(
        in context: inout GraphicsContext,
        face: NestFace,
        ears: NestEarStyle,
        headOffset: CGSize = .zero,
        headRotation: Double = 0,
        faceOffset: CGSize,
        breath: CGFloat = 1,
        tailAngle: Double = 0,
        opacity: Double = 1
    ) {
        context.drawLayer { layer in
            layer.opacity = opacity
            if breath != 1 {
                layer.translateBy(x: 160, y: 388)
                layer.scaleBy(x: 1, y: breath)
                layer.translateBy(x: -160, y: -388)
            }

            drawLyingBody(&layer, tailAngle: tailAngle)

            layer.drawLayer { head in
                head.translateBy(x: headOffset.width, y: headOffset.height)
                if headRotation != 0 {
                    head.translateBy(x: 126, y: 292)
                    head.rotate(by: .degrees(headRotation))
                    head.translateBy(x: -126, y: -292)
                }

                fillEllipse(
                    &head,
                    cx: 126,
                    cy: 292,
                    rx: 52,
                    ry: 48,
                    color: theme.joeyBody
                )
                drawLyingEars(&head, style: ears)
                head.drawLayer { faceLayer in
                    faceLayer.translateBy(x: faceOffset.width, y: faceOffset.height)
                    drawFace(face, in: &faceLayer)
                }
            }

            drawLyingPaws(&layer)
        }
    }

    private func drawLyingBody(_ context: inout GraphicsContext, tailAngle: Double) {
        fillEllipse(
            &context,
            cx: 160,
            cy: 368,
            rx: 120,
            ry: 16,
            color: theme.joeyEye,
            opacity: 0.08
        )

        var tail = Path()
        tail.move(to: CGPoint(x: 262, y: 330))
        tail.addCurve(
            to: CGPoint(x: 286, y: 302),
            control1: CGPoint(x: 292, y: 338),
            control2: CGPoint(x: 300, y: 314)
        )
        tail.addCurve(
            to: CGPoint(x: 263, y: 309),
            control1: CGPoint(x: 276, y: 293),
            control2: CGPoint(x: 262, y: 298)
        )
        context.drawLayer { tailLayer in
            tailLayer.translateBy(x: 250, y: 320)
            tailLayer.rotate(by: .degrees(tailAngle))
            tailLayer.translateBy(x: -250, y: -320)
            tailLayer.stroke(
                tail,
                with: .color(theme.joeyTail),
                style: StrokeStyle(lineWidth: 20, lineCap: .round)
            )
        }

        var body = Path()
        body.move(to: CGPoint(x: 96, y: 320))
        body.addCurve(
            to: CGPoint(x: 178, y: 258),
            control1: CGPoint(x: 96, y: 280),
            control2: CGPoint(x: 132, y: 258)
        )
        body.addCurve(
            to: CGPoint(x: 268, y: 324),
            control1: CGPoint(x: 232, y: 258),
            control2: CGPoint(x: 268, y: 288)
        )
        body.addCurve(
            to: CGPoint(x: 176, y: 372),
            control1: CGPoint(x: 268, y: 356),
            control2: CGPoint(x: 226, y: 372)
        )
        body.addCurve(
            to: CGPoint(x: 96, y: 320),
            control1: CGPoint(x: 124, y: 372),
            control2: CGPoint(x: 96, y: 352)
        )
        body.closeSubpath()
        context.fill(body, with: .color(theme.joeyBody))

        var belly = Path()
        belly.move(to: CGPoint(x: 176, y: 372))
        belly.addCurve(
            to: CGPoint(x: 96, y: 320),
            control1: CGPoint(x: 124, y: 372),
            control2: CGPoint(x: 96, y: 352)
        )
        belly.addCurve(
            to: CGPoint(x: 97, y: 308),
            control1: CGPoint(x: 96, y: 316),
            control2: CGPoint(x: 96, y: 312)
        )
        belly.addCurve(
            to: CGPoint(x: 176, y: 362),
            control1: CGPoint(x: 112, y: 350),
            control2: CGPoint(x: 140, y: 362)
        )
        belly.addCurve(
            to: CGPoint(x: 264, y: 306),
            control1: CGPoint(x: 214, y: 362),
            control2: CGPoint(x: 246, y: 346)
        )
        belly.addCurve(
            to: CGPoint(x: 268, y: 324),
            control1: CGPoint(x: 267, y: 312),
            control2: CGPoint(x: 268, y: 318)
        )
        belly.addCurve(
            to: CGPoint(x: 176, y: 372),
            control1: CGPoint(x: 268, y: 356),
            control2: CGPoint(x: 226, y: 372)
        )
        belly.closeSubpath()
        context.fill(belly, with: .color(theme.joeyShade.opacity(0.5)))

        var scarf = Path()
        scarf.move(to: CGPoint(x: 128, y: 330))
        scarf.addCurve(
            to: CGPoint(x: 192, y: 330),
            control1: CGPoint(x: 146, y: 342),
            control2: CGPoint(x: 176, y: 342)
        )
        context.stroke(
            scarf,
            with: .color(theme.joeyScarf),
            style: StrokeStyle(lineWidth: 9, lineCap: .round)
        )
        fillEllipse(
            &context,
            cx: 194,
            cy: 333,
            rx: 7,
            ry: 7,
            color: theme.joeyScarf
        )
    }

    private func drawLyingEars(_ context: inout GraphicsContext, style: NestEarStyle) {
        switch style {
        case .sleep:
            drawSleepEars(&context)
        case .perk:
            drawPerkEars(&context)
        case .twitch:
            drawSleepEars(&context)
            var top = Path()
            top.move(to: CGPoint(x: 148, y: 252))
            top.addCurve(
                to: CGPoint(x: 182, y: 212),
                control1: CGPoint(x: 156, y: 228),
                control2: CGPoint(x: 170, y: 212)
            )
            top.addCurve(
                to: CGPoint(x: 162, y: 258),
                control1: CGPoint(x: 190, y: 222),
                control2: CGPoint(x: 178, y: 246)
            )
            top.closeSubpath()
            context.fill(top, with: .color(theme.joeyBody))

            var inner = Path()
            inner.move(to: CGPoint(x: 154, y: 250))
            inner.addCurve(
                to: CGPoint(x: 178, y: 218),
                control1: CGPoint(x: 160, y: 232),
                control2: CGPoint(x: 170, y: 220)
            )
            inner.addCurve(
                to: CGPoint(x: 162, y: 250),
                control1: CGPoint(x: 182, y: 223),
                control2: CGPoint(x: 173, y: 240)
            )
            inner.closeSubpath()
            context.fill(inner, with: .color(theme.joeyInnerEar.opacity(0.9)))
        }
    }

    private func drawSleepEars(_ context: inout GraphicsContext) {
        var left = Path()
        left.move(to: CGPoint(x: 104, y: 254))
        left.addCurve(
            to: CGPoint(x: 52, y: 266),
            control1: CGPoint(x: 84, y: 240),
            control2: CGPoint(x: 58, y: 246)
        )
        left.addCurve(
            to: CGPoint(x: 76, y: 293),
            control1: CGPoint(x: 47, y: 284),
            control2: CGPoint(x: 60, y: 298)
        )
        left.addCurve(
            to: CGPoint(x: 106, y: 264),
            control1: CGPoint(x: 90, y: 289),
            control2: CGPoint(x: 96, y: 272)
        )
        left.closeSubpath()
        context.fill(left, with: .color(theme.joeyBody))

        var leftInner = Path()
        leftInner.move(to: CGPoint(x: 100, y: 258))
        leftInner.addCurve(
            to: CGPoint(x: 62, y: 266),
            control1: CGPoint(x: 84, y: 249),
            control2: CGPoint(x: 66, y: 253)
        )
        leftInner.addCurve(
            to: CGPoint(x: 78, y: 282),
            control1: CGPoint(x: 59, y: 277),
            control2: CGPoint(x: 68, y: 286)
        )
        context.stroke(
            leftInner,
            with: .color(theme.joeyInnerEar.opacity(0.9)),
            style: StrokeStyle(lineWidth: 10, lineCap: .round)
        )

        var right = Path()
        right.move(to: CGPoint(x: 146, y: 250))
        right.addCurve(
            to: CGPoint(x: 210, y: 256),
            control1: CGPoint(x: 170, y: 234),
            control2: CGPoint(x: 200, y: 238)
        )
        right.addCurve(
            to: CGPoint(x: 194, y: 280),
            control1: CGPoint(x: 218, y: 270),
            control2: CGPoint(x: 208, y: 284)
        )
        right.addCurve(
            to: CGPoint(x: 158, y: 258),
            control1: CGPoint(x: 180, y: 276),
            control2: CGPoint(x: 170, y: 262)
        )
        right.closeSubpath()
        context.fill(right, with: .color(theme.joeyBody))

        var rightInner = Path()
        rightInner.move(to: CGPoint(x: 152, y: 254))
        rightInner.addCurve(
            to: CGPoint(x: 198, y: 258),
            control1: CGPoint(x: 170, y: 243),
            control2: CGPoint(x: 192, y: 246)
        )
        rightInner.addCurve(
            to: CGPoint(x: 186, y: 273),
            control1: CGPoint(x: 203, y: 268),
            control2: CGPoint(x: 196, y: 276)
        )
        context.stroke(
            rightInner,
            with: .color(theme.joeyInnerEar.opacity(0.9)),
            style: StrokeStyle(lineWidth: 9, lineCap: .round)
        )
    }

    private func drawPerkEars(_ context: inout GraphicsContext) {
        var left = Path()
        left.move(to: CGPoint(x: 110, y: 258))
        left.addCurve(
            to: CGPoint(x: 108, y: 190),
            control1: CGPoint(x: 100, y: 226),
            control2: CGPoint(x: 100, y: 200)
        )
        left.addCurve(
            to: CGPoint(x: 127, y: 202),
            control1: CGPoint(x: 114, y: 183),
            control2: CGPoint(x: 124, y: 188)
        )
        left.addCurve(
            to: CGPoint(x: 134, y: 256),
            control1: CGPoint(x: 132, y: 222),
            control2: CGPoint(x: 133, y: 244)
        )
        left.closeSubpath()
        context.fill(left, with: .color(theme.joeyBody))

        var leftInner = Path()
        leftInner.move(to: CGPoint(x: 114, y: 250))
        leftInner.addCurve(
            to: CGPoint(x: 112, y: 198),
            control1: CGPoint(x: 107, y: 224),
            control2: CGPoint(x: 107, y: 206)
        )
        leftInner.addCurve(
            to: CGPoint(x: 122, y: 207),
            control1: CGPoint(x: 115, y: 194),
            control2: CGPoint(x: 120, y: 197)
        )
        leftInner.addCurve(
            to: CGPoint(x: 127, y: 250),
            control1: CGPoint(x: 125, y: 222),
            control2: CGPoint(x: 126, y: 240)
        )
        leftInner.closeSubpath()
        context.fill(leftInner, with: .color(theme.joeyInnerEar.opacity(0.9)))

        var right = Path()
        right.move(to: CGPoint(x: 142, y: 256))
        right.addCurve(
            to: CGPoint(x: 170, y: 194),
            control1: CGPoint(x: 148, y: 226),
            control2: CGPoint(x: 158, y: 202)
        )
        right.addCurve(
            to: CGPoint(x: 185, y: 208),
            control1: CGPoint(x: 178, y: 189),
            control2: CGPoint(x: 187, y: 196)
        )
        right.addCurve(
            to: CGPoint(x: 170, y: 256),
            control1: CGPoint(x: 182, y: 224),
            control2: CGPoint(x: 174, y: 242)
        )
        right.closeSubpath()
        context.fill(right, with: .color(theme.joeyBody))

        var rightInner = Path()
        rightInner.move(to: CGPoint(x: 148, y: 250))
        rightInner.addCurve(
            to: CGPoint(x: 170, y: 204),
            control1: CGPoint(x: 153, y: 228),
            control2: CGPoint(x: 161, y: 210)
        )
        rightInner.addCurve(
            to: CGPoint(x: 178, y: 213),
            control1: CGPoint(x: 175, y: 201),
            control2: CGPoint(x: 179, y: 205)
        )
        rightInner.addCurve(
            to: CGPoint(x: 166, y: 250),
            control1: CGPoint(x: 175, y: 226),
            control2: CGPoint(x: 169, y: 240)
        )
        rightInner.closeSubpath()
        context.fill(rightInner, with: .color(theme.joeyInnerEar.opacity(0.9)))
    }

    private func drawLyingPaws(_ context: inout GraphicsContext) {
        fillEllipse(&context, cx: 106, cy: 346, rx: 24, ry: 11, color: theme.joeyPaw)
        fillEllipse(&context, cx: 148, cy: 350, rx: 24, ry: 11, color: theme.joeyPaw)

        var leftToe = Path()
        leftToe.move(to: CGPoint(x: 96, y: 348))
        leftToe.addCurve(
            to: CGPoint(x: 110, y: 348),
            control1: CGPoint(x: 100, y: 344),
            control2: CGPoint(x: 106, y: 344)
        )
        context.stroke(
            leftToe,
            with: .color(theme.joeyShade),
            style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
        )

        var rightToe = Path()
        rightToe.move(to: CGPoint(x: 138, y: 352))
        rightToe.addCurve(
            to: CGPoint(x: 152, y: 352),
            control1: CGPoint(x: 142, y: 348),
            control2: CGPoint(x: 148, y: 348)
        )
        context.stroke(
            rightToe,
            with: .color(theme.joeyShade),
            style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
        )
    }

    // MARK: - Sitting

    func drawSitting(
        in context: inout GraphicsContext,
        face: NestFace,
        arms: NestArms,
        armsOpacity: Double = 1,
        waveAngle: Double = 0,
        bodyRotation: Double = 0,
        bodyOffset: CGSize = .zero,
        bodyScaleY: CGFloat = 1,
        breath: CGFloat = 1,
        tailAngle: Double = 0,
        opacity: Double = 1
    ) {
        context.drawLayer { layer in
            layer.opacity = opacity
            layer.translateBy(x: bodyOffset.width, y: bodyOffset.height)

            if bodyScaleY != 1 || breath != 1 {
                layer.translateBy(x: 160, y: 388)
                layer.scaleBy(x: 1, y: bodyScaleY * breath)
                layer.translateBy(x: -160, y: -388)
            }
            if bodyRotation != 0 {
                layer.translateBy(x: 160, y: 388)
                layer.rotate(by: .degrees(bodyRotation))
                layer.translateBy(x: -160, y: -388)
            }

            drawSittingBody(&layer, tailAngle: tailAngle)
            drawSittingArms(
                in: &layer,
                arms: arms,
                opacity: armsOpacity,
                waveAngle: waveAngle
            )
            drawFace(face, in: &layer)
        }
    }

    private func drawSittingBody(_ context: inout GraphicsContext, tailAngle: Double) {
        fillEllipse(
            &context,
            cx: 160,
            cy: 352,
            rx: 94,
            ry: 12,
            color: theme.joeyEye,
            opacity: 0.08
        )

        var tail = Path()
        tail.move(to: CGPoint(x: 228, y: 314))
        tail.addCurve(
            to: CGPoint(x: 290, y: 272),
            control1: CGPoint(x: 268, y: 324),
            control2: CGPoint(x: 294, y: 300)
        )
        tail.addCurve(
            to: CGPoint(x: 256, y: 256),
            control1: CGPoint(x: 287, y: 250),
            control2: CGPoint(x: 266, y: 244)
        )
        tail.addCurve(
            to: CGPoint(x: 269, y: 277),
            control1: CGPoint(x: 248, y: 266),
            control2: CGPoint(x: 256, y: 280)
        )
        context.drawLayer { tailLayer in
            tailLayer.translateBy(x: 250, y: 286)
            tailLayer.rotate(by: .degrees(tailAngle))
            tailLayer.translateBy(x: -250, y: -286)
            tailLayer.stroke(
                tail,
                with: .color(theme.joeyTail),
                style: StrokeStyle(lineWidth: 23, lineCap: .round)
            )
        }

        var leftEar = Path()
        leftEar.move(to: CGPoint(x: 118, y: 148))
        leftEar.addCurve(
            to: CGPoint(x: 93, y: 68),
            control1: CGPoint(x: 100, y: 126),
            control2: CGPoint(x: 88, y: 90)
        )
        leftEar.addCurve(
            to: CGPoint(x: 126, y: 62),
            control1: CGPoint(x: 97, y: 50),
            control2: CGPoint(x: 116, y: 46)
        )
        leftEar.addCurve(
            to: CGPoint(x: 146, y: 140),
            control1: CGPoint(x: 138, y: 80),
            control2: CGPoint(x: 144, y: 116)
        )
        leftEar.closeSubpath()
        context.fill(leftEar, with: .color(theme.joeyBody))

        var leftInner = Path()
        leftInner.move(to: CGPoint(x: 120, y: 136))
        leftInner.addCurve(
            to: CGPoint(x: 105, y: 80),
            control1: CGPoint(x: 108, y: 118),
            control2: CGPoint(x: 101, y: 94)
        )
        leftInner.addCurve(
            to: CGPoint(x: 122, y: 78),
            control1: CGPoint(x: 108, y: 70),
            control2: CGPoint(x: 117, y: 69)
        )
        leftInner.addCurve(
            to: CGPoint(x: 136, y: 132),
            control1: CGPoint(x: 129, y: 90),
            control2: CGPoint(x: 134, y: 114)
        )
        leftInner.closeSubpath()
        context.fill(leftInner, with: .color(theme.joeyInnerEar))

        var rightEar = Path()
        rightEar.move(to: CGPoint(x: 202, y: 148))
        rightEar.addCurve(
            to: CGPoint(x: 227, y: 68),
            control1: CGPoint(x: 220, y: 126),
            control2: CGPoint(x: 232, y: 90)
        )
        rightEar.addCurve(
            to: CGPoint(x: 194, y: 62),
            control1: CGPoint(x: 223, y: 50),
            control2: CGPoint(x: 204, y: 46)
        )
        rightEar.addCurve(
            to: CGPoint(x: 174, y: 140),
            control1: CGPoint(x: 182, y: 80),
            control2: CGPoint(x: 176, y: 116)
        )
        rightEar.closeSubpath()
        context.fill(rightEar, with: .color(theme.joeyBody))

        var rightInner = Path()
        rightInner.move(to: CGPoint(x: 200, y: 136))
        rightInner.addCurve(
            to: CGPoint(x: 215, y: 80),
            control1: CGPoint(x: 212, y: 118),
            control2: CGPoint(x: 219, y: 94)
        )
        rightInner.addCurve(
            to: CGPoint(x: 198, y: 78),
            control1: CGPoint(x: 212, y: 70),
            control2: CGPoint(x: 203, y: 69)
        )
        rightInner.addCurve(
            to: CGPoint(x: 184, y: 132),
            control1: CGPoint(x: 191, y: 90),
            control2: CGPoint(x: 186, y: 114)
        )
        rightInner.closeSubpath()
        context.fill(rightInner, with: .color(theme.joeyInnerEar))

        var body = Path()
        body.move(to: CGPoint(x: 160, y: 116))
        body.addCurve(
            to: CGPoint(x: 242, y: 231),
            control1: CGPoint(x: 209, y: 116),
            control2: CGPoint(x: 242, y: 167)
        )
        body.addCurve(
            to: CGPoint(x: 160, y: 342),
            control1: CGPoint(x: 242, y: 299),
            control2: CGPoint(x: 208, y: 342)
        )
        body.addCurve(
            to: CGPoint(x: 78, y: 231),
            control1: CGPoint(x: 112, y: 342),
            control2: CGPoint(x: 78, y: 299)
        )
        body.addCurve(
            to: CGPoint(x: 160, y: 116),
            control1: CGPoint(x: 78, y: 167),
            control2: CGPoint(x: 111, y: 116)
        )
        body.closeSubpath()
        context.fill(body, with: .color(theme.joeyBody))

        var belly = Path()
        belly.move(to: CGPoint(x: 160, y: 342))
        belly.addCurve(
            to: CGPoint(x: 78, y: 231),
            control1: CGPoint(x: 112, y: 342),
            control2: CGPoint(x: 78, y: 299)
        )
        belly.addCurve(
            to: CGPoint(x: 79, y: 212),
            control1: CGPoint(x: 78, y: 224),
            control2: CGPoint(x: 78, y: 218)
        )
        belly.addCurve(
            to: CGPoint(x: 160, y: 322),
            control1: CGPoint(x: 93, y: 298),
            control2: CGPoint(x: 118, y: 322)
        )
        belly.addCurve(
            to: CGPoint(x: 241, y: 212),
            control1: CGPoint(x: 202, y: 322),
            control2: CGPoint(x: 227, y: 298)
        )
        belly.addCurve(
            to: CGPoint(x: 242, y: 231),
            control1: CGPoint(x: 242, y: 218),
            control2: CGPoint(x: 242, y: 224)
        )
        belly.addCurve(
            to: CGPoint(x: 160, y: 342),
            control1: CGPoint(x: 242, y: 299),
            control2: CGPoint(x: 208, y: 342)
        )
        belly.closeSubpath()
        context.fill(belly, with: .color(theme.joeyShade.opacity(0.5)))

        fillEllipse(&context, cx: 128, cy: 337, rx: 27, ry: 13, color: theme.joeyPaw)
        fillEllipse(&context, cx: 192, cy: 337, rx: 27, ry: 13, color: theme.joeyPaw)

        var scarf = Path()
        scarf.move(to: CGPoint(x: 122, y: 250))
        scarf.addCurve(
            to: CGPoint(x: 198, y: 250),
            control1: CGPoint(x: 142, y: 264),
            control2: CGPoint(x: 178, y: 264)
        )
        context.stroke(
            scarf,
            with: .color(theme.joeyScarf),
            style: StrokeStyle(lineWidth: 9, lineCap: .round)
        )
        fillEllipse(&context, cx: 200, cy: 253, rx: 7, ry: 7, color: theme.joeyScarf)
    }

    func drawSittingArms(
        in context: inout GraphicsContext,
        arms: NestArms,
        opacity: Double = 1,
        waveAngle: Double = 0
    ) {
        context.drawLayer { layer in
            layer.opacity = opacity
            switch arms {
            case .rest:
                drawRestArm(&layer, cx: 84, cy: 262, angle: 10)
                drawRestArm(&layer, cx: 236, cy: 262, angle: -10)

            case .up:
                var left = Path()
                left.move(to: CGPoint(x: 112, y: 250))
                left.addCurve(
                    to: CGPoint(x: 84, y: 168),
                    control1: CGPoint(x: 96, y: 222),
                    control2: CGPoint(x: 88, y: 194)
                )
                drawArmStroke(&layer, left, width: 28)

                var right = Path()
                right.move(to: CGPoint(x: 208, y: 250))
                right.addCurve(
                    to: CGPoint(x: 236, y: 168),
                    control1: CGPoint(x: 224, y: 222),
                    control2: CGPoint(x: 232, y: 194)
                )
                drawArmStroke(&layer, right, width: 28)
                drawPaw(&layer, cx: 84, cy: 164, rx: 14, ry: 14)
                drawPaw(&layer, cx: 236, cy: 164, rx: 14, ry: 14)

            case .wave:
                drawRestArm(&layer, cx: 84, cy: 262, angle: 10)
                layer.drawLayer { arm in
                    arm.translateBy(x: 236, y: 262)
                    arm.rotate(by: .degrees(waveAngle))
                    arm.translateBy(x: -236, y: -262)

                    var right = Path()
                    right.move(to: CGPoint(x: 226, y: 258))
                    right.addCurve(
                        to: CGPoint(x: 251, y: 174),
                        control1: CGPoint(x: 244, y: 224),
                        control2: CGPoint(x: 251, y: 196)
                    )
                    drawArmStroke(&arm, right, width: 28)
                    drawPaw(&arm, cx: 251, cy: 168, rx: 15, ry: 15)
                }

            case .groom:
                drawRestArm(&layer, cx: 84, cy: 262, angle: 10)
                layer.drawLayer { arm in
                    arm.translateBy(x: 236, y: 262)
                    arm.rotate(by: .degrees(waveAngle))
                    arm.translateBy(x: -236, y: -262)

                    var right = Path()
                    right.move(to: CGPoint(x: 226, y: 258))
                    right.addCurve(
                        to: CGPoint(x: 238, y: 190),
                        control1: CGPoint(x: 240, y: 232),
                        control2: CGPoint(x: 243, y: 208)
                    )
                    drawArmStroke(&arm, right, width: 28)
                    drawPaw(&arm, cx: 236, cy: 185, rx: 15, ry: 15)
                }
            }
        }
    }

    private func drawArmStroke(
        _ context: inout GraphicsContext,
        _ path: Path,
        width: CGFloat
    ) {
        context.stroke(
            path,
            with: .color(theme.joeyShade.opacity(0.35)),
            style: StrokeStyle(lineWidth: width + 2, lineCap: .round)
        )
        context.stroke(
            path,
            with: .color(theme.joeyArm),
            style: StrokeStyle(lineWidth: width, lineCap: .round)
        )
    }

    private func drawPaw(
        _ context: inout GraphicsContext,
        cx: CGFloat,
        cy: CGFloat,
        rx: CGFloat,
        ry: CGFloat
    ) {
        let path = Path(
            ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2)
        )
        context.fill(path, with: .color(theme.joeyPaw))
        context.stroke(
            path,
            with: .color(theme.joeyShade.opacity(0.35)),
            style: StrokeStyle(lineWidth: 1.2)
        )
    }

    private func drawRestArm(
        _ context: inout GraphicsContext,
        cx: CGFloat,
        cy: CGFloat,
        angle: Double
    ) {
        let ellipse = Path(ellipseIn: CGRect(x: -18, y: -28, width: 36, height: 56))
        let transform = CGAffineTransform(translationX: cx, y: cy)
            .rotated(by: CGFloat.pi * CGFloat(angle) / 180)
        let path = ellipse.applying(transform)
        context.fill(path, with: .color(theme.joeyArm))
        context.stroke(
            path,
            with: .color(theme.joeyShade.opacity(0.35)),
            style: StrokeStyle(lineWidth: 1.2)
        )
    }

    // MARK: - Faces

    private func drawFace(_ face: NestFace, in context: inout GraphicsContext) {
        switch face {
        case .calm:
            drawBlush(&context, y: 226, opacity: 0.26)
            drawOpenEye(&context, cx: 134, cy: 204, highlight: CGPoint(x: 131, y: 200))
            drawOpenEye(&context, cx: 186, cy: 204, highlight: CGPoint(x: 183, y: 200))
            fillPath(&context, nosePath(y: 216), theme.joeyNose)
            drawCalmMouth(&context)

        case .look:
            drawBlush(&context, y: 226, opacity: 0.28)
            drawOpenEye(
                &context,
                cx: 133,
                cy: 204,
                highlight: CGPoint(x: 128.5, y: 199.5),
                highlightRadius: 2.9
            )
            drawOpenEye(
                &context,
                cx: 185,
                cy: 204,
                highlight: CGPoint(x: 180.5, y: 199.5),
                highlightRadius: 2.9
            )
            var brow = Path()
            brow.move(to: CGPoint(x: 122, y: 189))
            brow.addCurve(
                to: CGPoint(x: 141, y: 188),
                control1: CGPoint(x: 128, y: 185),
                control2: CGPoint(x: 136, y: 185)
            )
            context.stroke(
                brow,
                with: .color(Color(hex: 0xDCC3A6)),
                style: StrokeStyle(lineWidth: 2.6, lineCap: .round)
            )
            fillPath(&context, nosePath(y: 216), theme.joeyNose)
            drawCalmMouth(&context)

        case .happy:
            drawBlush(&context, y: 228, opacity: 0.36)
            drawHappyEyes(&context, y: 207)
            fillPath(&context, nosePath(y: 214), theme.joeyNose)
            var mouth = Path()
            mouth.move(to: CGPoint(x: 150, y: 226))
            mouth.addCurve(
                to: CGPoint(x: 170, y: 226),
                control1: CGPoint(x: 152, y: 238),
                control2: CGPoint(x: 168, y: 238)
            )
            mouth.closeSubpath()
            context.fill(mouth, with: .color(theme.joeyMouth))

        case .stretch:
            drawBlush(&context, y: 228, opacity: 0.3)
            drawHappyEyes(&context, y: 207)
            fillPath(&context, nosePath(y: 214), theme.joeyNose)
            var mouth = Path()
            mouth.move(to: CGPoint(x: 153, y: 228))
            mouth.addCurve(
                to: CGPoint(x: 167, y: 228),
                control1: CGPoint(x: 156, y: 232),
                control2: CGPoint(x: 164, y: 232)
            )
            context.stroke(
                mouth,
                with: .color(theme.joeyMouth),
                style: StrokeStyle(lineWidth: 2.4, lineCap: .round)
            )

        case .yawn:
            drawBlush(&context, y: 230, opacity: 0.34)
            drawHappyEyes(&context, y: 204)
            fillPath(&context, nosePath(y: 212), theme.joeyNose)
            fillEllipse(&context, cx: 160, cy: 232, rx: 13, ry: 16, color: theme.joeyMouth)
            fillEllipse(&context, cx: 160, cy: 239, rx: 8, ry: 6.5, color: theme.joeyNose)

        case .doze:
            drawBlush(&context, y: 228, opacity: 0.2, rx: 17, ry: 8)
            drawClosedEyes(
                &context,
                left: [
                    (CGPoint(x: 125, y: 206), CGPoint(x: 133, y: 215), CGPoint(x: 143, y: 215), CGPoint(x: 149, y: 206))
                ],
                right: [
                    (CGPoint(x: 171, y: 206), CGPoint(x: 179, y: 215), CGPoint(x: 189, y: 215), CGPoint(x: 195, y: 206))
                ],
                width: 3.4
            )
            fillPath(&context, nosePath(y: 218), theme.joeyNose)
            var mouth = Path()
            mouth.move(to: CGPoint(x: 155, y: 232))
            mouth.addCurve(
                to: CGPoint(x: 165, y: 232),
                control1: CGPoint(x: 158, y: 235),
                control2: CGPoint(x: 162, y: 235)
            )
            context.stroke(
                mouth,
                with: .color(theme.joeyMouth),
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
            )

        case .groom:
            drawBlush(&context, y: 226, opacity: 0.26)
            drawClosedEyes(
                &context,
                left: [
                    (CGPoint(x: 125, y: 202), CGPoint(x: 131, y: 210), CGPoint(x: 141, y: 210), CGPoint(x: 147, y: 202))
                ],
                right: [
                    (CGPoint(x: 173, y: 202), CGPoint(x: 179, y: 210), CGPoint(x: 189, y: 210), CGPoint(x: 195, y: 202))
                ],
                width: 3.6
            )
            fillPath(&context, nosePath(y: 216), theme.joeyNose)
            var mouth = Path()
            mouth.move(to: CGPoint(x: 155, y: 230))
            mouth.addCurve(
                to: CGPoint(x: 165, y: 230),
                control1: CGPoint(x: 158, y: 233),
                control2: CGPoint(x: 162, y: 233)
            )
            context.stroke(
                mouth,
                with: .color(theme.joeyMouth),
                style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
            )

        case .sleep:
            drawBlush(&context, y: 226, opacity: 0.22)
            drawClosedEyes(
                &context,
                left: [
                    (CGPoint(x: 124, y: 208), CGPoint(x: 132, y: 216), CGPoint(x: 144, y: 216), CGPoint(x: 152, y: 208))
                ],
                right: [
                    (CGPoint(x: 168, y: 208), CGPoint(x: 176, y: 216), CGPoint(x: 188, y: 216), CGPoint(x: 196, y: 208))
                ],
                width: 3.4
            )
            fillPath(&context, nosePath(y: 220), theme.joeyNose)
            var mouth = Path()
            mouth.move(to: CGPoint(x: 156, y: 234))
            mouth.addCurve(
                to: CGPoint(x: 167, y: 234),
                control1: CGPoint(x: 159, y: 237),
                control2: CGPoint(x: 164, y: 237)
            )
            context.stroke(
                mouth,
                with: .color(theme.joeyMouth),
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
            )

        case .blink2:
            drawBlush(&context, y: 226, opacity: 0.24)
            drawClosedEyes(
                &context,
                left: [
                    (CGPoint(x: 126, y: 202), CGPoint(x: 132, y: 199), CGPoint(x: 142, y: 199), CGPoint(x: 148, y: 202)),
                    (CGPoint(x: 126, y: 208), CGPoint(x: 132, y: 211), CGPoint(x: 142, y: 211), CGPoint(x: 148, y: 208))
                ],
                right: [
                    (CGPoint(x: 173, y: 202), CGPoint(x: 179, y: 199), CGPoint(x: 189, y: 199), CGPoint(x: 195, y: 202)),
                    (CGPoint(x: 173, y: 208), CGPoint(x: 179, y: 211), CGPoint(x: 189, y: 211), CGPoint(x: 195, y: 208))
                ],
                width: 3
            )
            fillPath(&context, nosePath(y: 216), theme.joeyNose)
            drawCalmMouth(&context)

        case .blink3:
            drawBlush(&context, y: 226, opacity: 0.24)
            drawClosedEyes(
                &context,
                left: [
                    (CGPoint(x: 126, y: 203), CGPoint(x: 132, y: 210), CGPoint(x: 142, y: 210), CGPoint(x: 148, y: 203))
                ],
                right: [
                    (CGPoint(x: 173, y: 203), CGPoint(x: 179, y: 210), CGPoint(x: 189, y: 210), CGPoint(x: 195, y: 203))
                ],
                width: 3.4
            )
            fillPath(&context, nosePath(y: 216), theme.joeyNose)
            drawCalmMouth(&context)
        }
    }

    private func drawBlush(
        _ context: inout GraphicsContext,
        y: CGFloat,
        opacity: Double,
        rx: CGFloat = 18,
        ry: CGFloat = 9
    ) {
        fillEllipse(
            &context,
            cx: 111,
            cy: y,
            rx: rx,
            ry: ry,
            color: theme.joeyBlush,
            opacity: opacity
        )
        fillEllipse(
            &context,
            cx: 209,
            cy: y,
            rx: rx,
            ry: ry,
            color: theme.joeyBlush,
            opacity: opacity
        )
    }

    private func drawOpenEye(
        _ context: inout GraphicsContext,
        cx: CGFloat,
        cy: CGFloat,
        rx: CGFloat = 8.5,
        ry: CGFloat = 11,
        highlight: CGPoint,
        highlightRadius: CGFloat = 2.8
    ) {
        fillEllipse(&context, cx: cx, cy: cy, rx: rx, ry: ry, color: theme.joeyEye)
        fillEllipse(
            &context,
            cx: highlight.x,
            cy: highlight.y,
            rx: highlightRadius,
            ry: highlightRadius,
            color: .white
        )
    }

    private func drawHappyEyes(_ context: inout GraphicsContext, y: CGFloat) {
        var left = Path()
        left.move(to: CGPoint(x: 124, y: y))
        left.addCurve(
            to: CGPoint(x: 147, y: y),
            control1: CGPoint(x: 130, y: y - 9),
            control2: CGPoint(x: 141, y: y - 9)
        )
        context.stroke(
            left,
            with: .color(theme.joeyEye),
            style: StrokeStyle(lineWidth: 4, lineCap: .round)
        )

        var right = Path()
        right.move(to: CGPoint(x: 173, y: y))
        right.addCurve(
            to: CGPoint(x: 196, y: y),
            control1: CGPoint(x: 179, y: y - 9),
            control2: CGPoint(x: 190, y: y - 9)
        )
        context.stroke(
            right,
            with: .color(theme.joeyEye),
            style: StrokeStyle(lineWidth: 4, lineCap: .round)
        )
    }

    private func drawClosedEyes(
        _ context: inout GraphicsContext,
        left: [(CGPoint, CGPoint, CGPoint, CGPoint)],
        right: [(CGPoint, CGPoint, CGPoint, CGPoint)],
        width: CGFloat
    ) {
        var path = Path()
        for segment in left + right {
            path.move(to: segment.0)
            path.addCurve(to: segment.3, control1: segment.1, control2: segment.2)
        }
        context.stroke(
            path,
            with: .color(theme.joeyEye),
            style: StrokeStyle(lineWidth: width, lineCap: .round)
        )
    }

    private func drawCalmMouth(_ context: inout GraphicsContext) {
        var mouth = Path()
        mouth.move(to: CGPoint(x: 160, y: 224))
        mouth.addCurve(
            to: CGPoint(x: 150, y: 228),
            control1: CGPoint(x: 158, y: 230),
            control2: CGPoint(x: 153, y: 232)
        )
        mouth.move(to: CGPoint(x: 160, y: 224))
        mouth.addCurve(
            to: CGPoint(x: 170, y: 228),
            control1: CGPoint(x: 162, y: 230),
            control2: CGPoint(x: 167, y: 232)
        )
        context.stroke(
            mouth,
            with: .color(theme.joeyMouth),
            style: StrokeStyle(lineWidth: 2.3, lineCap: .round)
        )
    }

    // MARK: - Z

    /// The `Z`s breathe with Joey instead of drifting up: each glyph fades in
    /// and settles back in place on the same slow cycle as the body.
    func drawZ(
        in context: inout GraphicsContext,
        elapsed: TimeInterval,
        count: Int,
        period: TimeInterval = 6,
        reduceMotion: Bool
    ) {
        if reduceMotion {
            drawZGlyph(
                in: &context,
                at: CGPoint(x: 214, y: 212),
                scale: 0.7,
                opacity: 0.35,
                rotation: 0
            )
            return
        }

        let anchors: [CGPoint] = [
            CGPoint(x: 194, y: 230),
            CGPoint(x: 214, y: 212),
            CGPoint(x: 236, y: 195)
        ]
        let sizes: [Double] = [0.62, 0.8, 1.0]
        let rotations: [Double] = [-4, -2, 0]

        for index in 0..<min(count, anchors.count) {
            let phase = (elapsed / period + Double(index) * 0.12)
                .truncatingRemainder(dividingBy: 1)
            let intensity = 0.5 - 0.5 * cos(2 * .pi * phase)
            guard intensity > 0.02 else { continue }

            drawZGlyph(
                in: &context,
                at: anchors[index],
                scale: sizes[index] * (0.9 + 0.1 * intensity),
                opacity: intensity * 0.45,
                rotation: rotations[index]
            )
        }
    }

    private func drawZGlyph(
        in context: inout GraphicsContext,
        at point: CGPoint,
        scale: Double,
        opacity: Double,
        rotation: Double
    ) {
        context.drawLayer { layer in
            layer.translateBy(x: point.x, y: point.y)
            layer.rotate(by: .degrees(rotation))
            layer.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
            layer.opacity = opacity

            var path = Path()
            path.move(to: CGPoint(x: -9, y: -13))
            path.addLine(to: CGPoint(x: 9, y: -13))
            path.addLine(to: CGPoint(x: -8, y: 8))
            path.addLine(to: CGPoint(x: 10, y: 8))
            layer.stroke(
                path,
                with: .color(theme.mistDeep),
                style: StrokeStyle(lineWidth: 5.5, lineCap: .round, lineJoin: .round)
            )
        }
    }

    // MARK: - Helpers

    private func nosePath(y: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 160, y: y))
        path.addCurve(
            to: CGPoint(x: 166.5, y: y + 7),
            control1: CGPoint(x: 166, y: y),
            control2: CGPoint(x: 169, y: y + 4)
        )
        path.addCurve(
            to: CGPoint(x: 153.5, y: y + 7),
            control1: CGPoint(x: 164.5, y: y + 9.5),
            control2: CGPoint(x: 155.5, y: y + 9.5)
        )
        path.addCurve(
            to: CGPoint(x: 160, y: y),
            control1: CGPoint(x: 151, y: y + 4),
            control2: CGPoint(x: 154, y: y)
        )
        path.closeSubpath()
        return path
    }

    private func fillEllipse(
        _ context: inout GraphicsContext,
        cx: CGFloat,
        cy: CGFloat,
        rx: CGFloat,
        ry: CGFloat,
        color: Color,
        opacity: Double = 1
    ) {
        context.fill(
            Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2)),
            with: .color(color.opacity(opacity))
        )
    }

    private func fillPath(
        _ context: inout GraphicsContext,
        _ path: Path,
        _ color: Color,
        opacity: Double = 1
    ) {
        context.fill(path, with: .color(color.opacity(opacity)))
    }
}
