# Layer Structure

iOS では Feature-Sliced Design を SwiftPM target と folder ownership に対応させる。

## Standard Layers

```text
Sources/
  App/
  Screens/
  Features/
  Entities/
  Shared/
```

## App

app 全体の入口。

- `AppFeature`
- root view
- tab/root navigation
- dependency bootstrap

feature 固有の処理は置かない。

## Screens

route/page 単位。

例:

```text
Screens/
  HomeScreen/
    model/HomeFeature.swift
    ui/HomeView.swift
  ItemDetailScreen/
    model/ItemDetailFeature.swift
    ui/ItemDetailView.swift
```

screen は child feature を組み合わせ、navigation を所有する。

## Features

再利用可能な interaction 単位。

例:

```text
Features/
  SearchFeature/
    model/SearchFeature.swift
    ui/SearchView.swift
  ImagePickerFeature/
    model/ImagePickerFeature.swift
    ui/ImagePickerView.swift
```

feature は route を知らない。結果を action/result として返す。

## Entities

domain concept 単位。

例:

```text
Entities/
  Item/
    model/ItemModels.swift
  User/
    model/UserModels.swift
    lib/UserReputation.swift
```

Foundation 以外への依存は最小にする。DTO/Row/View/Reducer は置かない。
domain model/value は `model/`、entity-local の pure helper は `lib/` に置く。

## Shared

横断的な primitive と infrastructure。

例:

```text
Shared/
  UI/
  Clients/
  Config/
  Navigation/
```

`Shared/UI` は concrete feature を知らない。`Shared/Clients` は external system を隠し、entity に map する。
