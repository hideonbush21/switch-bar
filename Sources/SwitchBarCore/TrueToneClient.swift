import Foundation

public protocol TrueToneClient {
    var isSupported: Bool { get }
    var isEnabled: Bool { get }
    func setEnabled(_ value: Bool) -> Bool
}

public final class CoreBrightnessTrueToneClient: TrueToneClient {
    private let clientObject: NSObject?

    private typealias BoolGetter = @convention(c) (NSObject, Selector) -> Bool
    private typealias BoolSetter = @convention(c) (NSObject, Selector, Bool) -> Bool

    public init() {
        let path = "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness"
        guard let _ = dlopen(path, RTLD_NOW),
              let cls = NSClassFromString("CBTrueToneClient") as? NSObject.Type else {
            self.clientObject = nil
            return
        }
        self.clientObject = cls.init()
    }

    public var isSupported: Bool {
        callBool("supported")
    }

    public var isEnabled: Bool {
        callBool("enabled")
    }

    public func setEnabled(_ value: Bool) -> Bool {
        guard let obj = clientObject else { return false }
        let sel = NSSelectorFromString("setEnabled:")
        guard obj.responds(to: sel) else { return false }
        let imp = obj.method(for: sel)
        let fn = unsafeBitCast(imp, to: BoolSetter.self)
        return fn(obj, sel, value)
    }

    private func callBool(_ name: String) -> Bool {
        guard let obj = clientObject else { return false }
        let sel = NSSelectorFromString(name)
        guard obj.responds(to: sel) else { return false }
        let imp = obj.method(for: sel)
        let fn = unsafeBitCast(imp, to: BoolGetter.self)
        return fn(obj, sel)
    }
}
