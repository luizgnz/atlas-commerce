terraform {
  # Intentionally uses local state. This bootstrap creates the remote S3
  # backend itself, so it cannot depend on a backend that does not exist yet.
}