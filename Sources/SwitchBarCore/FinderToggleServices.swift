import Foundation

public final class FinderDesktopIconService {
    private let preferences: FinderPreferenceManaging
    private let reloader: FinderReloading
    private let reopenPolicy: FinderReopenPolicy

    public init(
        preferences: FinderPreferenceManaging = FinderPreferenceStore(),
        reloader: FinderReloading = FinderReloader(),
        reopenPolicy: FinderReopenPolicy = .reopenIfUserHadFinderWindow
    ) {
        self.preferences = preferences
        self.reloader = reloader
        self.reopenPolicy = reopenPolicy
    }

    public func setDesktopIconsHidden(_ hidden: Bool) -> Bool {
        let createDesktop = hidden == false
        guard preferences.writeBool(createDesktop, key: .createDesktop) else {
            return false
        }
        return reloader.reloadFinder(reopenPolicy: reopenPolicy)
    }

    public func areDesktopIconsHidden() -> Bool {
        preferences.readBool(key: .createDesktop, defaultValue: true) == false
    }
}

public final class FinderHiddenFilesService {
    private let preferences: FinderPreferenceManaging
    private let reloader: FinderReloading
    private let reopenPolicy: FinderReopenPolicy

    public init(
        preferences: FinderPreferenceManaging = FinderPreferenceStore(),
        reloader: FinderReloading = FinderReloader(),
        reopenPolicy: FinderReopenPolicy = .reopenIfUserHadFinderWindow
    ) {
        self.preferences = preferences
        self.reloader = reloader
        self.reopenPolicy = reopenPolicy
    }

    public func setHiddenFilesVisible(_ visible: Bool) -> Bool {
        guard preferences.writeBool(visible, key: .appleShowAllFiles) else {
            return false
        }
        return reloader.reloadFinder(reopenPolicy: reopenPolicy)
    }

    public func areHiddenFilesVisible() -> Bool {
        preferences.readBool(key: .appleShowAllFiles, defaultValue: false)
    }
}
