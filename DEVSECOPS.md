# DevSecOps Setup for This Repository

This document explains what's been added for security automation, why it's
configured the way it is, and what's still left for you to do manually.

## What's automated

| Layer | Tool | Where |
|---|---|---|
| SAST | CodeQL | `.github/workflows/security.yml` |
| Dependency / license review on PRs | `dependency-review-action` | same file |
| IaC misconfiguration + filesystem vuln scan | Trivy | same file |
| Dependency & action updates | Dependabot | `.github/dependabot.yml` |
| Local secret/lint checks before commit | pre-commit (gitleaks, shellcheck) | `.pre-commit-config.yaml` |
| Vulnerability disclosure process | — | `SECURITY.md` |

All three CI jobs run on push to `main`, on pull requests, weekly (to catch
newly disclosed CVEs against unchanged code), and on manual trigger.

## Why everything is pinned to a commit SHA, not a version tag

Every third-party action in `security.yml` is referenced like
`aquasecurity/trivy-action@57a97c7e7821...` with the human-readable version
in a trailing comment, rather than `@v0.35.0` or `@master`.

This isn't paranoia for its own sake. In March 2026, `aquasecurity/trivy-action`
— a security-scanning action used in thousands of pipelines — was the target
of a real supply-chain attack (CVE-2026-33634): attackers with compromised
maintainer credentials force-pushed 76 of its 77 version tags to point at a
credential-stealing payload. Any workflow referencing a *tag* (even a
specific one like `@v0.34.2`) silently started running malicious code the
moment that tag moved. Workflows pinned to a full commit SHA were unaffected,
because a SHA always refers to the same content no matter what happens to
tags afterward.

GitHub's own security documentation has recommended SHA-pinning for years;
this incident is what that warning was about. The trade-off is that SHAs are
less readable and don't auto-update — which is why Dependabot is configured
for the `github-actions` ecosystem above. Dependabot understands SHA pins and
will open a PR bumping the SHA while showing you the new version number, so
you keep the security benefit without manually tracking every release.

**Do not change any `uses: ...@<sha>` line to a bare version tag or
`@master`/`@main` for convenience.** If you want to bump a pin manually,
resolve the tag to its full SHA first (e.g.
`git ls-remote https://github.com/<owner>/<repo>.git refs/tags/<tag>`) and
verify it against the project's own release notes.

## What you still need to do (can't be automated from here)

1. **Fill in `SECURITY.md`** — replace the `TODO` placeholder with a real
   contact email or rely solely on GitHub Security Advisories.

2. **Set branch protection on `main`** (Settings → Branches → Add rule):
   - Require a pull request before merging
   - Require status checks to pass before merging — select `CodeQL (SAST)`
     and `Trivy (IaC + filesystem)` once they've run at least once
   - Consider requiring signed commits

3. **Confirm secret scanning is on** (Settings → Code security and
   analysis). For public repositories this is free and normally on by
   default, but it's worth checking that both "Secret scanning" and "Push
   protection" show as enabled.

4. **Install pre-commit locally** if you want the gitleaks/shellcheck checks
   to run before you commit, not just in CI:
   ```bash
   pip install pre-commit --break-system-packages
   pre-commit install
   ```

5. **Decide when to tighten Trivy from report-only to blocking.** Right now
   both Trivy steps use `exit-code: "0"`, so findings show up in the
   Security tab but don't fail the build. Once you've triaged the initial
   findings (for example, the default Wazuh credentials documented in
   `wazuh/single-node/DIGITALOCEAN_DEPLOY.md`), change `exit-code: "0"` to
   `"1"` in `security.yml` so new high/critical issues block merges.

6. **Add more CodeQL languages as the codebase grows.** Right now
   `languages: actions` only analyzes the GitHub Actions workflows
   themselves, since that's the only "code" in the repo so far. Once you add
   Python, JavaScript, Go, etc., update the `languages:` line in
   `security.yml` to include them (comma-separated).
