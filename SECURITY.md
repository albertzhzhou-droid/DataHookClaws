# Security Policy

## Supported Versions

This project is currently in active prototype and pre-release development. Only
the current `main` branch is expected to receive security fixes.

## Reporting A Vulnerability

Please report security issues privately to the repository owner through GitHub.
If private vulnerability reporting is not available, open a minimal public issue
that avoids exploit details and request a private follow-up channel.

Include:

- affected platform and version
- steps to reproduce
- expected and actual behavior
- impact assessment
- any relevant logs with secrets removed

## Security Boundaries

- Do not commit API keys, local database snapshots, exported nutrition data, or
  downloaded official dataset artifacts.
- Local Ollama endpoints are treated as user-configured local services.
- Exported files may contain source-derived material and should be handled as
  user data.
- AI suggestions are non-authoritative and must not bypass deterministic
  governance or source-license controls.
