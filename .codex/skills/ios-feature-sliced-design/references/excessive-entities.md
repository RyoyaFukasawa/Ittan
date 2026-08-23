# Excessive Entities

Entities は domain language の置き場であり、すべての API response や DB row を置く場所ではない。

## Entity にしないもの

- 画面専用の display model
- API DTO
- database row
- generated schema type
- form state
- one-off enum

これらは feature/screen/client 側に残す。

## Entity にしてよいもの

- 複数 feature/screen で共有される domain model
- product language として安定している value
- API や DB の形から独立している model
- pure domain helper が自然に属する concept

## 判断ルール

1. その型名は product team や user story に出てくるか。
2. API provider や DB schema が変わっても残る概念か。
3. 複数 slice から必要とされているか。
4. SwiftUI/TCA/API/DB を import せず表現できるか。

すべて Yes に近いなら `Entities`。そうでなければ local に残す。

## 例

```text
Entities/User/model/User.swift    # OK: domain model
Shared/Clients/UserClient/DTOs.swift  # OK: API DTO
Features/EditUserFeature/FormState.swift # OK: form state
```
