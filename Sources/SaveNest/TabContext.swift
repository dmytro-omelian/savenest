import Foundation

enum TabContextScript {
    // Read bounded descriptive content only. Never read input values or editable text.
    static let page = #"""
    (() => {
      const clean = value => String(value || '').replace(/\s+/g, ' ').trim();
      const meta = document.querySelector('meta[name="description"],meta[property="og:description"]');
      const parts = [clean(meta?.content).slice(0, 1000)];
      const nodes = document.querySelectorAll('h1,h2,h3,main p,article p,[data-testid="tweetText"]');
      for (let i = 0; i < Math.min(nodes.length, 80); i++) {
        const node = nodes[i];
        if (node.closest('form,input,textarea,select,[contenteditable]:not([contenteditable="false"]),[hidden],[aria-hidden="true"]')) continue;
        if (node.querySelector('input,textarea,select,[contenteditable]:not([contenteditable="false"])')) continue;
        const style = getComputedStyle(node);
        if (style.display === 'none' || style.visibility === 'hidden' || node.getClientRects().length === 0) continue;
        parts.push(clean(node.innerText).slice(0, 500));
        if (parts.join(' ').length >= 8000) break;
      }
      return JSON.stringify({url: location.href, text: parts.filter(Boolean).join(' ').slice(0, 8000)});
    })()
    """#

    static let reader = #"""
    function readTabContexts(app, targets, safari, source) {
      if (!app.running()) return {contexts: [], blocked: false};
      const contexts = [];
      const windows = app.windows();
      for (const target of targets) {
        try {
          const w = windows.find(w => String(w.id()) === target.windowID);
          if (!w) continue;
          const tabs = w.tabs();
          const tab = safari ? tabs[target.index - 1] : tabs.find(t => String(t.id()) === target.tabID);
          if (!tab || tab.url() !== target.url) continue;
          const raw = safari ? app.doJavaScript(source, {in: tab}) : tab.execute({javascript: source});
          const value = JSON.parse(raw);
          if (tab.url() === target.url && value.url === target.url && typeof value.text === 'string') {
            contexts.push({key: target.key, text: value.text.slice(0, 8000)});
          }
        } catch (error) {
          if (error.errorNumber === -1728) continue;
          // JavaScript from Apple Events is optional. Stop rather than repeatedly asking a blocked browser.
          return {contexts: contexts, blocked: true};
        }
      }
      return {contexts: contexts, blocked: false};
    }
    """#
}
