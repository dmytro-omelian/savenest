import Foundation

// Safari has no stable scriptable tab ID. Require the original position and a
// unique URL; leave ambiguous, moved, or navigated tabs open rather than guessing.
enum TabCloseScript {
    static let script = #"""
    function closeCapturedTab(app, target) {
        if (!app.running()) return false;
        const windows = app.windows();
        const w = windows.find(w => w.id() === target.windowID);
        if (!w) return false;
        const tabs = w.tabs();
        let tab;
        if (target.safari) {
            const matches = tabs.filter(t => t.url() === target.url);
            if (matches.length !== 1 || !tabs[target.index] || tabs[target.index].url() !== target.url) return false;
            tab = tabs[target.index];
        } else {
            tab = tabs.find(t => t.id() === target.tabID && t.url() === target.url);
        }
        if (!tab || tab.url() !== target.url) return false;
        tab.close();
        return true;
    }
    """#
}
