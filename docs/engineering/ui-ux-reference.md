> **Imported from board_box.** This doc was authored for board_box; the file references and worked examples in the body (e.g. KlondikeModel, GameStats, Minesweeper, iOS Runner.messenger, the CI workflows) are board_box-specific. The *patterns* and *practices* are universal Flutter/Dart/Android engineering and apply here. Swap in card_box-local examples (e.g. CardDatabase, the Android device acceptance suite, card_box's CI) in follow-up edits — the structure does not need to change.

---

# UI/UX Reference

> **Stub.** Full content requires web research. The research
> backlog (URLs to scrape) is in the appendix of the docs
> plan. Author the full doc from that backlog in a follow-up
> turn.

---

## What this doc will cover

When the research is done, this file will be a single cited
reference for the UI/UX principles in
[`../design/04-ui-ux-principles.md`](../design/04-ui-ux-principles.md):

- **Nielsen's 10 heuristics** with citations to the NN/g
  articles.
- **Don Norman's 7 design principles** with citations to
  *The Design of Everyday Things*.
- **Material 3 foundations** with citations to m3.material.io.
- **Apple Human Interface Guidelines** with citations to
  developer.apple.com/design.
- **WCAG 2.2 AA** with citations to w3.org/WAI and WebAIM.
- **Motion, i18n, RTL** with citations to the relevant
  W3C, Apple, and Android docs.

The doc is a *reference* — it backs the claims in
`04-ui-ux-principles.md` with primary sources. The principles
doc is the *operational* layer; this is the *citation* layer.

---

## Source list (deferred to a follow-up turn)

### Core design principles
- https://www.nngroup.com/articles/ten-usability-heuristics/ (Nielsen 10)
- https://www.nngroup.com/articles/affordances/ (Norman summary)
- https://m3.material.io/foundations (Material 3)
- https://developer.apple.com/design/human-interface-guidelines/ (Apple HIG)
- https://design-system.service.gov.uk/design-principles/ (GOV.UK)

### Mobile-specific UX
- https://m3.material.io/foundations/accessible-design/accessibility-basics
- https://developer.apple.com/design/human-interface-guidelines/layout
- https://m3.material.io/styles/color/dark-theme
- https://developer.apple.com/design/human-interface-guidelines/typography
- https://m3.material.io/styles/gestures

### Design systems & tokens
- https://atlassian.design/tokens/design-tokens
- https://primer.style/foundations/color
- https://polaris.shopify.com/tokens
- https://www.w3.org/TR/design-tokens/
- https://m3.material.io/styles/motion/easing-and-duration

### Accessibility
- https://www.w3.org/TR/WCAG22/
- https://www.w3.org/WAI/standards-guidelines/mobile/
- https://www.w3.org/TR/wai-aria-1.2/
- https://www.w3.org/WAI/WCAG22/quickref/
- https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html
- https://webaim.org/resources/contrastchecker/
- https://developer.apple.com/design/human-interface-guidelines/accessibility
- https://developer.android.com/guide/topics/ui/accessibility

### Navigation & IA
- https://m3.material.io/components/navigation-bar
- https://developer.apple.com/design/human-interface-guidelines/navigation
- https://www.nngroup.com/articles/ia/
- https://developer.android.com/training/app-links
- https://developer.apple.com/documentation/xcode/defining-your-apps-structure

### States & feedback
- https://m3.material.io/components/progress-indicators
- https://m3.material.io/components/snackbar/overview
- https://developer.apple.com/design/human-interface-guidelines/undo-and-redo
- https://www.nngroup.com/articles/skeleton-screens/
- https://www.nngroup.com/articles/response-times-3-important-limits/
- https://web.dev/offline-first/

### Forms & input
- https://www.nngroup.com/articles/errors-forms-design/
- https://m3.material.io/components/text-fields/overview
- https://developer.apple.com/design/human-interface-guidelines/text-fields

### Motion
- https://m3.material.io/styles/motion
- https://developer.apple.com/design/human-interface-guidelines/motion
- https://developer.apple.com/documentation/uikit/uifeedbackgenerator
- https://developer.android.com/develop/ui/views/haptics
- https://www.w3.org/WAI/WCAG22/Understanding/animation-from-interactions.html

### i18n / RTL
- https://www.w3.org/International/tutorials/
- https://format.gs/ (ICU MessageFormat + CLDR)
- https://cldr.unicode.org/index/cldr-spec/plural-rules
- https://developer.apple.com/localization/
- https://developer.apple.com/design/human-interface-guidelines/right-to-left
- https://developer.android.com/training/basics/support-multiple-languages

### Onboarding & empty states
- https://www.nngroup.com/articles/onboarding/
- https://www.nngroup.com/articles/progressive-disclosure/
- https://m3.material.io/patterns/empty-states

### Heuristic review
- https://www.nngroup.com/articles/heuristic-evaluation/
- https://www.nngroup.com/articles/how-to-rate-the-severity-of-usability-problems/
- https://inclusive-components.design/

### AI-assisted UI generation
- https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering
- https://m3.material.io/ (component contracts)
- https://pair.withgoogle.com/guidebook (People + AI)
- https://developer.apple.com/design/human-interface-guidelines/machine-learning

---

## How to author this doc

1. Use the `Agent` tool with `WebSearch` + `WebFetch` to
   scrape the URL list above in 4-5 parallel batches.
2. For each principle in
   [`../design/04-ui-ux-principles.md`](../design/04-ui-ux-principles.md),
   add a citation to the primary source.
3. Pull quoted excerpts (with citation) for the load-bearing
   claims: the 4.5:1 contrast ratio, the 48dp touch target,
   the 200ms "feels instant" threshold, the 3-state heuristic
   for skeleton vs spinner, etc.
4. Keep the doc readable — bullet points with links, not a
   wall of quoted text. The principles doc is the
   operational layer; this is the citation layer.
5. Commit as `docs(ux): add UI/UX reference with primary-source
   citations` when the research is done.

---

## See also

- [`../design/04-ui-ux-principles.md`](../design/04-ui-ux-principles.md)
  — the principles this doc will cite.
- [`../design/03-design-system.md`](../design/03-design-system.md)
  — the tokens the principles implement.
