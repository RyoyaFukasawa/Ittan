# Ittan

Ittan is a native macOS file shelf. Start dragging a file or folder and Ittan
appears on the active display. Park items there, switch to the destination,
then drag them back out.

<p>
  <a href="https://github.com/RyoyaFukasawa/Ittan/releases/latest/download/Ittan.dmg">
    <img src="download-button.svg" alt="Download the latest version of Ittan" width="220">
  </a>
</p>

## Status

Ittan is an early macOS 26 prototype. It currently supports:

- Files and folders from Finder and other apps that provide file URLs
- Automatic shelf appearance when a file drag begins
- Multiple displays and all Spaces
- Persistent path references across launches
- Quick Look thumbnails, opening, revealing, copying, and removing items
- Removing a shelf reference after a successful drag out without changing the
  original file

Ittan is local-only. It has no account, analytics, cloud sync, or network calls.

## Requirements

- macOS 26 or newer
- Xcode 26 or newer

## Install

### Download

Download the latest notarized `Ittan.dmg` using the button above, open it, and
drag **Ittan** onto the **Applications** folder.

### Homebrew

Install the latest notarized release with Homebrew:

```sh
brew install --cask ryoyafukasawa/tap/ittan
```

## Build

```sh
xcodebuild build \
  -project Ittan.xcodeproj \
  -scheme Ittan \
  -configuration Debug \
  -destination "platform=macOS" \
  CODE_SIGNING_ALLOWED=NO
```

Run tests with:

```sh
xcodebuild test \
  -project Ittan.xcodeproj \
  -scheme Ittan \
  -destination "platform=macOS" \
  CODE_SIGNING_ALLOWED=NO
```

## Design references

The floating-panel approach is inspired by
[Screendrop](https://github.com/fayazara/screendrop), which is released under
CC0 1.0. Ittan's file-shelf implementation is independently structured for
its narrower workflow.

## License

MIT. See [LICENSE](LICENSE).
