import CoreGraphics
import Testing
@testable import JoeyPet

// Geometry contract for the isolated Mac Care Stage prototype (Unit 1).
//
// These assert the invariants the design depends on across the compact / regular / large
// window tiers: the body never collides with the info block or the bottom controls, the
// action chip stays fully above the dock, the info width is capped on wide windows, and
// the big window gets a genuinely bigger Stage. All values derive from the window size.
#if DEBUG
@MainActor
struct CalmSpaceStageLayoutTests {
    private struct Sample {
        let name: String
        let size: CGSize
        let compact: Bool
        let large: Bool
        let diameterRange: ClosedRange<CGFloat>
    }

    private let samples: [Sample] = [
        Sample(name: "compact", size: CGSize(width: 680, height: 512), compact: true, large: false, diameterRange: 200...240),
        // A short regular window: fit wins over the tier target, so the body shrinks.
        Sample(name: "regular-short", size: CGSize(width: 800, height: 560), compact: false, large: false, diameterRange: 190...340),
        Sample(name: "regular-wide", size: CGSize(width: 1024, height: 680), compact: false, large: false, diameterRange: 300...340),
        Sample(name: "large", size: CGSize(width: 1600, height: 900), compact: false, large: true, diameterRange: 400...440),
    ]

    /// A deliberately conservative tallest-possible info block: a two-line headline, a
    /// two-line detail, the reserved activity slot and the action chip, plus every gap.
    /// Mirrors the font-size / spacing constants in `MacCareStageView`.
    private func worstCaseBlockHeight(_ l: CalmSpaceStageLayout) -> CGFloat {
        let connector = l.connectorHeight
        let gapHeadline = l.compact ? 9.0 : 12.0
        let headline = 2 * l.headlineSize * 1.25
        let gapDetail = l.compact ? 7.0 : 9.0
        let detail = 2 * l.detailSize * 1.3 + 3
        let gapActivity = l.compact ? 8.0 : 10.0
        let activity = l.activitySlotHeight
        let gapContext = l.compact ? 8.0 : 10.0
        let context = l.chipHeight
        return connector + gapHeadline + headline + gapDetail + detail
            + gapActivity + activity + gapContext + context
    }

    @Test func tiersMatchExpectedBuckets() {
        for sample in samples {
            let layout = CalmSpaceStageLayout(size: sample.size)
            #expect(layout.compact == sample.compact, "\(sample.name) compact flag")
            #expect(layout.large == sample.large, "\(sample.name) large flag")
        }
    }

    @Test func bodyDiameterStaysInRange() {
        for sample in samples {
            let layout = CalmSpaceStageLayout(size: sample.size)
            #expect(
                sample.diameterRange.contains(layout.bodyDiameter),
                "\(sample.name) diameter \(layout.bodyDiameter) in \(sample.diameterRange)"
            )
        }
    }

    @Test func bodyNeverOverlapsInfoBlock() {
        for sample in samples {
            let layout = CalmSpaceStageLayout(size: sample.size)
            let bodyBottom = layout.bodyCenter.y + layout.bodyDiameter / 2
            #expect(bodyBottom <= layout.infoTop, "\(sample.name) body bottom \(bodyBottom) <= infoTop \(layout.infoTop)")
        }
    }

    @Test func reservedInfoClearsBottomControls() {
        for sample in samples {
            let layout = CalmSpaceStageLayout(size: sample.size)
            #expect(layout.infoClearsBottomControls, "\(sample.name) reserved info clears controls")
        }
    }

    @Test func longCopyBlockStillClearsBottomControls() {
        // Even the worst-case (long-copy, action-chip) block must stay above the dock.
        for sample in samples {
            let layout = CalmSpaceStageLayout(size: sample.size)
            let actualBottom = layout.infoTop + worstCaseBlockHeight(layout)
            #expect(
                actualBottom <= layout.base.bottomControlsTop,
                "\(sample.name) long-copy bottom \(actualBottom) <= controls top \(layout.base.bottomControlsTop)"
            )
        }
    }

    @Test func infoWidthIsCappedAndCentred() {
        for sample in samples {
            let layout = CalmSpaceStageLayout(size: sample.size)
            #expect(layout.infoWidth <= 520, "\(sample.name) info width \(layout.infoWidth) <= 520")
            #expect(layout.infoWidth <= sample.size.width, "\(sample.name) info fits window")
        }
    }

    @Test func largeWindowGetsAGenuinelyBiggerStage() {
        let layout = CalmSpaceStageLayout(size: CGSize(width: 1600, height: 900))
        #expect(layout.bodyDiameter >= 420, "large body \(layout.bodyDiameter) >= 420")
        #expect(layout.infoWidth <= 520, "large info width capped")
    }

    @Test func compactBodyNeverSmallerThanFloor() {
        let layout = CalmSpaceStageLayout(size: CGSize(width: 680, height: 512))
        #expect(layout.bodyDiameter >= 200, "compact body \(layout.bodyDiameter) >= 200")
    }

    @Test func designBudgetRespectsSpecCeiling() {
        // The normal-copy block budget: regular ≤ 150 pt, compact ≤ 128 pt.
        for sample in samples {
            let layout = CalmSpaceStageLayout(size: sample.size)
            let ceiling: CGFloat = sample.compact ? 128 : 150
            #expect(layout.infoDesignBudget <= ceiling, "\(sample.name) design budget \(layout.infoDesignBudget) <= \(ceiling)")
            // The actual reserve never shrinks below the design budget.
            #expect(layout.infoReservedHeight >= layout.infoDesignBudget, "\(sample.name) reserve >= budget")
        }
    }
}

