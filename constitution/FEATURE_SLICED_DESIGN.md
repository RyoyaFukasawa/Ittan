# Feature-Sliced Design Constitution

基本的なFSDルールはskillを正本とし、この憲法には、それより優先して強制する差分だけを記載します。

## Feature層の命名

- Feature層のslice/moduleは、必ず **Verb + Noun（動詞 + 名詞）** で命名する。
- Verbは一つの明確な操作、Nounはその対象または結果を表す。
- 表記形式とsuffixは、使用する言語やframeworkの規約に従う。
- `auth`、`profile`、`search`のような名詞だけの名前は禁止する。
- `manage-user`、`process-data`のように責務が曖昧な名前は禁止する。
- Verb + Nounで表せない場合は、操作ごとに分割する。境界が不明ならFeatureへ抽出しない。

例: `search-items`、`toggle-favorite`、`save-draft`、`delete-comment`
