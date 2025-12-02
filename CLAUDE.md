# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Docker image build repository for llm-d development environments. It creates custom vLLM development images using the llm-d project's official Dockerfile, with automated nightly builds and efficient layered caching to enable fast custom builds.

## Architecture

The build system uses a two-layer approach to minimize rebuild times:

1. **Base Layer** (large, rebuilt nightly):
   - Built from `llm-d/docker/Dockerfile.cuda` (llm-d submodule)
   - Full compilation of vLLM with all dependencies
   - vLLM installed in editable mode at `/opt/vllm-source`
   - Tagged as `llm-d-dev:nightly`
   - Updated nightly to track latest vLLM main

2. **Checkout Layer** (small, <100MB, rebuilt per session):
   - **GitHub builds** (`./Dockerfile`): Clones vLLM from GitHub and checks out `VLLM_CHECKOUT_COMMIT`
   - **Local builds** (`./Dockerfile.local`): Mounts local `.git` directory and checks out from local repo
   - Only updates source files (doesn't touch compiled `.so` files from base layer)
   - Works because base layer uses editable install - source changes are reflected immediately
   - Only works for changes that don't require recompiling vLLM binaries (e.g., Python-only changes)

### Build Arguments

**Dockerfile** (GitHub builds):
- `VLLM_CHECKOUT_COMMIT`: The specific vLLM commit to checkout from GitHub

**Dockerfile.local** (Local builds):
- `VLLM_LOCAL_GIT_DIR`: Path to local vLLM `.git` directory (default: `/home/tms/vllm/.git`)
- `VLLM_LOCAL_REF`: Git ref to checkout - branch, commit, or tag (default: `HEAD`)

### Git Remotes

The Dockerfile sets up multiple git remotes for vLLM:
- `vllm`: Official vLLM repository
- `njhill`: Nick Hill's fork
- `tms`: Taylor Smith's fork
- `nm`: Neural Magic's fork

## Common Commands

### Setting Up Nightly Builds

Enable automated nightly builds (runs at 2 AM):
```bash
./setup-cron.sh
```

This creates a cron job that:
- Fetches the latest vLLM main commit
- Updates `base_commit.txt` locally
- Builds from `llm-d/docker/Dockerfile.cuda`
- Tags locally as `llm-d-dev:nightly` and `llm-d-dev:nightly-<commit>`

### Manual Nightly Build

Manually trigger a nightly build (rebuilds the large base layer):
```bash
just nightly
```

### Building Custom Commits from GitHub

Build and push an image for a specific vLLM commit from GitHub (fast, uses cached base layer):
```bash
just build <commit-hash>
```

This:
- Uses `llm-d-dev:nightly` as the base image
- Clones vLLM and checks out `<commit-hash>` from GitHub
- Tags locally as `llm-d-dev:<commit-hash>`
- Pushes as `quay.io/tms/llm-d-dev:commit-<commit-hash>`

**Note**: This only works for commits that don't require recompiling vLLM binaries (e.g., Python-only changes).

### Building from Local vLLM Directory

Build and push an image from your local vLLM development directory (fastest, minimal layer size):
```bash
just dev                                    # Uses $HOME/vllm and HEAD
just dev /path/to/vllm                      # Custom path
just dev /path/to/vllm my-branch            # Custom branch/commit
```

This:
- Uses `llm-d-dev:nightly` as the base image
- Mounts your local `.git` directory (doesn't copy it - zero layer overhead!)
- Checks out the specified ref (branch/commit/tag) from your local repo
- Only updates tracked source files (compiled `.so` files are NOT touched)
- Tags locally as `llm-d-dev:local-<commit-hash>`
- Pushes as `quay.io/tms/llm-d-dev:local-<commit-hash>`

**Advantages**:
- Extremely fast (no network fetch)
- Works with local branches and uncommitted work
- Minimal layer size (only changed source files)
- Perfect for iterative development

**Note**: Like `just build`, this only works for Python-only changes since the base layer's compiled binaries are reused.

## Development Workflow

### Initial Setup
1. Run `./setup-cron.sh` once to enable nightly builds

### Local Development (Recommended)
1. Wait for nightly build or run `just nightly` to update base layer
2. Make changes to your local vLLM checkout (e.g., `$HOME/vllm`)
3. Run `just dev` to build and push an image with your local changes (fastest, ~1-2 minutes)

### Testing GitHub Commits
1. Wait for nightly build or run `just nightly` to update base layer
2. Run `just build <hash>` to build and push a custom commit image from GitHub

### When Base Layer Needs Updating
The base layer is automatically updated nightly. To manually update:
1. Run `just nightly` to rebuild the base layer from latest vLLM main
2. Continue with normal `just dev` or `just build <hash>` workflow

## Important Notes

- `base_commit.txt` is gitignored and managed locally by nightly builds (tracks the vLLM commit in the base layer)
- The `llm-d` submodule contains the official llm-d Dockerfile used for base layer builds
- The entrypoint runs the vLLM OpenAI API server: `python -m vllm.entrypoints.openai.api_server`
- Quick builds clone vLLM to `/home/code/vllm` and set up multiple git remotes for easy development
