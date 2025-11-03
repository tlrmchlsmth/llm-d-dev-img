FROM llm-d-dev:nightly

WORKDIR /opt/vllm-source

# Add all remotes upfront
RUN git remote add vllm https://github.com/vllm-project/vllm && \
  git remote add njhill https://github.com/njhill/vllm && \
  git remote add tms https://github.com/tlrmchlsmth/vllm && \
  git remote add nm https://github.com/neuralmagic/vllm

# Fetch all branches
ARG VLLM_CHECKOUT_COMMIT
RUN git fetch --all

# Check out a specific commit for testing
# This relies on the fact that the llm-d Dockerfile installs vLLM editably!
RUN --mount=type=cache,target=/root/.cache/uv \
  source /opt/vllm/bin/activate && \
  git checkout -q ${VLLM_CHECKOUT_COMMIT}

USER 2000

ENTRYPOINT ["python", "-m", "vllm.entrypoints.openai.api_server"]

