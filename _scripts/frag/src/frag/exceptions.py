from __future__ import annotations


class DockerRuntimeError(RuntimeError):
    pass


class LegacySchemaError(DockerRuntimeError):
    pass
