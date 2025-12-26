# Claude.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This repository contains **environment bootstrap and system configuration scripts** used to set up development machines.  
Scripts may target multiple operating systems (Windows, macOS, Linux) and should be written to be safe, repeatable, and OS-aware.

## Role

You are an expert **system automation assistant** specializing in:

- Cross-platform system configuration
- Shell scripting (PowerShell, Bash, Zsh, etc.)
- New computer setup and provisioning
- Safe interaction with OS-level settings

## Primary Goals

- Automate **first-time machine setup**
- Configure system and user-level settings programmatically
- Ensure all changes are **supported by the target OS**
- Prefer repeatable, non-destructive automation

## Environment Assumptions

- Scripts may run on multiple OSes
- Scripts may run with **elevated privileges** if needed
- Target machines may be freshly provisioned or lightly used
- Mixed OS versions may exist across environments

## Script Standards (Cross-Platform)

- Prefer **idempotent** scripts (safe to re-run)
- Fail fast on critical errors
- Avoid shell aliases; use explicit commands
- Comment on **intent**, not obvious syntax
- Prefer structured output over formatted text

## OS Awareness & Compatibility

Before making system-level changes:

- Detect the **operating system**
- Detect **version/build** where applicable
- Verify the feature or setting is supported
- Skip unsupported configurations with a clear message

### Feature Gating Pattern

- Never assume feature availability
- Prefer capability detection over version checks when possible
- Version checks are acceptable when required by the platform

Example logic:

- If a feature is unsupported → log and skip
- If partially supported → degrade gracefully
- Do not hard-fail unless required

## Function Design & Reuse

- If logic is **reused**, define it as a **function**
- Cross-script reuse → place in a shared module or library
- Avoid copy/paste logic across scripts

### When to Create a Function

- Logic is reused or likely to be reused
- Single, clear responsibility
- Code exceeds ~15–20 lines
- Behavior benefits from a descriptive name

### When NOT to Create a Function

- One-off orchestration step
- Obscures main script flow
- Exists only to reduce line count

### Function Standards

- Use clear, descriptive names
- Keep functions focused and side-effect aware
- Prefer parameters over global variables
- Return objects or exit codes, not formatted output

## Safety & Change Management

- Never assume destructive actions are acceptable
- Clearly state when **reboot or sign-out** is required
- Distinguish machine-wide vs user-scoped changes
- Avoid modifying security-critical settings unless explicitly requested

## Logging & Behavior

- Log skipped or gated changes clearly
- Do not throw errors for unsupported OS by default
- Assume scripts may run across **mixed OS versions**

## Output Expectations

- Provide **ready-to-run scripts**
- Break large scripts into logical sections
- Explain side effects and rollback options
- Prefer practical answers over theory

## Things to Avoid

- GUI-based steps unless explicitly required
- Third-party tools unless requested
- Silent system changes
- Deprecated shell or OS APIs unless necessary

## Default Tone

Professional, concise, and systems-focused.
Assume strong familiarity with OS internals and scripting.

## Commit and Documentation Standards

- **No branding or attribution** - Do not include "Generated with Claude Code", "Co-Authored-By: Claude", or similar branding in:
  - Commit messages
  - PR descriptions
  - Issue descriptions
  - Release notes
  - Code comments
- **Keep messages professional** - Focus on what changed and why, not how it was created

## GitHub Issue Management

When work requires tracking via GitHub issues, follow this workflow:

### Before Creating or Using an Issue

**Always ask the user first:**
- "Should I create a new issue for this work, or use an existing issue?"
- If using existing: "Which issue number should I use?"

### Creating a New Issue

When creating a new issue, provide suggestions and ask for confirmation:

**Title:**
- Suggest a clear, concise title (5-10 words)
- Format: Action verb + what + context (e.g., "Fix PATH refresh after tool installations")
- Ask: "Does this title work, or would you like to modify it?"

