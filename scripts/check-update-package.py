#!/usr/bin/env python3
"""Check a packaged ZIP and exercise Sparkle signing without publishing it."""
import os
import pathlib
import plistlib
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

root = pathlib.Path(__file__).resolve().parent.parent
tools = root / ".build/artifacts/sparkle/Sparkle/bin"
account = os.environ.get("SPARKLE_KEY_ACCOUNT", "app.savenest.mac")
archive = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) == 2 else None
if archive is None or not archive.is_file():
    sys.exit("Usage: scripts/check-update-package.py PATH_TO_RELEASE_ZIP")


def run(*args):
    return subprocess.check_output([str(arg) for arg in args], text=True).strip()


with tempfile.TemporaryDirectory(prefix="savenest-update-check-") as directory:
    work = pathlib.Path(directory)
    run("ditto", "-x", "-k", archive, work / "unpacked")
    app = work / "unpacked/SaveNest.app"
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    assert info["CFBundleIdentifier"] == "app.savenest.mac"
    assert info["SUPublicEDKey"] == run(tools / "generate_keys", "--account", account, "-p")
    assert info["SUFeedURL"] == "https://savenest.app/downloads/appcast.xml"
    assert info["SUAllowsAutomaticUpdates"] is False
    assert info["SUEnableSystemProfiling"] is False
    run("codesign", "--verify", "--deep", "--strict", app)
    binary = app / "Contents/MacOS/SaveNest"
    assert set(run("lipo", "-archs", binary).split()) == {"arm64", "x86_64"}
    assert "@executable_path/../Frameworks" in run("otool", "-l", binary)
    framework = app / "Contents/Frameworks/Sparkle.framework"
    assert (framework / "Versions/Current").is_symlink()
    assert (framework / "Sparkle").is_symlink()
    assert set(run("lipo", "-archs", framework / "Sparkle").split()) == {"arm64", "x86_64"}
    for relative in ("Autoupdate", "Updater.app/Contents/MacOS/Updater",
                     "XPCServices/Installer.xpc/Contents/MacOS/Installer",
                     "XPCServices/Downloader.xpc/Contents/MacOS/Downloader"):
        assert os.access(framework / "Versions/B" / relative, os.X_OK), relative

    feed_dir = work / "feed"
    feed_dir.mkdir()
    copied = feed_dir / archive.name
    shutil.copy2(archive, copied)
    notes = root / "Resources/ReleaseNotes" / f'{info["CFBundleShortVersionString"]}.html'
    if notes.exists():
        shutil.copy2(notes, copied.with_suffix(".html"))
    run(tools / "generate_appcast", "--account", account, "--maximum-deltas", "0",
        "--download-url-prefix", "https://savenest.app/downloads/", feed_dir)
    namespace = {"sparkle": "http://www.andymatuschak.org/xml-namespaces/sparkle"}
    item = ET.parse(feed_dir / "appcast.xml").find("channel/item")
    assert item is not None
    assert item.findtext("sparkle:version", namespaces=namespace) == info["CFBundleVersion"]
    assert item.findtext("sparkle:shortVersionString", namespaces=namespace) == info["CFBundleShortVersionString"]
    assert item.findtext("sparkle:minimumSystemVersion", namespaces=namespace) == info["LSMinimumSystemVersion"]
    enclosure = item.find("enclosure")
    assert enclosure is not None
    assert enclosure.get("url") == f"https://savenest.app/downloads/{archive.name}"
    assert int(enclosure.get("length")) == copied.stat().st_size
    signature = enclosure.get("{" + namespace["sparkle"] + "}edSignature")
    assert signature
    run(tools / "sign_update", "--account", account, "--verify", copied, signature)
    with copied.open("ab") as file:
        file.write(b"tampered")
    rejected = subprocess.run([str(tools / "sign_update"), "--account", account,
                               "--verify", str(copied), signature], capture_output=True)
    assert rejected.returncode != 0, "A modified archive must fail signature verification"

print("Passed update package checks: universal app/framework, embedded helpers, code signature, feed metadata, valid signature, and tampered-archive rejection.")
