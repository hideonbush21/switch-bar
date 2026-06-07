import Combine
import Foundation
import IOKit.pwr_mgt

public final class KeepAwakeToggle: ToggleProvider {
    public let id = "keepAwake"
    public let title = "保持亮屏"
    public let iconName = "cup.and.saucer.fill"
    @Published public var isOn: Bool = false

    private var assertionID: IOPMAssertionID = IOPMAssertionID(kIOPMNullAssertionID)

    public init() {
        refreshState()
    }

    deinit {
        if assertionID != IOPMAssertionID(kIOPMNullAssertionID) {
            IOPMAssertionRelease(assertionID)
        }
    }

    public func apply(newValue: Bool) -> Bool {
        if newValue {
            if assertionID != IOPMAssertionID(kIOPMNullAssertionID) {
                return true
            }

            var newAssertionID = IOPMAssertionID(kIOPMNullAssertionID)
            let reason = "SwitchBar KeepAwake" as CFString
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                reason,
                &newAssertionID
            )
            if result == kIOReturnSuccess {
                assertionID = newAssertionID
                return true
            }
            return false
        }

        if assertionID == IOPMAssertionID(kIOPMNullAssertionID) {
            return true
        }

        let result = IOPMAssertionRelease(assertionID)
        if result == kIOReturnSuccess {
            assertionID = IOPMAssertionID(kIOPMNullAssertionID)
            return true
        }
        return false
    }

    public func refreshState() {
        isOn = assertionID != IOPMAssertionID(kIOPMNullAssertionID)
    }
}
