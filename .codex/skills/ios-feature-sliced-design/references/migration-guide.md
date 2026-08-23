# Migration Guide

既存 iOS アプリを FSD へ移行するときは、一度に全部を移動しない。

## Step 1: 現状を読む

- `Package.swift` または Xcode project の target graph
- `import` の向き
- 画面単位の navigation
- API/DB/StoreKit などの service boundary

## Step 2: ルールを先に文書化する

先に `AGENTS.md` や architecture docs に layer rule を置く。コード移動より先に判断基準を固定する。

## Step 3: Pure domain を分離する

SwiftUI/TCA/API/DB 依存のない model/helper から `Entities` へ移す。

## Step 4: Clients を切る

API、DB、Keychain、StoreKit、Analytics などは `Shared/Clients` に dependency boundary を作る。

## Step 5: Screen と Feature を分ける

route/navigation を持つものは `Screens`。再利用 interaction は `Features`。

## Step 6: Package graph を更新する

SwiftPM target dependency が layer direction に沿っているか確認する。

## Step 7: 検証する

package graph を変えたら、少なくとも `swift test` またはその repo の iOS build/test コマンドを実行する。

## 避けること

- 全ファイルを一気に rename/move する。
- 使われていない abstraction を先に作る。
- `Shared` を temporary dump にする。
- import cycle を上向き import で解く。