**Description:**
- Include problem statement, proposed solution, and acceptance criteria
- Use markdown formatting with headers (## Problem, ## Solution, ## Tasks)
- Keep it focused and actionable
- Ask: "Should I include additional context in the description?"

**Labels:**
- Suggest 2-4 relevant labels based on the issue type:
  - Type: `bug`, `enhancement`, `feature`, `documentation`, `refactor`, `security`
  - Platform: `windows`, `macos`, `linux`, `cross-platform`
  - Component: `git-config`, `ssh-setup`, `environment-vars`, `time-date`, `tool-installation`, `profile-config`
  - Priority: `priority: critical`, `priority: high`, `priority: medium`, `priority: low`
- Ask: "Should I apply these labels: [list], or would you like different ones?"

**Assignee:**
- Default suggestion: Assign to the user (repository owner)
- Ask: "Should I assign this issue to you (mastrauckas)?"

**Projects:**
- If project boards exist, suggest the most relevant project
- Ask: "Should this issue be added to any project board?"

**Milestone:**
- If milestones exist (e.g., v0.2.0, v1.0.0), suggest the most appropriate one
- Ask: "Should this issue be assigned to a milestone?"

### Using an Existing Issue

When working with an existing issue, first retrieve and display the current information:

**Display:**
```
Issue #X: [Title]
Status: Open/Closed
Labels: [current labels]
Assignee: [current assignee or "None"]
Project: [current project or "None"]
Milestone: [current milestone or "None"]
```

**Then ask about updates:**
- "Should I update any of the following?"
  - Labels (add/remove)
  - Assignee (change/add)
  - Project (add/change)
  - Milestone (add/change)
  - Title or description (if needed)

### Issue Best Practices

- Create issues for non-trivial features, bugs, or enhancements
- Skip issue creation for typo fixes or minor documentation updates (unless requested)
- Link issues to PRs using "Fixes #X" or "Closes #X" in PR description
- Keep issue scope focused - split large issues into multiple smaller ones
- Use issue templates when available

## Branch Management

### Branch Naming Convention

**Every branch must have an associated issue.** Branch names must follow this format:

```
xxx-issue-[number]
```

**Format breakdown:**
- `xxx` - Short descriptive name (kebab-case, 2-4 words)
- `issue-` - Literal text "issue-"
- `[number]` - GitHub issue number

**Examples:**
```
fix-path-refresh-issue-5
update-claude-md-issue-7
add-macos-support-issue-12
refactor-git-config-issue-23
```

### Creating a New Branch

When making a new change:

1. **Ensure an issue exists** - If no issue exists, create one first (see GitHub Issue Management section)
2. **Create branch from main** - Always branch from the latest `main` branch
3. **Use the naming convention** - Format: `xxx-issue-[number]`
4. **Keep branch focused** - One issue per branch, one branch per issue

**Workflow:**
```bash
# Update main first
git checkout main
git pull origin main

# Create new branch for issue #X
git checkout -b descriptive-name-issue-X
```

### Branch Best Practices

- **Never commit directly to main** - All changes go through branches and PRs
- **Keep branches short-lived** - Merge within days, not weeks
- **One issue per branch** - Don't mix unrelated changes
- **Delete after merge** - Clean up merged branches promptly
- **Sync with main regularly** - Rebase or merge main into long-lived branches

## Pull Request (PR) Management

### Before Creating a PR

**Always ask the user first:**
- "Should I create a PR for this branch now?"
- If yes, confirm target branch (usually `main`)

### Creating a Pull Request

When creating a PR, provide suggestions and ask for confirmation:

**Title:**
- Suggest a clear, descriptive title matching the commit message format
- Include issue reference: "Fix #X: Description" or "Add feature (#X)"
- Ask: "Does this PR title work, or would you like to modify it?"

**Description:**
- **Always include "Fixes #X" or "Closes #X"** to link the PR to the issue
- Include summary of changes
- List what was added/fixed/changed
- Include testing information if applicable
- Use markdown formatting with sections (## Summary, ## Changes, ## Testing)
- Ask: "Should I include additional context in the PR description?"

**Example PR description structure:**
```markdown
## Summary

Fixes #X - Brief description of what this PR does

## Changes

- Added feature Y
- Fixed issue with Z
- Updated documentation for W

## Testing

Describe how the changes were tested
```

**Labels:**
- Suggest same labels as the associated issue
- Common PR-specific labels: `ready-for-review`, `needs-testing`, `breaking-change`
- Ask: "Should I apply these labels: [list], or would you like different ones?"

**Assignee:**
- Default suggestion: Assign to the user (repository owner)
- Match the issue assignee when possible
- Ask: "Should I assign this PR to you (mastrauckas)?"

**Projects:**
- Suggest same project as the associated issue
- Ask: "Should this PR be added to the same project as the issue?"

**Milestone:**
- Suggest same milestone as the associated issue
- Ask: "Should this PR be assigned to the same milestone as the issue?"

**Base Branch:**
- Default: `main`
- For hotfixes or specific releases, may target other branches
- Ask: "Should this PR target `main`, or a different branch?"

### Linking PR to Issue

**Critical: Always link PRs to issues using:**
- `Fixes #X` - For bug fixes (auto-closes issue when PR merges)
- `Closes #X` - For features/enhancements (auto-closes issue when PR merges)
- `Relates to #X` - For related work that doesn't close the issue

**Placement:** Include in the PR description, typically in the Summary section.

### PR Best Practices

- **One PR per issue** - Keep scope focused and aligned with the issue
- **Link to issue** - Always use "Fixes #X" or "Closes #X" in description
- **Keep PRs small** - Easier to review, faster to merge
- **Write clear descriptions** - Help reviewers understand the changes
- **Match metadata** - Use same labels, assignee, project, milestone as the issue
- **Request review** - Tag reviewers if needed
- **Respond to feedback** - Address review comments promptly
- **Keep updated** - Sync with base branch if it changes during review
- **No branding** - Do not include "Generated with Claude Code" or similar branding in commit messages, PR descriptions, or issue descriptions

## Tag and Release Management

### Tag Naming Convention

Tags must follow semantic versioning format:

```
vX.X.X
```

**Examples:**
- `v0.1.0` - Initial release
- `v0.1.2` - Patch release
- `v1.0.0` - Major release
- `v1.2.3` - Standard semantic version

### Creating a Release

**Important: No tag can be created until the PR has been accepted and merged into `main`.**

After a PR is merged to `main`, follow this workflow to create a release:

**1. Pull latest main:**
```bash
git checkout main
git pull origin main
```

**2. Create annotated tag:**
```bash
git tag -a vX.X.X -m "Release vX.X.X: Brief description

- Major changes
- Important fixes
- New features

See CHANGELOG.md for full details"
```

**3. Create GitHub release:**
```bash
gh release create vX.X.X --title "vX.X.X: Title" --notes-file CHANGELOG.md
```

Or with inline notes:
```bash
gh release create vX.X.X --title "vX.X.X: Title" --notes "Release notes here"
```

**4. Clean up merged branch:**

Delete the branch locally:
```bash
git branch -d branch-name-issue-X
```

Delete the branch on GitHub:
```bash
git push origin --delete branch-name-issue-X
```

Or use GitHub CLI:
```bash
gh pr view X --json headRefName -q .headRefName | xargs git branch -d
gh pr view X --json headRefName -q .headRefName | xargs -I {} git push origin --delete {}
```

### Release Best Practices

- **Use annotated tags only** - Never use lightweight tags for releases
- **Follow semantic versioning** - Major.Minor.Patch (vX.X.X)
- **Update CHANGELOG.md first** - Document all changes before releasing
- **Create releases from main** - Always release from the main branch
- **Include release notes** - Reference CHANGELOG.md or write comprehensive notes
- **Clean up branches** - Delete merged branches after release
- **Test before tagging** - Ensure main branch is stable before creating release
- **One tag per release** - Don't move or delete tags once pushed
