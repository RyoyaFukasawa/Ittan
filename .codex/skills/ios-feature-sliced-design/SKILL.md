---
name: ios-feature-sliced-design
description: Feature-Sliced Design for Swift/iOS projects. Use when structuring SwiftUI/TCA code with App, Screens, optional Widgets, Features, Entities, and Shared layers; deciding where Swift files, reducers, views, dependency clients, static assets, and SwiftPM targets belong; defining public API and import boundaries; resolving cross-imports or dependency cycles; deciding whether to create or remove an entity; migrating an existing iOS codebase to FSD; or implementing common SwiftUI/TCA patterns such as authentication, API clients, persistence, and state management within FSD.
---

# iOS Feature-Sliced Design (FSD)

**Source**: [feature-sliced/skills](https://github.com/feature-sliced/skills) を iOS/Swift 向けに翻案する。厳密さは project scale と team context に合わせて調整する。

---

## 1. Core Philosophy & Layer Overview

FSD の基本原則: **Start simple, extract when needed.**

まず `Screens/` に置く。重複があるだけでは、下位 layer へ抽出する理由にならない。

抽出するのは、同じ code が実際に複数箇所で使われていて、常に一緒に変更されるわけではなく、境界の責務が明確なときだけ。

**すべての layer は必須ではない。** 多くの iOS project は `Shared/`、`Screens/`、`App/` だけで開始できる。`Widgets/`、`Features/`、`Entities/` は価値が明確になったときに追加する。

空の layer folder を「念のため」に作らない。

iOS FSD では、標準 layer を高い順に次のように扱う。

```text
App/       → app initialization, dependency bootstrap, root navigation
Screens/   → route-level composition, owns its own logic
Widgets/   → multiple screens で再利用される大きな composite UI block（任意）
Features/  → 複数箇所で使われる reusable user interactions
Entities/  → 複数箇所で使われる reusable business domain models
Shared/    → business logic を持たない infrastructure（UI kit, utils, API clients）
```

**Import rule**: module は自分より下の layer だけを import する。

同じ layer の slice 間 cross-import は禁止する。

```swift
// ✅ Allowed: Feature -> Shared
import SharedUI

// ✅ Allowed: Screen -> Entity
import UserEntity

// ❌ Violation: Entity -> Feature
import LoginFeature

// ❌ Violation: Feature -> Feature
import FavoriteButtonFeature
```

`Processes/` layer は使わない。移行は `references/migration-guide.md` を読む。

---

## 2. Decision Framework

新しい code を書くときは、この順で判断する。

**Step 1: この code はどこで使われるか？**

- 1つの screen だけで使う → その `Screens/` slice に残す。
- 2つ以上の screen で使うが、重複が許容できる → それぞれの screen に残すのも有効。
- 1つの screen でしか使われていない entity/feature → その screen に残す。

**Step 2: business logic を持たない reusable infrastructure か？**

- UI component → `Shared/UI/`
- utility → `Shared/Lib/` または `Shared/Utils/`
- API client、route constants → `Shared/Clients/`、`Shared/API/`、`Shared/Config/`
- auth token、session management → `Shared/Auth/` または `Shared/Clients/AuthClient/`
- CRUD operations → `Shared/Clients/` または `Shared/API/`

**Step 3: 複数箇所で使われ、境界が安定した complete user action か？**

- Yes → `Features/`
- 不確実、単一利用、将来の再利用予想だけ → screen に残す。

**Step 4: 複数箇所で使われ、境界が安定した business domain model か？**

- Yes → `Entities/`
- 不確実、単一利用、将来の再利用予想だけ → screen に残す。

**Step 5: app-wide configuration か？**

- global providers、root navigation、theme、app bootstrap → `App/`

**Golden Rule: 迷ったら `Screens/` に残す。抽出は、同じ code が実際に複数箇所で使われ、境界が明確なときだけ。**

---

## 3. Quick Placement Table

| Scenario | Single use | Confirmed multi-use |
| --- | --- | --- |
| User profile form | `Screens/ProfileScreen/ui/ProfileForm.swift` | `Features/ProfileFormFeature/` |
| Product/Item card | `Screens/ItemListScreen/ui/ItemCard.swift` | `Entities/Item/ui/ItemCard.swift` または `Widgets/ItemCardWidget/` |
| Product/Item data fetching | `Screens/ItemDetailScreen/model/ItemDetailLoader.swift` | `Shared/Clients/ItemClient/` |
| Auth token/session | `Shared/Auth/` or `Shared/Clients/AuthClient/` | `Shared/Auth/` or `Shared/Clients/AuthClient/` |
| Login form | `Screens/LoginScreen/ui/LoginForm.swift` | `Features/AuthFeature/` |
| CRUD operations | `Shared/Clients/` | `Shared/Clients/` |
| Generic Card layout | local if truly one-off | `Shared/UI/Card.swift` |
| Modal manager | local if truly one-off | `Shared/UI/ModalManager.swift` |
| Modal content | `Screens/<Screen>/ui/SomeModal.swift` | extract only with real reuse |
| Date formatting utility | local if tied to screen | `Shared/Lib/DateFormatting.swift` |

---

## 4. Architectural Rules (MUST)

これらは FSD の土台。破る必要がある場合は、意図的な design decision として理由を code comment または ADR に残す。

### 4-1. Import only from lower layers

`App → Screens → Widgets → Features → Entities → Shared`

上向き import と、同じ layer の slice 間 cross-import は禁止する。

### 4-2. Public API: slice の外部公開面を小さく保つ

TypeScript の `index.ts` に相当するものとして、Swift では SwiftPM target/module の `public` API を最小に保つ。

外部 consumer は、その slice が意図して公開した型・関数・view だけを使う。internal helper を安易に `public` にしない。

```swift
// ✅ Correct: slice が公開する entry view/reducer を使う
import AuthFeature

// ❌ Violation: target を分けず internal helper を public にして外部から使う
// AuthFeatureInternalPasswordValidator を別 slice から直接利用する
```

`Shared` は slice を持たず、segment ごとに公開面を分ける。例: `SharedUI`、`APIClient`、`SharedConfig`。

### 4-3. No cross-imports between slices on the same layer

同じ layer の2つの slice が logic を共有したい場合は、Section 7 の解決順に従う。直接 import しない。

### 4-4. Domain-based file naming

ファイル名は technical role ではなく、表す domain/purpose で名付ける。

```text
// ❌ Technical-role naming
model/Types.swift      ← 何の型か不明。User? Order? 混在?
model/Utils.swift

// ✅ Domain/purpose-based naming
model/User.swift       ← User types + related logic
model/Order.swift
api/FetchProfile.swift
api/UpdateSettings.swift
```

### 4-5. No business logic in Shared

`Shared` は infrastructure のみ: UI kit、utilities、API client setup、route constants、assets。

business calculation、domain rule、workflow は `Entities/` またはより上位 layer に置く。

```swift
// ❌ Shared に business logic
// Shared/Lib/UserReputation.swift
func calculateUserReputation(_ user: User) -> Int { ... }

// ✅ owning domain へ
// Entities/User/lib/UserReputation.swift
func calculateUserReputation(_ user: User) -> Int { ... }
```

---

## 5. Recommendations (SHOULD)

### 5-1. Screens First: place code where it is used

まず `Screens/` に置く。下位 layer への抽出は本当に必要になってから行う。

抽出は project 全体に影響する design decision なので、閾値は高く保つ。

**Screens に残すもの:**

- 1 screen だけで使う大きな UI block
- screen-specific form、validation、data fetching、state management
- screen-specific business logic/API integration
- 再利用できそうに見えるが local の方が単純な code

Evolution pattern:

まず `Screens/ProfileScreen/` に置く。同じ user data が別 screen でも実際に必要になったら、shared model を `Entities/User/` へ抽出する。screen-specific API call や UI は screen に残す。

### 5-2. Be conservative with entities

`Entities` はほぼ全 layer から import できるため、変更の影響が広い。

1. **Entities なしで始める。** `Shared/` + `Screens/` + `App/` は有効な FSD。
2. **premature split を避ける。** code はまず screen に置く。
3. **business logic があるだけでは entity にしない。** API type は `Shared/Clients`、logic は current slice の `model/` で十分な場合がある。
4. **CRUD は `Shared/Clients` または `Shared/API` に置く。** CRUD は infrastructure であり entity ではない。
5. **auth data は `Shared/Auth` または `Shared/Clients/AuthClient` に置く。** token や login DTO は auth context に依存し、domain entity として再利用されることは少ない。

Entities を清潔に保つ詳細は `references/excessive-entities.md` を読む。

### 5-3. Start with minimal layers

```text
// ✅ Valid minimal iOS FSD project
Sources/
  App/       ← bootstrap, root navigation
  Screens/   ← all screen-level code
  Shared/    ← UI kit, utils, API clients

// Add only when an actual use case requires them:
// + Widgets/   ← UI blocks currently reused across multiple screens
// + Features/  ← user interactions currently reused across multiple screens/widgets
// + Entities/  ← domain models currently reused across screens/features/widgets
```

### 5-4. Validate manually or with local tooling

FSD の公式 linter は web/frontend 向けのため、Swift project ではそのまま使えないことが多い。代わりに次を確認する。

- SwiftPM target dependency が layer direction に沿う。
- `import` が上向きになっていない。
- 同 layer slice 間で直接 import していない。
- single-use feature/entity を早すぎて抽出していない。

---

## 6. Anti-patterns (AVOID)

- **entities を早く作りすぎない。** 1箇所でしか使わない data structure はその場所に置く。
- **CRUD を entities に置かない。** `Shared/Clients` または `Shared/API` を使う。
- **auth data だけのために `User` entity を作らない。** token/login DTO は `Shared/Auth` や auth client に置く。
- **single-use code を抽出しない。** 1 screen だけで使う feature/entity はその screen に残す。
- **technical-role file name を乱用しない。** `Types.swift`、`Utils.swift` より domain/purpose based naming を使う。
- **entity UI に注意する。** entity UI は便利だが cross-import を誘発しやすい。上位 layer からのみ import し、entity 同士で UI を import しない。
- **god slice を作らない。** 責務が広すぎる slice は focused slice に分割する。
- **top-level assets folder を作らない。** static assets は使う code の近くへ置く。詳細は `references/asset-handling.md`。

---

## 7. Cross-Import Resolution

cross-import は code smell だが、常に絶対禁止ではない。layer と状況で解決策を選ぶ。

### Entities layer: prefer boundary merge

`Entities` の cross-import は entity を細かく切りすぎた結果であることが多い。まず境界を merge できないか検討する。

特殊な escape hatch は最後の手段にする。使う場合は、なぜ merge や下位抽出ではだめなのかを記録する。

### Features and Widgets: four strategies

context に応じて選ぶ。

- **Strategy A: Slice merge.** 2つの slice が常に一緒に変わる → merge。
- **Strategy B: Push to entities.** shared domain logic → `Entities/` へ移し、UI は features/widgets に残す。
- **Strategy C: Compose from upper layer (IoC).** parent (`Screens` or `App`) が両 slice を import し、closure/delegate/action/DI で接続する。
- **Strategy D: Public API access.** reuse が本当に避けられない場合だけ、slice の public API 経由で許可する。internal file/helper へ手を伸ばさない。

strictness は project context に依存する。早期 product では pragmatic trade-off があり得る。長期運用や規制領域では境界を厳密に保つ価値が高い。

具体例は `references/cross-import-patterns.md` を読む。

---

## 8. Segments & Structure Rules

### Standard segments

slice 内の code は technical purpose で segment に分ける。

- **`ui/`**: SwiftUI/UIKit views、display-related code
- **`model/`**: TCA reducer/state/action、domain-facing logic、validation
- **`api/`**: backend integration、request functions、API-specific types
- **`lib/`**: slice-local utility
- **`config/`**: configuration、feature flags

### Layer structure rules

- **App and Shared**: slices を持たず、segment で直接整理する。
- **Screens, Widgets, Features, Entities**: slice first、その中に segment。
- **Slice groups (optional)**: 大きい layer で関連 slice を見つけやすくするための group folder は許可する。ただし group は segment も public API も持たない。詳細は `references/layer-structure.md`。

### File naming within segments

ファイル名は domain/purpose based にする。

```text
model/User.swift
model/Order.swift
api/FetchProfile.swift
api/UpdateSettings.swift
```

segment が1つの domain concern だけを持つなら、filename は slice 名と同じでもよい。

---

## 9. Shared Layer Guide

`Shared` は business logic を持たない infrastructure。

`Shared` は slice を持たず、segment で整理する。segment 間 import は許可する。

**Allowed in Shared:**

- `UI/`: UI kit (`Button`, `Input`, `Modal`, `Card`)
- `Lib/` or `Utils/`: utilities (`formatDate`, `debounce`)
- `Clients/` or `API/`: API client、route constants、CRUD helpers、base DTOs
- `Auth/`: auth tokens、login utilities、session management
- `Config/`: environment values、app settings
- `Assets/`: app 全体で共有される branding assets（控えめに使う。詳細は `references/asset-handling.md`）

`Shared` は route constants、API endpoints、branding assets、common infrastructure types など application-aware な code を含んでよい。

ただし business logic、feature-specific code、entity-specific code は置かない。

---

## 10. Quick Reference

- **Import direction**: `App → Screens → Widgets → Features → Entities → Shared`
- **Minimal FSD**: `App/` + `Screens/` + `Shared/`
- **Create entities when**: 同じ business domain model が複数 screen/feature/widget で実際に使われ、境界が安定している。
- **Create features when**: 同じ user interaction が複数 screen/widget で実際に使われ、境界が安定している。
- **Breaking rules**: 意図的な design choice としてのみ。理由を comment/ADR に残す。
- **Cross-import resolution (entities)**: まず boundary merge。
- **Cross-import resolution (features/widgets)**: Strategy A (merge), B (push to entities), C (compose from upper layer), D (public API)。
- **File naming**: domain/purpose based。`Types.swift`、`Utils.swift` の乱用を避ける。
- **Asset placement**: 使う code の近くへ置く。reuse は `Shared/UI/`。global fonts/branding は `App/` または `Shared/Assets/`。
- **Slice groups**: 大きい layer の navigation aid。group folder は segment も public API も持たない。
- **Processes layer**: 使わない。`references/migration-guide.md` を読む。

---

## 11. Conditional References

必要な状況でだけ reference を読む。すべてを最初から preload しない。

- **FSD layer/slice の folder/file structure を作成・review・再整理するとき**、または関連 slice を group folder にまとめるべきか判断するとき:
  → `references/layer-structure.md`
- **同じ layer の slice 間 cross-import を解消するとき**、Strategy A/B/C/D を選ぶとき、boundary merge を判断するとき:
  → `references/cross-import-patterns.md`
- **entity を作る/消す判断をするとき**、entities が増えすぎているとき、entities layer 自体を省略できるか判断するとき、CRUD/auth data の配置で迷うとき:
  → `references/excessive-entities.md`
- **static assets**（images, icons, fonts, PDFs, asset catalogs）を single slice、shared、global のどこへ置くか判断するとき:
  → `references/asset-handling.md`
- **既存 iOS codebase を FSD へ移行するとき**、古い独自 layer を廃止するとき:
  → `references/migration-guide.md`
- **SwiftUI/TCA/UIKit/SwiftData/Core Data/GRDB/OpenAPI など framework と FSD の接続で迷うとき**:
  → `references/framework-integration.md`
- **authentication、API request handling、type definitions、state management、dependency clients などの具体例が必要なとき**:
  → `references/practical-examples.md`

Structure を先に扱い、その後で必要な pattern reference を読む。
