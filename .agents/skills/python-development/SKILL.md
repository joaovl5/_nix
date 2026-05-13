---
name: python-development
description: Use when editing/writing/debugging Python code
---

# Python Development

- Python 3.14 and above is expected in this workspace. Do not write compatibility code for older versions.
- We use `uv` for Python tooling
  - Run apps with `uv run`

## Typing

- We use **strongly-typed** Python with **3.14** as baseline
  - Never add `from __future__ import annotations`
  - Pattern matching with `match` when it makes variant handling clearer than plain `if`
- Keep strict typing intact
  - **Never** use `cast(...)`
  - Avoid using `Any` unless no cleaner option
- Public functions/methods should:
  - Be keyword-only (with `*, foo: int, bar: str` or `self, *, foo: int, bar: str`) if they have more than one argument (besides self)
  - Have docstrings that:
    - are concise by default (one-liners)
    - ellaborate further for non-trivial behavior/concepts
    - get treated as 1st-class citizens
  - **NEVER** use `noqa` or `pyrightIgnore` statements
    - if, for instance, a test requires hardcoded mocked secrets like `oauth-refresh-token` that trigger the respective ruff warning `S105`, don't deactivate it - instead, deactivate it for test files in general in `pyproject.toml` through a glob pattern matching test files
    - if you'll deactivate warnings in `pyproject.toml`, must **ALWAYS** have an inline comment in the file stating the exact motive for the supression of the warning

## Data Modeling

- Use pydantic `BaseModel` for serializable objects: configs, requests/response DTOs
- Use `define` from `attrs` instead of dataclasses or ad-hoc state-holder classes
- Create dedicated `<Thing>Error` hierarchies (with more specific errors subclassing the main module error type) usually within module-local `errors.py` boundary
- **NEVER** use `TypedDict` or `dataclasses` unless there's absolutely no alternative - which in that case **MUST** make a comment next to the exceptional use explaining the reasoning for it.
- _For closed scalar choices without payload, may use simple enums_
- _For complex variants, consider using algebraic data types over enums:_
  - have ADT-related classes and type aliases within a namespace (class)
  - model each variant as its own type, with only the fields that variant needs
  - define a closed union for allowed variants
  - use pattern matching for handling of these values
  - example:

  ```python
  # instead of:
  class GenderType(Enum):
    MALE = "male"
    FEMALE = "female"
    OTHER = "other"

  # do this:
  class Gender:
      class Male(BaseModel): ...
      class Female(BaseModel): ...
      class Other(BaseModel):
        name: str | None = None

      type Type = Gender.Male | Gender.Female | Gender.Other

  # then later:
  some_gender: Gender.Type
  match some_gender:
    case Gender.Male(x):
        print("it's a male")
    case Gender.Female(x):
        print("it's a female")
    case Gender.Other(x):
        print(f"it's a {x.name or 'other'}")
  ```

**Follow the decision flow below for reference:**

- "I need to model a new type"
  - _is type an error?_ - follow the `<Thing>Error` flow
  - _relates to multiple-choices of different values?_
    - _yes_ - _are all choices scalar and don't have payloads?_
      - _yes_ - use a simple `StrEnum`
      - _no_ - complex variant - create an algebraic data type
    - _no_ - _should type be serializable/validated?_
      - _yes_ - use Pydantic-related flows - `BaseMdel`
      - _no_ - use `@define` from `attrs`
  - **NEVER USE UNLESS IN EXTRAORDINARY CIRCUMSTANCES:**
    - `TypedDict`
    - `dataclasses`

## Modules

- Module-related error handling should be subclassing-based instead of having error messages - use subclassing for specificity
  - Extra info (debugging or user-facing) may be injected into payload for error classes (more or less akin to algebraic data type)
- When a module grows beyond one clear responsibility, it should be split into a folder-based module of this shape:
  - `__init__.py` - module-wide docstring, public exports with `__all__` - these are the only place to re-export with `__all__`, **NEVER** export with `__all__` in files that aren't `__init__.py`
  - `errors.py` - for exception types
  - `types.py` - models/typed payloads
  - `main.py` - core logic
  - `utils.py` - focused helpers
  - `tests/` - module-scoped unit tests

## Testing Rules

- We use `pytest` as a testing library
- Do **NOT** hardcode dynamic stuff in tests - you **MUST ONLY** test _input vs. output_ for a given scope, and never hidden logic prone to change - that means:
  - hardcoding tests to state some Enum only has some values, or an associated key in a dict has an expected value (doesn't test anything meaninful, code duplication)
  - asserting on private logic, internal delegation is bad unless it truly protects a real external guarantee which is **static** and could've not been gotten simply through public-facing assertions
- Overlapping cases should get merged for easier reading of tests - through parametrization, helper functions, and other means
- Tests should **CLEARLY** state their intent comprehensively:
  - **Every** test function should have a docstring explaining their scope clearly.
  - **Every** non-trivial assertion should have a comment above it explaining what is being asserted
- Tests **MUST** sit next to their modules, within a `tests/` folder and having a `*.test.py` format
