import Foundation

/// A fixed, read-only DOM reader. No page-provided text is ever evaluated as code.
enum PageMetadata {
    static let script = #"""
    (() => {
      const text = value => String(value || '').replace(/\s+/g, ' ').trim().slice(0, 600);
      const meta = key => text(document.querySelector('meta[property="' + key + '"],meta[name="' + key + '"]')?.content);
      const data = {url: location.href, pageTitle: text(document.title), ogTitle: meta('og:title'),
        twitterTitle: meta('twitter:title'), description: meta('og:description') || meta('twitter:description') || meta('description')};
      const icons = Array.from(document.querySelectorAll('link[rel]')).filter(link => /^(?:icon|shortcut icon|apple-touch-icon|apple-touch-icon-precomposed)$/i.test(link.rel.trim()));
      const icon = icons.find(link => /(?:^|\s)icon(?:$|\s)/i.test(link.rel)) || icons[0];
      if (icon && /^https?:\/\//i.test(icon.href)) data.iconURL = icon.href.slice(0, 4096);
      const host = location.hostname.replace(/^www\./, '');
      const path = location.pathname;
      if ((host === 'x.com' || host.endsWith('.x.com') || host === 'twitter.com') && /\/status\/\d+/.test(path)) {
        const status = path.match(/\/status\/(\d+)/)[1];
        const article = Array.from(document.querySelectorAll('article')).find(a => Array.from(a.querySelectorAll('a time')).some(t => {
          const href = t.closest('a')?.getAttribute('href') || '';
          return href.split('?')[0].endsWith('/status/' + status);
        }));
        data.post = text(article?.querySelector('[data-testid="tweetText"]')?.textContent);
      } else if (host === 'instagram.com' && /^\/(p|reel|tv)\//.test(path)) {
        // A permalink has one primary article; never take a caption from a scrolling feed.
        const articles = document.querySelectorAll('[role="dialog"] article');
        const article = articles.length === 1 ? articles[0] : (document.querySelectorAll('article').length === 1 ? document.querySelector('article') : null);
        data.post = text(article?.querySelector('h1')?.textContent);
      } else if (host.endsWith('linkedin.com') && /^\/(posts|feed\/update)\//.test(path)) {
        // Social metadata is safer than an arbitrary feed card or comment.
        data.post = data.description;
      }
      if (!['instagram.com', 'x.com', 'twitter.com', 'linkedin.com'].some(h => host === h || host.endsWith('.' + h))) {
        data.heading = text(document.querySelector('main h1,article h1')?.textContent);
      }
      return JSON.stringify(data);
    })()
    """#
}
