import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import assert from 'node:assert/strict';

const source = readFileSync(new URL('../Sources/SaveNest/PageMetadata.swift', import.meta.url), 'utf8');
const script = source.split('#"""')[1].split('"""#')[0];
function read({host, path, title, metadata = {}, articles = []}) {
  return JSON.parse(runInNewContext(script, {
    location: {hostname: host, pathname: path, href: `https://${host}${path}`},
    document: {
      title,
      querySelector(selector) {
        const key = selector.match(/meta\[property="([^"]+)"\]/)?.[1];
        return key && metadata[key] ? {content: metadata[key]} : null;
      },
      querySelectorAll(selector) { return selector === 'article' ? articles : []; }
    }
  }, {timeout: 1000}));
}
function tweet(id, content) {
  return {
    querySelectorAll: () => [{closest: () => ({getAttribute: () => `/anna/status/${id}`})}],
    querySelector: () => ({textContent: content})
  };
}
const result = read({host: 'x.com', path: '/anna/status/123', title: 'X', articles: [tweet('999', 'Unrelated promoted post'), tweet('123', 'The post being saved')]});
assert.equal(result.post, 'The post being saved');
const feed = read({host: 'x.com', path: '/home', title: 'Home / X', articles: [tweet('999', 'A feed post')]});
assert.equal(feed.post, undefined, 'Do not turn the home page into an unrelated post title');
const instagram = read({host: 'instagram.com', path: '/p/ABC/', title: 'Instagram', metadata: {'og:title': 'A caption from Instagram'}});
assert.equal(instagram.ogTitle, 'A caption from Instagram');
const linkedin = read({host: 'www.linkedin.com', path: '/posts/anna-design', title: 'LinkedIn', metadata: {'og:description': 'How to make a thoughtful interface'}});
assert.equal(linkedin.post, 'How to make a thoughtful interface');
console.log('Passed 4 page metadata checks');
