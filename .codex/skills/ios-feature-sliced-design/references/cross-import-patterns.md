# Cross Import Patterns

Feature-Sliced Design では sibling slice 同士の直接依存を慎重に扱う。iOS では SwiftPM target dependency に現れるため、循環が早く表面化しやすい。

## 禁止に近い依存

```text
Features/A -> Features/B -> Features/A
Features/SomeFeature -> Screens/SomeScreen
Entities/User -> Shared/Clients/UserClient
```

この形になったら、依存先を上位 orchestration へ移すか、共通部分を下位層へ抽出する。

## Screen で出会わせる

複数 feature の sequencing は screen に置く。

```text
Screens/EditProfileScreen
  imports ProfileFormFeature
  imports ImagePickerFeature
```

`ProfileFormFeature` が `ImagePickerFeature` を直接 import するより、screen が両方を持って action をつなぐ。

## Entity に protocol を置かない

Swift では protocol を entity に置きたくなるが、client boundary は通常 `Shared/Clients` に置く。

```text
Shared/Clients/UserClient
  maps GeneratedAPI.UserDTO -> UserEntity.User
```

Entity は domain model を持つ。transport や storage の protocol は client 側に閉じる。

## Shared へ抽出する基準

下位層へ抽出してよいもの:

- pure helper
- generic UI primitive
- dependency client
- app domain に依存しない utility

抽出しないもの:

- 1 screen のためだけの view composition
- feature 固有の validation/business rule
- route 固有の navigation state
