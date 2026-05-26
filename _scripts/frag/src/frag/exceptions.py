class DockerRuntimeError(RuntimeError):
  """Report runtime failures while managing frag containers."""


class LegacySchemaError(DockerRuntimeError):
  """Refuse legacy schema artifacts that require recreation."""
