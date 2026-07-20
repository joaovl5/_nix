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
  - use `_Unknown_` or `_N/A_` for such cases
- `TITLE` verbatim from work's title
  - If untitled: `Untitled`
  - If unknown: `Unknown`
  - Must be italicized and capitalized (except if untitled/unknown)
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
- `- INSTITUTION, PROVENANCE -` consists of:
  - `INSTITUTION,` - if applicable, the institution's name responsible
    for publishing work in question (if absent remove comma)
  - `PROVENANCE` - where source material was gotten (e.g.: journal,
    website, platform)
- `SNIPPET` is an **OBLIGATORY** short snippet of material - it shall
  only contain bare essential-to-the-matter contents in condensed
  form, via the rules below:
  - In markdown quotes syntax, so all lines have `>` before the
    content, and no whitespace between the angle bracket and the
    proceeding text
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
  - Mustn't be longer than what would take to write 12
    sentences of median length
  - Example:
  >(pg. 1 - _Introduction_) CoT is expensive, requires high-quality
  >reasoning data (...) can be brittle since the generated reasoning
  >may be wrong (...) (pg. 8 - _Conclusion_) (re. Tiny Recursion
  >Models) significantly reduces the number of parameters by halving
  >the number of layers and replacing the two networks with a single
  >tiny network

Generally, treat dashes as applicable for being omitted if they're
separating items that aren't applicable.

## Format

```markdown
[^footnote-id]: YEAR, MONTH - INSTITUTION, PROVENANCE - AUTHOR - _TITLE_ - POS
  >SNIPPET
```

### Examples
