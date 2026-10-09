import Foundation

// Safari has no stable scriptable tab ID. Require the original position and a
// unique URL; leave ambiguous, moved, or navigated tabs open rather than guessing.
enum TabCloseScript {
    static let script = #"""
    function uniqueSafariTabIndex(w, url) {
        // One Apple Event for the whole collection, rather than one event per tab.
        const urls = w.tabs.url();
        const index = urls.indexOf(url);
        return index >= 0 && urls.lastIndexOf(url) === index ? index : -1;
    }
    function closeCapturedTab(app, target) {
        if (!app.running()) return false;
        const windowIndex = app.windows.id().indexOf(target.windowID);
        if (windowIndex < 0) return false;
        const w = app.windows[windowIndex];
        let tab;
        if (target.safari) {
            if (uniqueSafariTabIndex(w, target.url) !== target.index || target.index < 0) return false;
            tab = w.tabs[target.index];
        } else {
            const index = w.tabs.id().indexOf(target.tabID);
            if (index < 0) return false;
            tab = w.tabs[index];
        }
        // Resolve again immediately before closing; never close a tab that navigated.
        if (!tab || tab.url() !== target.url) return false;
        tab.close();
        return true;
    }
    """#
}
