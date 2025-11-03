FROM llm-d-dev:nightly

USER root

RUN mkdir -p /home/code && \
    git clone https://github.com/vllm-project/vllm.git /home/code/vllm

WORKDIR /home/code/vllm

# Add all remotes upfront
ARG VLLM_CHECKOUT_COMMIT
RUN git remote add vllm https://github.com/vllm-project/vllm && \
  git remote add njhill https://github.com/njhill/vllm && \
  git remote add tms https://github.com/tlrmchlsmth/vllm && \
  git remote add nm https://github.com/neuralmagic/vllm

# Fetch all branches
RUN git fetch --all

# Checkout specific commit for testing (small layer, changes frequently)
# Uses VLLM_USE_PRECOMPILED=1 to reuse binaries from base image
RUN --mount=type=cache,target=/root/.cache/uv \
  source /opt/vllm/bin/activate && \
  git checkout -q ${VLLM_CHECKOUT_COMMIT}

USER 2000

ENTRYPOINT ["python", "-m", "vllm.entrypoints.openai.api_server"]

