# Practical Examples

## Example 1: Search

Search が複数画面で使える interaction なら feature。

```text
Features/SearchFeature/
  model/SearchFeature.swift
  ui/SearchView.swift
```

Search tab の navigation や detail 遷移を持つなら screen。

```text
Screens/SearchScreen/
  model/SearchScreenFeature.swift
  ui/SearchScreenView.swift
```

## Example 2: Item Detail

detail route は通常 screen。

```text
Screens/ItemDetailScreen/
  model/ItemDetailFeature.swift
  ui/ItemDetailView.swift
```

detail 内の reusable section が他でも使われるなら feature に抽出する。

## Example 3: Image Loading

```text
Shared/UI/RemoteImageView.swift
Shared/Clients/ImageCacheClient/
Features/ProfileAvatarPickerFeature/
```

URL construction や cache は UI primitive に混ぜない。domain-specific な選択は feature/screen 側。

## Example 4: Form Validation

1つの form だけなら feature-local。

```text
Features/EditProfileFeature/model/ProfileFormValidation.swift
```

複数 domain で使う pure validation なら `Shared/Validation`。

## Example 5: Dependency Cycle

悪い例:

```text
Features/ProfileFeature -> Screens/SettingsScreen
```

修正:

```text
Screens/SettingsScreen imports ProfileFeature
ProfileFeature emits .delegate(.profileSaved)
SettingsScreen handles navigation
```
