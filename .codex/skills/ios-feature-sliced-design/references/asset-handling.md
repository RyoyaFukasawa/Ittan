# Asset Handling

asset は ownership に合わせて置く。

## App Assets

AppIcon、LaunchBackground、entitlements に近いものは app target 側に置く。

```text
apps/ios/App/Resources/
```

## Shared UI Assets

複数 feature/screen で使う UI asset は `Shared/UI` の resources に置く。

```text
Sources/Shared/UI/Resources/
```

`Package.swift` では target に resources を明示する。

```swift
.target(
  name: "SharedUI",
  dependencies: [],
  path: "Sources/Shared/UI",
  resources: [.process("Resources")]
)
```

## Feature-local Assets

1つの feature/screen 専用なら、その target の resources に置く。まだ再利用されていない asset を早く `Shared` に移さない。

## External Images

API/CDN 由来の画像は asset catalog にコピーしない。URL、cache、placeholder、attribution の責務を分ける。

- URL construction/cache: client または shared image utility。
- display primitive: `Shared/UI`。
- domain-specific choice: feature/screen。
