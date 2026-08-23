# Framework Integration

この skill は SwiftUI/TCA を主対象にするが、他の iOS framework と併用しても layer rule は変えない。

## SwiftUI

- view primitive は `Shared/UI`。
- screen 固有 layout は `Screens`。
- feature 固有 view は `Features`。
- `Environment` や view modifier は汎用なら `Shared/UI`、local ならその slice。

## TCA

- reducer/state/action は `Features` または `Screens`。
- screen reducer が child feature reducer を compose する。
- dependency client は `Shared/Clients`。
- `Shared/UI` は原則 `ComposableArchitecture` を import しない。

## UIKit

UIKit wrapper は責務で置く。

- 汎用 wrapper: `Shared/UI`
- feature 固有 wrapper: `Features/<Feature>/ui`
- route 固有 wrapper: `Screens/<Screen>/ui`

## Combine / AsyncSequence

stream の source は client に隠す。feature/screen は domain event として受け取る。

## SwiftData / GRDB / Core Data

storage row/model は entity ではない。

- DB schema/row: client implementation 側
- repository/dependency boundary: `Shared/Clients`
- domain model: `Entities`

## Generated API Clients

OpenAPI generated type や GraphQL generated type は external shape として扱う。

- generated code: `Shared/Generated` など
- mapping: client implementation
- exposed domain model: `Entities`
