---
name: org-mode
description: ORG-Mode skill
---

# Org Mode Cheatsheet

## Headlines & Structure

- `*` = level 1, `**` = level 2, etc.
- `M-RET` insert new heading at current level
- `C-RET` insert new heading after subtree
- `M-S-RET` insert new TODO entry
- `M-LEFT/RIGHT` promote/demote heading one level
- `M-S-LEFT/RIGHT` promote/demote current subtree
- `M-UP/DOWN` move subtree up/down

## Visibility Cycling

- `TAB` rotate subtree: FOLDED → CHILDREN → SUBTREE
- `S-TAB` global: OVERVIEW → CONTENTS → SHOW ALL
- `C-u C-u TAB` restore startup visibility
- `C-u C-u C-u TAB` show all including drawers

## Motion

- `C-c C-n/p` next/previous heading
- `C-c C-f/b` next/previous same level
- `C-c C-u` backward to higher level
- `C-c C-j` jump to different place (outline navigator)

## Sparse Trees & Filtering

- `C-c /` construct sparse tree by criteria
- `C-c / r` (or `C-c / /`) regex search → sparse tree
- `M-g n/p` next/previous match

## Plain Lists

- `-` or `+` unordered, `1.` or `1)` ordered
- `M-RET` new item, `M-S-RET` checkbox item
- `C-c -` cycle bullet type
- `S-UP/DOWN` jump to prev/next item
- `C-c C-c` toggle checkbox / verify structure

## Drawers & Blocks

- `:DRAWERNAME:` ... `:END:` for drawers
- `C-c C-x d` insert drawer
- `C-c C-z` add timestamped note to LOGBOOK
- `#+BEGIN` ... `#+END` blocks foldable with TAB

## Tables

- `C-c |` convert region to table
- `TAB` re-align, move to next field
- `M-LEFT/RIGHT` move column, `M-UP/DOWN` move row
- `C-c -` insert hline, `C-c RET` hline + move
- `C-c +` sum column/rectangle

## Links

- `[[LINK][DESCRIPTION]]` or `[[LINK]]`
- `C-c C-l` insert/edit link
- `C-c C-o` open link at point
- `C-c %` push position, `C-c &` jump back
- Internal: `[[*Headline]]`, `[[#custom-id]]`, `<<target>>`

## TODO Items

- `C-c C-t` rotate TODO state (TODO → DONE)
- `S-LEFT/RIGHT` prev/next state
- `C-c ,` set priority [A/B/C]
- `S-UP/DOWN` raise/lower priority
- `C-c C-v` view TODO sparse tree
- `M-S-RET` insert checkbox TODO
- `[/]` or `[%]` progress cookie

## Tags

