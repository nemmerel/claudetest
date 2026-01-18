# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a test repository configured with Claude Code GitHub Actions automation.

## GitHub Actions Workflows

Two Claude Code workflows are configured:

1. **Claude Code Review** (`.github/workflows/claude-code-review.yml`)
   - Automatically runs on pull requests (opened, synchronize, ready_for_review, reopened)
   - Uses the `code-review` plugin from the claude-code-plugins marketplace
   - Requires `CLAUDE_CODE_OAUTH_TOKEN` secret to be configured

2. **Claude PR Assistant** (`.github/workflows/claude.yml`)
   - Triggers when `@claude` is mentioned in:
     - Issue comments
     - Pull request review comments
     - Pull request reviews
     - Issue titles or bodies
   - Has read access to CI results on PRs
   - Can be customized with additional prompts and allowed tools via `claude_args`

## Repository Structure

- `hello.txt` - Test file for git operations
- `.github/workflows/` - GitHub Actions automation for Claude Code
