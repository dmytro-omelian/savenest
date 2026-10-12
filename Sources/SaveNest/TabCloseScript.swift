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
        const windowIndex = app.windows.id().map(String).indexOf(String(target.windowID));
        if (windowIndex < 0) return false;
        const w = app.windows[windowIndex];
        let tab;
        if (target.safari) {
            if (uniqueSafariTabIndex(w, target.url) !== target.index || target.index < 0) return false;
            tab = w.tabs[target.index];
        } else {
            const index = w.tabs.id().map(String).indexOf(String(target.tabID));
            if (index < 0) return false;
            tab = w.tabs[index];
        }
        // Resolve again immediately before closing; never close a tab that navigated.
        if (!tab || tab.url() !== target.url) return false;
        tab.close();
        return true;
    }
    function closeBrowserTabs(app, targets) {
        if (!app.running() || !Array.isArray(targets)) return 0;
        let closed = 0;
        const ordered = targets.slice().sort(function(a, b) {
            if (String(a.windowID) !== String(b.windowID)) return 0;
            return Number(b.index) - Number(a.index);
        });
        ordered.forEach(function(target) {
            try {
                const windowIndex = app.windows.id().map(String).indexOf(String(target.windowID));
                if (windowIndex < 0) return;
                const w = app.windows[windowIndex];
                let tab;
                if (target.safari) {
                    const index = Number(target.index) - 1;
                    if (index < 0 || index >= w.tabs.length) return;
                    tab = w.tabs[index];
                } else {
                    const index = w.tabs.id().map(String).indexOf(String(target.tabID));
                    if (index < 0) return;
                    tab = w.tabs[index];
                }
                if (!tab || String(tab.url() || '') !== String(target.url || '')) return;
                tab.close();
                closed++;
            } catch (_) { /* A moved, closed, or protected tab is left alone. */ }
        });
        return closed;
    }
    """#
}