- `:tag:` at end of headline
- `C-c C-q` set tags
- Tags inherit down the tree
- `C-c \` sparse tree matching tags

## Properties

- `PROPERTIES` drawer below headline
- `:KEY: VALUE` format
- `C-c C-x p` set property
- Special: ALLTAGS, CLOSED, DEADLINE, SCHEDULED, PRIORITY, TODO, etc.

## Timestamps

- `<2024-01-15 Mon>` active, `[2024-01-15 Mon]` inactive
- `C-c .` insert timestamp, `C-c !` inactive
- `C-c C-d` DEADLINE, `C-c C-s` SCHEDULED
- `+1w` weekly repeater, `+1m` monthly
- `S-LEFT/RIGHT` ±1 day, `S-UP/DOWN` change year/month/day

## Clocking

- `C-c C-x C-i` start clock
- `C-c C-x C-o` stop clock
- `C-c C-x C-d` display times
- `C-c C-x C-r` insert clock report table

## Refile & Archive

- `C-c C-w` refile entry
- `C-c C-x C-s` move to archive file
- `C-c C-x a` toggle ARCHIVE tag

## Capture

- `C-c c` capture new item
- Templates: `C-c c C-c` select template

## Agenda

- `C-c a a` weekly agenda
- `C-c a t` global TODO list
- `C-c a m` match tags/properties
- `C-c [` add file to agenda
- In agenda: `d/w/m` day/week/month view, `t` change state

## Babel/Source Blocks

- `C-c C-c` execute block
- `C-c '` edit in separate buffer
- `#+BEGIN_SRC lang` ... `#+END_SRC`
- Header args: `:var`, `:results`, `:exports`, `:tangle`

## LaTeX

- `C-c C-x C-l` preview fragment
- `$inline$` or `$$display$$`
- `#+OPTIONS: tex:t` for LaTeX processing

## Export

- `C-c C-e` export dispatcher
- `C-c C-e #` insert export options template

## Key Bindings Summary

| Key     | Action           |
| ------- | ---------------- |
| TAB     | Cycle visibility |
| M-RET   | New heading      |
| C-c C-t | TODO state       |
| C-c .   | Timestamp        |
| C-c l   | Store link       |
| C-c c   | Capture          |
| C-c a   | Agenda           |
| C-c /   | Sparse tree      |

# Org-roam Cheat Sheet

## Overview

- Tool for networked thought in Emacs/Org-mode
- Reproduces Roam Research features
- Based on Zettelkasten (slip-box) method
- Plain text + SQLite database cache

## Terminology

- **Node**: Any headline or top-level file with an ID property
- **Fleeting notes**: Quick capture, processed later
- **Permanent notes**: Literature notes (annotations) or concept notes (detailed)

## Core Commands

| Command                      | Description             |
| ---------------------------- | ----------------------- |
| `M-x org-roam-node-find`     | Create/open note        |
| `M-x org-roam-node-insert`   | Insert link to note     |
| `M-x org-roam-capture`       | Capture with templates  |
| `M-x org-roam-buffer-toggle` | Show backlinks buffer   |
| `M-x org-id-get-create`      | Add ID to headline/file |
| `M-x org-roam-db-sync`       | Build cache manually    |

## Installation

```elisp
(require 'package)
(add-to-list 'package-archives '("melpa" . "http://melpa.org/packages/") t)
M-x package-install RET org-roam RET
```

**Dependencies**: org, emacsql, magit-section

## Setup

```elisp
(make-directory "~/org-roam")
(setq org-roam-directory (file-truename "~/org-roam"))
(org-roam-db-autosync-mode)
```

## Node Properties

| Property           | Purpose                          |
| ------------------ | -------------------------------- |
| `:ID:`             | Required for node                |
| `:ROAM_ALIASES:`   | Alternative names (searchable)   |
| `:ROAM_REFS:`      | Unique IDs (URLs, citation keys) |
| `:ROAM_EXCLUDE: t` | Exclude from database            |
| Tags               | Regular Org tags                 |

## Links

- Use ID links: `[[id:FOO][Link Text]]`
- Completion via `completion-at-point`

## Templates

```elisp
(setq org-roam-capture-templates
  '(("d" "default" plain "%?"
     :target (file+head "${slug}.org"
                        "#+title: ${title}\n")
     :unnarrowed t)))
```

- Variables: `${title}`, `${slug}`, `${file}`, `${foo}` (custom accessors)

## org-roam-dailies (Journaling)

```elisp
(setq org-roam-dailies-directory "daily/")
(setq org-roam-dailies-capture-templates
  '(("d" "default" entry "* %?"
     :target (file+head "%<%Y-%m-%d>.org"
                        "#+title: %<%Y-%m-%d>\n"))))
```

- `M-x org-roam-dailies-capture-today`
- `M-x org-roam-dailies-goto-today`

## org-roam-protocol (Browser capture)

```elisp
(require 'org-roam-protocol)
```

- `org-protocol://roam-node?node=ID`
- `org-protocol://roam-ref?ref=URL`

## org-roam-graph

```elisp
M-x org-roam-graph
(setq org-roam-graph-executable "dot")
```

## Buffer Display

```elisp
(add-to-list 'display-buffer-alist
 '("\\*org-roam\\*"
   (display-buffer-in-direction)
   (direction . right)
   (window-width . 0.33)))
```

## Key Variables

- `org-roam-directory`: Note storage location
- `org-roam-node-display-template`: Node display format
- `org-roam-db-update-on-save`: Auto-update cache
- `org-roam-completion-everywhere`: Enable link completion everywhere

## Performance

```elisp
(setq org-roam-db-gc-threshold most-positive-fixnum)
```

## Ecosytem Tools

- **Deft**: Full-text search (`C-c n d`)
- **org-ref**: Citations
- **org-roam-bibtex**: BibTeX integration
- **winner-mode**: Browser-like history (`M-left`/`M-right`)
