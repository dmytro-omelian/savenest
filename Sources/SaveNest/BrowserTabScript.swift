import Foundation

enum BrowserTabScript {
    static let script = #"""
    function readBrowserTabs(app, browser) {
        if (!app.running()) return [];
        const result = [];
        app.windows().forEach(function(w) {
            const windowID = String(w.id());
            w.tabs().forEach(function(t, i) {
                try {
                    const url = t.url() || '';
                    if (!/^https?:/i.test(url)) return;
                    result.push({browserID:browser.id, browserName:browser.name,
                        windowID:windowID, tabID:browser.safari ? '' : String(t.id()),
                        index:i + 1, title:(browser.safari ? t.name() : t.title()) || url, url:url});
                } catch (error) {
                    // A closed tab may disappear during enumeration; permission failures must surface.
                    if (error.errorNumber !== -1728) throw error;
                }
            });
        });
        return result;
    }
    function isKnownEmptyBrowserTab(url) {
        const value = String(url || '').toLowerCase().replace(/\/$/, '');
        return ['', 'about:blank', 'about:newtab', 'chrome://newtab', 'chrome://new-tab-page',
            'edge://newtab', 'brave://newtab', 'vivaldi://newtab', 'opera://startpage',
            'favorites:/', 'safari://favorites', 'arc://new-tab'].includes(value);
    }
    function readBrowserTabsForCleanup(app, browser) {
        if (!app.running()) return [];
        const result = [];
        app.windows().forEach(function(w, windowOffset) {
            const windowID = String(w.id());
            let activeIndex = -1;
            try { activeIndex = Number(browser.safari ? w.currentTab.index() : w.activeTabIndex()); } catch (_) {}
            w.tabs().forEach(function(t, i) {
                try {
                    const url = t.url() || '';
                    let title = url || 'Empty tab';
                    try { title = (browser.safari ? t.name() : t.title()) || title; } catch (_) {}
                    result.push({browserID:browser.id, browserName:browser.name,
                        windowID:windowID, windowIndex:windowOffset + 1,
                        tabID:browser.safari ? '' : String(t.id()), index:i + 1,
                        title:title, url:url,
                        isActive:activeIndex === i + 1, isEmpty:isKnownEmptyBrowserTab(url)});
                } catch (error) {
                    if (error.errorNumber !== -1728) throw error;
                }
            });
        });
        return result;
    }
    function activateBrowserTab(app, target) {
        if (!app.running()) return false;
        const windows = app.windows();
        for (let i = 0; i < windows.length; i++) {
            const w = windows[i];
            if (String(w.id()) !== target.windowID) continue;
            const tabs = w.tabs();
            let index = -1;
            if (target.safari) {
                const original = target.index - 1;
                if (tabs[original] && tabs[original].url() === target.url) index = original;
                else index = tabs.findIndex(t => t.url() === target.url);
            } else {
                index = tabs.findIndex(t => String(t.id()) === target.tabID && t.url() === target.url);
            }
            if (index < 0) return false;
            if (target.safari) w.currentTab = tabs[index];
            else w.activeTabIndex = index + 1;
            try { w.minimized = false; } catch (_) {}
            w.index = 1;
            app.activate();
            return true;
        }
        return false;
    }
    """#
}
