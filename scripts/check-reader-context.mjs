import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import { createRequire } from 'node:module';
import { JSDOM } from 'jsdom';

const require = createRequire(import.meta.url);
const { Readability } = require('@mozilla/readability');
const source = readFileSync(new URL('../Sources/SaveNest/ReaderCapture.swift', import.meta.url), 'utf8');
const [page, browser] = [...source.matchAll(/#"""([\s\S]*?)"""#/g)].map(match => match[1]);
const prose = 'A thoughtful reader writes down questions, remembers useful connections, and makes room for ideas to develop. '.repeat(12);
const dom = new JSDOM(`<!doctype html><html><head><title>Reading well</title><style>.secret { display:none }</style></head><body><article><h1>Reading well</h1><p>${prose}</p><form><p>PRIVATE_FORM_VALUE</p><input value="PRIVATE_INPUT_VALUE"></form><div contenteditable><p>PRIVATE_EDITOR_VALUE</p></div><p hidden>PRIVATE_HIDDEN_VALUE</p><div class="secret"><p>PRIVATE_CSS_VALUE</p></div><p aria-hidden="true">PRIVATE_ARIA_VALUE</p><p>${prose}</p><img src="/article.jpg" srcset="/other.jpg 2x"><a href="/next">Next reading</a><a href="javascript:alert(1)">Bad reference</a></article></body></html>`, {url:'https://example.com/read'});
const execute = (document = dom.window.document, location = dom.window.location) => JSON.parse(runInNewContext(`(() => {${page}})()`, {
  document, location, Readability, URL, TextEncoder,
  getComputedStyle: node => dom.window.getComputedStyle(node)
}));
const article = execute();
assert.equal(article.url, 'https://example.com/read');
assert.ok(article.article.content.includes('thoughtful reader'));
assert.ok(!article.article.content.includes('PRIVATE_'));
assert.ok(article.article.content.includes('https://example.com/article.jpg'));
assert.ok(article.article.content.includes('https://example.com/next'));
assert.ok(!article.article.content.includes('javascript:'));
assert.ok(!article.article.content.includes('srcset='));
assert.ok(dom.window.document.querySelector('input'), 'capture must not alter the browser page');

const large = new JSDOM(`<article><p>${'Reader text. '.repeat(12000)}</p></article>`, {url:'https://example.com/large'});
assert.match(execute(large.window.document, large.window.location).error, /too large/);
const oversizedDOM = { querySelectorAll: () => ({length:30001, [Symbol.iterator]: function* () { for (let i=0;i<30001;i++) yield {}; }}) };
assert.match(execute(oversizedDOM).error, /too large/);

const read = runInNewContext(browser + '\nreadReaderTab');
let reads = 0, currentURL = 'https://example.com/read', capturedURL = currentURL;
const tab = {id:()=>'tab-1',url:()=>currentURL,title:()=>'Reading well',name:()=>'Reading well',execute:()=>{reads++;return JSON.stringify({...article,url:capturedURL});}};
const window = {id:()=>42,tabs:()=>[tab],activeTab:()=>tab,currentTab:()=>tab};
const app = {id:()=>'com.google.Chrome',running:()=>true,windows:()=>[window],doJavaScript:()=>tab.execute()};
const target = {windowID:'42',tabID:'tab-1',index:1,url:currentURL};
for (const safari of [false,true]) {
  assert.equal(read(app,safari,null,'static extraction').article.title, article.article.title);
  assert.equal(read(app,safari,target,'static extraction').url,currentURL);
}
assert.equal(reads,4);
for (const safari of [false,true]) {
  const metadata = read(app,safari,null,'');
  assert.equal(metadata.url,currentURL);
  assert.equal(metadata.article,undefined);
  assert.equal(metadata.readerTarget.windowID,'42');
}
assert.equal(reads,4, 'opening Original must not execute browser JavaScript');
assert.match(read(app,false,{...target,url:'https://example.com/other'},'extract').captureError,/changed/);
assert.equal(reads,4, 'wrong target must not execute JavaScript');
assert.match(read(app,false,{...target,tabID:'closed'},'extract').captureError,/closed/);
capturedURL = 'https://example.com/navigated';
assert.match(read(app,false,target,'extract').captureError,/changed/);
capturedURL = currentURL;
tab.execute = () => { currentURL = 'https://example.com/navigated'; return JSON.stringify(article); };
assert.match(read(app,false,target,'extract').captureError,/changed/);
currentURL = target.url;
tab.execute = () => { throw {errorNumber:-1743}; };
const blocked = read(app,false,target,'extract');
assert.equal(blocked.url,target.url);
assert.match(blocked.captureError,/JavaScript from Apple Events/);
window.tabs = () => [tab,tab];
assert.match(read(app,true,target,'extract').captureError,/multiple copies/);
console.log('Passed Reader capture: private/hidden exclusion, real Readability, safe references, bounds, identity, navigation and denied access.');
