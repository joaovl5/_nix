#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.13"
# dependencies = [
#     "cyclopts>=4.5.1",
#     "pydantic>=2.11.0",
# ]
# ///

from __future__ import annotations

import json
import re
import unicodedata
from datetime import datetime
from pathlib import Path
from typing import ClassVar

from cyclopts import App, CycloptsError
from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    ValidationError,
    ValidationInfo,
    field_validator,
)

SHORT_TITLE_MAX_LENGTH = 96
SHORT_TITLE_MIN_LENGTH = 10
REPORT_BRIEF_MAX_LENGTH = 280
REPORT_BRIEF_MIN_LENGTH = 30
DATE_SLUG_PATTERN = re.compile(r"^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}$")
TITLE_SLUG_PATTERN = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
TEMPLATE_PLACEHOLDER_PATTERN = re.compile(r"<([a-z_]+)>")
VALIDATION_FIELD_LABELS = {
    "date_slug": "date slug",
    "short_title": "short title",
    "short_title_slug": "short title",
    "report_brief": "report brief",
}

app = App(
    name="add-log",
    result_action="return_value",
    exit_on_error=False,
    print_error=False,
)


def contains_control_characters(value: str) -> bool:
    return any(unicodedata.category(character).startswith("C") for character in value)


def meaningful_character_count(value: str) -> int:
    normalized = unicodedata.normalize("NFKC", value)
    return sum(character.isalnum() for character in normalized)


def normalize_for_comparison(value: str) -> str:
    normalized = unicodedata.normalize("NFKC", value).casefold()
    return " ".join(normalized.split())


class LogTemplateInput(BaseModel):
    model_config: ClassVar[ConfigDict] = ConfigDict(
        extra="forbid", str_strip_whitespace=True
    )

    timestamp: int = Field(gt=0)
    date_slug: str
    short_title: str = Field(
        min_length=SHORT_TITLE_MIN_LENGTH,
        max_length=SHORT_TITLE_MAX_LENGTH,
    )
    short_title_slug: str
    report_brief: str = Field(
        min_length=REPORT_BRIEF_MIN_LENGTH,
        max_length=REPORT_BRIEF_MAX_LENGTH,
    )

    @field_validator("date_slug")
    @classmethod
    def validate_date_slug(cls, value: str) -> str:
        if not DATE_SLUG_PATTERN.fullmatch(value):
            raise ValueError("must use the format YYYY-MM-DD_HH-MM")
        return value

    @field_validator("short_title", "report_brief")
    @classmethod
    def validate_single_line(cls, value: str) -> str:
        if "\n" in value or "\r" in value:
            raise ValueError("must be a single line")
        if contains_control_characters(value):
            raise ValueError("must not contain control characters")
        return value

    @field_validator("short_title_slug")
    @classmethod
    def validate_short_title_slug(cls, value: str, info: ValidationInfo) -> str:
        if not value:
            raise ValueError(
                "must slugify to at least one ASCII letter or number; punctuation-only, emoji-only, or non-ASCII-only titles cannot be used as filenames"
            )
        if not TITLE_SLUG_PATTERN.fullmatch(value):
            raise ValueError(
                "must contain only lowercase letters, numbers, and single hyphens"
            )

        short_title = info.data.get("short_title")
        if isinstance(short_title, str) and value != slugify(short_title):
            raise ValueError("must match the slug generated from the short title")
        return value

    def render_context(self) -> dict[str, str | int]:
        return {
            "timestamp": self.timestamp,
            "date_slug": self.date_slug,
            # JSON string encoding keeps YAML frontmatter valid for arbitrary single-line input.
            "short_title": json.dumps(self.short_title, ensure_ascii=False),
            "report_brief": json.dumps(self.report_brief, ensure_ascii=False),
        }


def slugify(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value)
    ascii_only = normalized.encode("ascii", "ignore").decode("ascii")
    slug = re.sub(r"[^a-z0-9]+", "-", ascii_only.casefold()).strip("-")
    return slug


def build_template_input(short_title: str, report_brief: str) -> LogTemplateInput:
    now = datetime.now().astimezone()
    return LogTemplateInput(
        timestamp=int(now.timestamp()),
        date_slug=now.strftime("%Y-%m-%d_%H-%M"),
        short_title=short_title,
        short_title_slug=slugify(short_title),
        report_brief=report_brief,
    )


def format_validation_error(error: ValidationError) -> str:
    lines = ["Validation failed:"]
    for entry in error.errors():
        raw_location = ".".join(str(part) for part in entry["loc"]) or "input"
        location = VALIDATION_FIELD_LABELS.get(
            raw_location, raw_location.replace("_", " ")
        )
        message = entry["msg"]
        if message.startswith("Value error, "):
            message = message.removeprefix("Value error, ")
        lines.append(f"- {location}: {message}")
    return "\n".join(lines)


def template_path() -> Path:
    return Path(__file__).resolve().parent / "log_templates" / "base.md"


def output_dir() -> Path:
    skill_dir = Path(__file__).resolve().parent.parent
    return skill_dir.parent.parent.parent / "docs" / "logs"


def render_template(template_file: Path, context: LogTemplateInput) -> str:
    template = template_file.read_text(encoding="utf-8")
    replacements = context.render_context()

    placeholders = set(TEMPLATE_PLACEHOLDER_PATTERN.findall(template))
    unknown_placeholders = sorted(placeholders - replacements.keys())
    if unknown_placeholders:
        formatted_placeholders = ", ".join(
            f"<{placeholder}>" for placeholder in unknown_placeholders
        )
        raise ValueError(
            f"Template contains unsupported placeholders: {formatted_placeholders}"
        )

    return TEMPLATE_PLACEHOLDER_PATTERN.sub(
        lambda match: str(replacements[match.group(1)]),
        template,
    )


@app.default
def main(short_title: str, report_brief: str) -> int:
    """Create a new docs/logs incident report from the base template."""

    try:
        log_input = build_template_input(
            short_title=short_title,
            report_brief=report_brief,
        )
    except ValidationError as error:
        print(format_validation_error(error))
        return 1

    resolved_template_path = template_path()
    if not resolved_template_path.is_file():
        print(f"Template not found: {resolved_template_path}")
        return 1

    resolved_output_dir = output_dir()
    resolved_output_dir.mkdir(parents=True, exist_ok=True)
    destination = (
        resolved_output_dir / f"{log_input.timestamp}_{log_input.short_title_slug}.md"
    )
    if destination.exists():
        print(f"Refusing to overwrite existing log file: {destination}")
        return 1

    try:
        rendered = render_template(resolved_template_path, log_input)
    except ValueError as error:
        print(error)
        return 1

    destination.write_text(rendered, encoding="utf-8")

    print(destination)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(app())
    except CycloptsError as error:
        print(error)
        raise SystemExit(1)
