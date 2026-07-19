---
name: update-gitlab-ci-versions
type: skill
description: Use when updating devtools-gitlab-includes ref version or DEV_TOOLS_IMAGE_VERSION in a .gitlab-ci.yml file in the airlab/sdg ecosystem. Triggers on requests like "update devtools", "bump ci versions", "update gitlab-ci devtools", or "update dev tools image version".
tags: [devtools, gitlab-ci]
version: 1.0.0
compatibility: [copilot, claude]
---

# GitLab CI Devtools Version Update

## Overview

Updates two versioned references in `.gitlab-ci.yml`. Versions are fetched live from GitLab via
`git ls-remote`.

The `devtools-gitlab-ci` rule has the repo URL and version-fetching instructions for
`devtools-gitlab-includes`. The `developer-tools` rule has the repo URL and version-fetching
instructions for `developer-tools`.

## Steps

### 1. Fetch latest tags for both repos

Run both in parallel using the `git ls-remote --tags` commands from the `devtools-gitlab-ci` and
`developer-tools` rules.

Extract the tag name as-is — preserve the `v` prefix if present, since it must match the format
already used in `.gitlab-ci.yml`.

### 2. Read current `.gitlab-ci.yml`

File is typically `.gitlab-ci.yml` (not `.yaml`). Read it before editing.

The file contains an include block referencing `devtools-gitlab-includes` and a `DEV_TOOLS_IMAGE_VERSION`
variable. Other variables (e.g. `GIT_DEPTH`, `DEV_TOOLS_PLAYWRIGHT_INSTALL`) are project-specific
— do not touch them. Examples:

```yaml
# Spring Boot project
include:
  - project: ams/airlab-sg/common/components/devtools-gitlab-includes
    ref: v3.25.1
    file:
      - includes/templates/spring_boot.yaml

variables:
  DEV_TOOLS_IMAGE_VERSION: 1.42.4
```

```yaml
# npm / frontend project
include:
  - project: ams/airlab-sg/common/components/devtools-gitlab-includes
    ref: v3.28.0
    file:
      - includes/templates/npm.yaml

variables:
  GIT_DEPTH: 0
  DEV_TOOLS_IMAGE_VERSION: 1.43.0
  DEV_TOOLS_PLAYWRIGHT_INSTALL: 1
```

### 3. Update `.gitlab-ci.yml`

Update two values if they differ from latest:

- `ref:` under the `devtools-gitlab-includes` include block → latest tag from devtools-gitlab-includes repo
- `DEV_TOOLS_IMAGE_VERSION:` → latest tag from developer-tools repo (strip `v` prefix if the current value has no `v`)

Only edit lines that actually change. Do not reformat the file.

## Quick Reference

| What to update | File | Key |
|----------------|------|-----|
| devtools-gitlab-includes version | `.gitlab-ci.yml` | `ref:` under the include block |
| Dev tools image version | `.gitlab-ci.yml` | `DEV_TOOLS_IMAGE_VERSION` |

## Common Mistakes

- **Picking wrong latest tag** — sort semantically (`3.10.0 > 3.9.0`), not lexicographically.
- **Stripping/adding `v` prefix incorrectly** — match the format already used in the file (`ref: v3.25.1` keeps `v`; `DEV_TOOLS_IMAGE_VERSION: 1.42.4` has no `v`).
- **Touching unrelated variables** — only update `ref:` and `DEV_TOOLS_IMAGE_VERSION`. Leave all other variables as-is.
- **Editing `.gitlab-ci.yaml`** — the file extension in this ecosystem is `.yml`, not `.yaml`.
