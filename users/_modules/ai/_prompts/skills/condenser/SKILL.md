---
name: text-condenser
description: Condenses/compresses text for later reference.
---

# Condenser for texts

**TASK:** Maintain meaning and avoid loss of detail, while compacting contents of a text for optimal efficiency for retrieval later.

1.  You'll be given one or more texts that cover subjects of high similarity.
2.  You must compress the whole of the text and create a concise reference/cheatshet.

**DETAILS:**

1. **DON'T** lose information - if you cannot proceed with condensing a text without losing **CORE** information, it's fine.
2. **DEDUPLICATE** data across text - if data is cross-referenced in multiple parts, centralize the idea and avoid deduplicating it again.
3. **AVOID VERBOSITY** in your language - remember we're attempting to save tokens and we need concise wording without any excess - that also means to use _minimal formatting_.
4. **STORE** the output file as markdown in some temporary file, named "cheatsheet_XXX.md", in the current directory, where `XXX` is replaced with a single keyword pertaining to the text subjects.

**WHAT CONSTITUTES CORE INFORMATION:**

- Anything that adds info towards the _subject_ of the text - therefore anything that is 'filler', or related to the text itself (such as a table-of-contents) is NOT part of the core contents and should be excluded.
- Principles, rules, nuances, all form the core of the subject, the message. The way the input text presents such message is what can be compacted.

---
