# Fetch the latest vLLM commit from main branch
@get-latest-commit:
  git ls-remote https://github.com/vllm-project/vllm.git refs/heads/main | cut -f1

# Build and push nightly image with latest vLLM commit
nightly:
  #!/usr/bin/env bash
  set -e
  echo "Fetching latest vLLM commit..."
  LATEST_COMMIT=$(just get-latest-commit)
  echo "Latest vLLM commit: $LATEST_COMMIT"
  echo "$LATEST_COMMIT" > base_commit.txt
  echo "Building nightly base image from llm-d Dockerfile.cuda..."
  docker build -f llm-d/docker/Dockerfile.cuda \
    --build-arg USE_SCCACHE=false \
    --build-arg VLLM_COMMIT_SHA="$LATEST_COMMIT" \
    --build-arg VLLM_USE_PRECOMPILED=1 \
    --label quay.expires-after=14d \
    -t llm-d-dev:nightly \
    -t "llm-d-dev:nightly-$LATEST_COMMIT" \
    -t quay.io/tms/llm-d-dev:nightly \
    -t "quay.io/tms/llm-d-dev:nightly-$LATEST_COMMIT" \
    ./llm-d
  echo "Pushing nightly images to registry..."
  docker push quay.io/tms/llm-d-dev:nightly
  docker push "quay.io/tms/llm-d-dev:nightly-$LATEST_COMMIT"
  echo "Nightly base image build complete!"
  echo "Local tags: llm-d-dev:nightly and llm-d-dev:nightly-$LATEST_COMMIT"
  echo "Pushed to: quay.io/tms/llm-d-dev:nightly and quay.io/tms/llm-d-dev:nightly-$LATEST_COMMIT"
  echo "vLLM base commit updated in base_commit.txt: $LATEST_COMMIT"

set shell := ["bash", "-cu"]

# Build and push image with custom checkout commit (uses cached base nightly image)
build HASH='':
  #!/usr/bin/env bash
  set -euo pipefail
  # Determine the hash (default to vLLM HEAD if none passed)
  if [ -z "{{HASH}}" ]; then
    HASH="$(git -C /home/tms/vllm rev-parse HEAD)"
    if [ -z "$HASH" ]; then
      echo "Error: vLLM hash could not be determined."
      exit 1
    fi
  else
    HASH="{{HASH}}"
  fi

  if [ ! -f base_commit.txt ]; then
    echo "Error: base_commit.txt not found. Run 'just nightly' first to create the base layer."
    exit 1
  fi

  BASE_COMMIT=$(cat base_commit.txt)
  echo "Building with base from nightly (base commit: $BASE_COMMIT)"
  echo "Checking out commit: $HASH"
  docker build -f Dockerfile \
    --build-arg VLLM_CHECKOUT_COMMIT=$HASH \
    --label quay.expires-after=3d \
    -t llm-d-dev:${HASH} \
    -t quay.io/tms/llm-d-dev:commit-${HASH} \
    .
  echo "Pushing to registry..."
  docker push quay.io/tms/llm-d-dev:commit-${HASH}
  echo "Build complete!"
  echo "Local tag: llm-d-dev:${HASH}"
  echo "Pushed to: quay.io/tms/llm-d-dev:commit-${HASH}"

# Build and push image from local vLLM directory (uses bind mount, keeps layers light)
dev VLLM_DIR='$HOME/vllm' REF='HEAD':
  #!/usr/bin/env bash
  set -euo pipefail

  # Expand the path
  VLLM_PATH="{{VLLM_DIR}}"
  VLLM_PATH="${VLLM_PATH/#\~/$HOME}"
  VLLM_PATH="${VLLM_PATH/#\$HOME/$HOME}"

  if [ ! -d "$VLLM_PATH/.git" ]; then
    echo "Error: $VLLM_PATH/.git not found. Please provide a valid vLLM git repository."
    exit 1
  fi

  # Get the commit hash for tagging
  HASH="$(git -C "$VLLM_PATH" rev-parse {{REF}})"
  if [ -z "$HASH" ]; then
    echo "Error: Could not resolve ref '{{REF}}' in $VLLM_PATH"
    exit 1
  fi

  if [ ! -f base_commit.txt ]; then
    echo "Error: base_commit.txt not found. Run 'just nightly' first to create the base layer."
    exit 1
  fi

  BASE_COMMIT=$(cat base_commit.txt)
  echo "Building with base from nightly (base commit: $BASE_COMMIT)"
  echo "Using local vLLM from: $VLLM_PATH"
  echo "Checking out ref: {{REF}} (commit: $HASH)"

  docker build -f Dockerfile.local \
    --build-arg VLLM_LOCAL_GIT_DIR="$VLLM_PATH/.git" \
    --build-arg VLLM_LOCAL_REF={{REF}} \
    --label quay.expires-after=3d \
    -t llm-d-dev:local-${HASH} \
    -t quay.io/tms/llm-d-dev:local-${HASH} \
    .

  echo "Pushing to registry..."
  docker push quay.io/tms/llm-d-dev:local-${HASH}
  echo "Build complete!"
  echo "Local tag: llm-d-dev:local-${HASH}"
  echo "Pushed to: quay.io/tms/llm-d-dev:local-${HASH}"
