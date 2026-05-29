FROM swiftlang/swift:nightly-main

# Install Claude Code dependencies
RUN \
  DEBIAN_FRONTEND=noninteractive \
  apt-get update && \
    apt-get install -y \
      python3 \
      curl
RUN curl -fsSL https://claude.ai/install.sh | bash
ENV PATH="/root/.local/bin:$PATH"
