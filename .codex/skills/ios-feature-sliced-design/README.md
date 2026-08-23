# iOS Feature-Sliced Design Skill

この skill は、Feature-Sliced Design 公式 skill repository を参考にしています。

- 参考 repository: https://github.com/feature-sliced/skills
- 元 skill: `feature-sliced-design`

元の Feature-Sliced Design skill は主に frontend / TypeScript / React の文脈を前提にしているため、この project では Swift / iOS / SwiftUI / TCA / SwiftPM 向けに内容を書き換えています。

基本思想と構成は元 skill に寄せつつ、以下のような iOS 固有の観点へ置き換えています。

- `pages` → `Screens`
- `index.ts` による public API → SwiftPM module の `public` API
- React component → SwiftUI view
- frontend import boundary → SwiftPM target dependency と Swift `import`
- API / state management examples → Swift dependency client / TCA reducer examples