// MOCK content contract: an action only exists when there is something actionable.
@MainActor
struct MacCareStageContentFixturesTests {
    @Test func normalHasNoAction() {
        let content = StagePrototypeFixtures.macCareContent(state: .normal)
        #expect(content.action == nil)
        #expect(content.level == .normal)
    }

    @Test func attentionAndCriticalExposeActions() {
        let attention = StagePrototypeFixtures.macCareContent(state: .attention)
        let critical = StagePrototypeFixtures.macCareContent(state: .critical)
        #expect(attention.action != nil)
        #expect(critical.action != nil)
    }

    @Test func unknownShowsProgressNotHealth() {
        let content = StagePrototypeFixtures.macCareContent(state: .unknown)
        #expect(content.action == nil)
        #expect(content.progressLabel != nil)
        #expect(content.level == .unknown)
    }

    @Test func activityOverrideKeepsActionSemantics() {
        let content = StagePrototypeFixtures.macCareContent(
            state: .normal,
            activityOverride: StagePrototypeFixtures.scanningActivity
        )
        #expect(content.activity != nil)
        #expect(content.action == nil, "a healthy Mac never shows an action")
    }
}

// Geometry contract for the Work Rhythm "time instrument" Stage (Unit 2).
@MainActor
struct WorkRhythmStageLayoutTests {
    private struct Sample {
        let name: String
        let size: CGSize
        let compact: Bool
        let large: Bool
        let diameterRange: ClosedRange<CGFloat>
    }

    private let samples: [Sample] = [
        Sample(name: "compact", size: CGSize(width: 680, height: 512), compact: true, large: false, diameterRange: 220...250),
        Sample(name: "regular-short", size: CGSize(width: 800, height: 560), compact: false, large: false, diameterRange: 200...380),
        Sample(name: "regular-wide", size: CGSize(width: 1024, height: 680), compact: false, large: false, diameterRange: 340...380),
        Sample(name: "large", size: CGSize(width: 1600, height: 900), compact: false, large: true, diameterRange: 400...440),
    ]

    @Test func deviceDiameterStaysInRange() {
        for sample in samples {
            let l = WorkRhythmStageLayout(size: sample.size)
            #expect(sample.diameterRange.contains(l.deviceDiameter), "\(sample.name) device \(l.deviceDiameter) in \(sample.diameterRange)")
        }
    }

    @Test func deviceNeverOverlapsActionRow() {
        for sample in samples {
            let l = WorkRhythmStageLayout(size: sample.size)
            #expect(l.deviceBottom <= l.actionRowTop, "\(sample.name) device bottom \(l.deviceBottom) <= action row top \(l.actionRowTop)")
        }
    }

    @Test func actionRowClearsBottomControls() {
        for sample in samples {
            let l = WorkRhythmStageLayout(size: sample.size)
            #expect(l.actionClearsBottomControls, "\(sample.name) action row clears dock/mode switch")
        }
    }

    @Test func deviceFitsHorizontally() {
        for sample in samples {
            let l = WorkRhythmStageLayout(size: sample.size)
            #expect(l.deviceDiameter <= sample.size.width, "\(sample.name) device fits width")
        }
    }

    @Test func centreTextStaysInsideInnerCircle() {
        // The central text column (0.66·d) must fit within the inner track circle.
        for sample in samples {
            let l = WorkRhythmStageLayout(size: sample.size)
            #expect(l.deviceDiameter * 0.66 <= l.trackRadius * 2 + 0.5,
                    "\(sample.name) centre text fits inner circle")
        }
    }

    @Test func longCountdownFitsRegularDevice() {
        // `1:02:45` at the rule-based digit size stays within the inner circle width.
        let l = WorkRhythmStageLayout(size: CGSize(width: 1024, height: 680))
        #expect(l.timeFontSize >= 40 && l.timeFontSize <= 72)
        #expect(WorkRhythmStageFixtures.formatDuration(3765) == "1:02:45")
        #expect(WorkRhythmStageFixtures.formatDuration(1476) == "24:36")
        #expect(WorkRhythmStageFixtures.formatDuration(252) == "04:12")
    }

    @Test func largeDeviceIsGenuinelyBigger() {
        let l = WorkRhythmStageLayout(size: CGSize(width: 1600, height: 900))
        #expect(l.deviceDiameter >= 400, "large device \(l.deviceDiameter) >= 400")
    }
}

// Work Rhythm MOCK content contract.
@MainActor
struct WorkRhythmStageContentFixturesTests {
    @Test func idleShowsNoProgressAndSecondDot() {
        let c = WorkRhythmStageFixtures.content(state: .idle)
        #expect(c.progress == 0)
        #expect(c.showSecondDot)
        #expect(!c.showsProgressArc)
        #expect(c.clockText != nil)
    }

    @Test func focusPausedRestCarryProgress() {
        let focus = WorkRhythmStageFixtures.content(state: .focus)
        let paused = WorkRhythmStageFixtures.content(state: .paused)
        let rest = WorkRhythmStageFixtures.content(state: .rest)
        #expect(focus.showsProgressArc && focus.progress > 0 && focus.progress < 1)
        #expect(paused.isPaused)
        #expect(abs(paused.progress - 0.328) < 0.01, "paused 8:12 of 25:00 ≈ 0.33")
        #expect(rest.phase == .rest)
    }

    @Test func completeClosesTheArc() {
        let c = WorkRhythmStageFixtures.content(state: .complete)
        #expect(c.progress == 1)
        #expect(c.wordsText != nil)
    }

    @Test func focusAndRestAccentsAreDistinct() {
        let theme = WorkRhythmStageTheme.dark
        #expect(theme.accent(for: .focus) != theme.accent(for: .rest), "focus and rest must differ")
    }
}
#endif
