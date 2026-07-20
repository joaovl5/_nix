---
name: writing-markdown
description: |
  Use for any edits or writes to markdown files in general.
---

# Markdown Directives

Conflicting project-specific rules may take precedence.

## General Guidelines

- **Tables:** avoid creating tables unless they're absolutely
  necessary to convey an idea - prefer any of these alternatives:
  - Bullet list, mapping a concept A to another B
  - Plain prose - avoid reiterating something previously said with a
    table, especially if it's better conveyed through prose
  - Tables cost tokens and convey less per-token, thus it's crucial to
    only fallback to them once no other avenue is reasonable, like for
    statistics and situations with many useful columns to see
    - However, in the case the project context allows for placing
      chart components into markdown (e.g.: Plotly) they probably are
      better suited than a table for quantitative demonstrations
- **Bullet Lists:** useful for quickly getting a message across
  without ceremony
  - Avoid ending items with a period (question mark is fine)
  - Some bullet lists may benefit from structuring their top-level
    items via a `**<title>:** <content>` format, where `title` should
    be a succinct primer on what `content` entails
- **Headings and Titles:** when you need to title a section, either of
  a list or a header, it must be *kept short and condensed*, thus
  instead of "Comparison of Differences Amongst Styles", just say
  "Styles Comparison"
- **Diagrams:** express non-linear/complex ideas/flows via
  Mermaid diagrams
  - Avoid diagrams for ideas best expressed through prose, lists, or
    any other method available
  - *MUST* read [Mermaid reference](./references/mermaid/index.md)
    when handling these tasks
  - Use the reference for choosing the proper visuals for the diagram
- **Links:** use relative links instead of wrapping a path in
  backticks, unless they otherwise refer to non-local URIs
  - For links to Markdown files, strongly consider linking directly to
    a specific header via the `[Label](./file.md#header-slug)` syntax,
    where `header-slug` is auto-generated from the header of value
    `Header Slug` (slugs may be renderer-specific, thus check
    accordingly)
  - Links sometimes may be put [within the contents of
    a sentence](./SKILL.md) which is preferred when that sentence
    already talks of a linked subject instead of dedicating a link in
    isolation from prose
- **Footnotes:** usage of footnotes is obligatory for citing sources
  of any kind that are outside the authored file (or even inside, if
  the file is large enough to warrant cross-references)
  - If project rules on references aren't defined, abide by the
    [Sane Reference Standard](./references/sane-reference-standard.md)
  - Review loops, in case their scope includes markdown-authored
    material, shall use the footnotes cross-checking for verification
    of accuracy against base sources (when they're available)
- **Emphasis:** prefer bold for main emphasis topics, and italic for
  *secondary-like* emphasis
- **LaTeX:** prefer LaTeX for formulae, mathematical symbols, and
  related notation
  - For *notation types*, use `$` for inline and `$$` for block:

    ```markdown
    For values $x$ and $y$, the expression $x^2 + 2xy +y^2$ represents
    the result of:

    $$
    (x + y)^2
    $$

    ```
