# Sane Reference Standard

>[!WARNING]
>This standard is not from any institution and should not be used in
>situations where another conflicting standard may exist.
>
>The **Sane Reference Standard**, or **SRS**, is for footnote
>references, not "in-text"

## Philosophy

- Reach for maximum allowed specificity
- Quoting of relevant sections - when it makes sense

## Atoms

These "atoms" explain contents in the reference format, including when
and how they're applied.

- `YEAR, MONTH` like `2000, Jan`
  - Omit `, MONTH` if it's unknown/undecidable
  - Omit date entirely if year is unknown/undecidable, while also
    omitting the dash.
- `AUTHOR` like `J. M. Doe` for `John Markson Doe`
  - Initials on all parts of name aside from last, titles like "Mr",
    "Dr", "Professor" are dropped
  - Use "et al" for more than three authors, and keep the first three,
    e.g.: `J. Doe, M. Axis, T. C. Lin et al.`
  - use `_Unknown_` or `_N/A_` for cases where the author could not be
    determined or isn't applicable
    - Don't use this for collaborative documents (e.g. Confluence)
      where a list of authors can be derived with specialized
      tooling like MCPs - handle blockers in access for these cases
      by consulting with user
- `TITLE` taken from work's title
  - If untitled: `Untitled`
  - If unknown: `Unknown`
  - If is commit title, use italicized backticked syntax, e.g.
    "*`fix(ABC-123): Remove constraint on argument parsing`*"
    otherwise use italicized and capitalized syntax (except if
    untitled/unknown) e.g. "*An Analysis of Human Understanding*"
- `- POS`, as in "position" of reference:
  - If page number exists it gets added first, in the form of
    `pg. NUM`, e.g.: `pg. 2`
  - If audiovisual (e.g.: lecture video, or a transcript thereof),
    timestamp range is added in the format of `HH:MM:SS → HH:MM:SS`
    with stripped leading zeros, thus `00:04:01` becomes `04:01`
  - If has chapters/sections, add its title, the format is
    `_CHAPTER_` e.g.: `_Constructing the experiment_`
  - If none of these are applicable for it, omit `- POS` entirely
  - So the formatting is basically: (`?` means "if applicable")
    `page? - timestamp_range? - chapter?` (with empty items stripped
    of dashes of course)
  - For code repositories, use space-separated commit hashes in
    italicized backticks, with a prepending "commit" or "commits" word
    - e.g. "commits *`1234abc 56789de`*"
- `- PROVENANCE -` consists of:
  - `INSTITUTION,` - if applicable, the institution's name responsible
    for publishing work in question (if absent remove comma)
    - for code repositories, use forge website (e.g. Github)
  - `SOURCE` - where source material was gotten (e.g.: journal,
    website, platform)
    - for code repositories, use format `author/repository` (including
      the backticks), so the full "PROVENANCE" string would be
      something like "Github, `example-org/http-server`"
  - If link exists for source, the full provenance string should be
    the place to encapsulate this link
- `SNIPPET` is an **OBLIGATORY** short snippet of material - it shall
  only contain bare essential-to-the-matter contents in condensed
  form, via the rules below:
  - In markdown quotes syntax, so all lines have `>` before the
    content, and no whitespace between the angle bracket and the
    proceeding text
  - For code/commit references, use a code block applied with the
    correct language, or with the "diff" language syntax in cases of
    references pertaining to code diffs specifically - the following
    prose-specific instructions should be disregarded for code/diffs.
  - Any non-essential contents are omitted within the text and
    replaced by `(...)` - also applies to start/end of snippet
    if they're not start/end of paragraph/phrase
  - Contents from snippet, if relevant, may come from different places
    of material (but `POS` must respect that, if applicable), and
    joined by `(...)` - however, it should be noted if
    position/chapter differ amongst them, via `(POS)` for each
    portion (of course, this only applies if reference position was
    made intentionally broader for dealing with scattered portions in
    the same reference)
  - Phrases may be shortened by adapting their "subject of regard" via
    `(re. SUBJ)` forms
  - Mustn't contain line breaks
  - Mustn't be longer than what would take to write 12 sentences of
    median length
  - Example:
  >_(pg. 1 - Introduction) CoT is expensive, requires high-quality
  >reasoning data (...) can be brittle since the generated reasoning
  >may be wrong (...) (pg. 8 - Conclusion) (re. Tiny Recursion
  >Models) significantly reduces the number of parameters by halving
  >the number of layers and replacing the two networks with a single
  >tiny network_

Notes:

- Generally, treat dashes and commas as applicable for being omitted
  if they're separating items that aren't applicable.
- Code repositories may have `CITATION.*` files containing extractable
  information for usage in references

## Format

```markdown
[^footnote-id]: YEAR, MONTH - PROVENANCE - AUTHOR - _TITLE_ - POS
    >_SNIPPET_
```
