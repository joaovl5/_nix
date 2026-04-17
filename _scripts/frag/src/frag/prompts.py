from __future__ import annotations

from collections.abc import Sequence

import questionary

_CREATE_PROFILE_CHOICE = "Create a new profile"
_CREATE_PROFILE_SENTINEL = object()


class PromptAborted(RuntimeError):
    pass


def _ask_prompt(prompt: object) -> object:
    try:
        answer = prompt.ask()
    except (EOFError, KeyboardInterrupt) as error:
        raise PromptAborted() from error
    if answer is None:
        raise PromptAborted()
    return answer


def _ask_required_prompt(prompt: object) -> str:
    answer = str(_ask_prompt(prompt))
    if not answer.strip():
        raise PromptAborted()
    return answer


def prompt_select_profile(names: Sequence[str]) -> str | None:
    if not names:
        return None
    try:
        answer = _ask_prompt(
            questionary.select("Select a frag profile", choices=list(names))
        )
    except PromptAborted:
        return None
    return str(answer)


def prompt_enter_profile_action(names: Sequence[str]) -> tuple[str, str | None]:
    if not names:
        return ("create", None)
    answer = _ask_prompt(
        questionary.select(
            "Select a frag profile",
            choices=[
                *names,
                questionary.Choice(
                    title=_CREATE_PROFILE_CHOICE,
                    value=_CREATE_PROFILE_SENTINEL,
                ),
            ],
        )
    )
    if answer is _CREATE_PROFILE_SENTINEL:
        return ("create", None)
    return ("existing", str(answer))


def confirm_profile_removal(name: str) -> bool:
    try:
        answer = _ask_prompt(questionary.confirm(f"Remove frag profile '{name}'?"))
    except PromptAborted:
        return False
    return bool(answer)


def prompt_profile_name() -> str:
    return _ask_required_prompt(questionary.text("Profile name"))


def prompt_profile_image(image_keys: Sequence[str]) -> str:
    if not image_keys:
        raise PromptAborted()
    return str(_ask_prompt(questionary.select("Image", choices=list(image_keys))))


def prompt_workspace_root() -> str:
    return _ask_required_prompt(questionary.path("Workspace root"))


def require_non_blank(value: str | None) -> str:
    if value is None or not value.strip():
        raise PromptAborted()
    return value
