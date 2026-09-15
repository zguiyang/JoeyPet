import Foundation

protocol SystemSensor: AnyObject {
    var sensorID: String { get }
    var onSignal: ((SystemSignal) -> Void)? { get set }
    func start()
    func stop()
}
