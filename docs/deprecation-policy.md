# Deprecation policy

After `1.0.0`, a public API scheduled for removal remains available for at least one minor release and normally six months. The warning, replacement, first deprecated version, and earliest removal version must be documented in the changelog and migration material.

Warnings are emitted at most once per process through the configured safe logger and must not include application payloads. Security fixes, behavior that can expose secrets, and upstream runtime incompatibilities may require faster action; the security advisory and changelog must explain the exception. Ruby/Rails support changes are recorded in `docs/compatibility.md` before removal.

Prereleases may revise APIs without the full stable window, but every incompatible revision must remain explicit. Version `0.9.0.pre.2` introduces no removal.
