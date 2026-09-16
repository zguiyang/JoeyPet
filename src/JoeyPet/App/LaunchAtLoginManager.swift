import Foundation
import ServiceManagement

protocol LaunchAtLoginManaging: AnyObject {
    var isRegistered: Bool { get }
    func setRegistered(_ registered: Bool) throws
}

final class LaunchAtLoginManager: LaunchAtLoginManaging {
    var isRegistered: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setRegistered(_ registered: Bool) throws {
        if registered {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
