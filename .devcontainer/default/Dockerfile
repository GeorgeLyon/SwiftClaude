FROM swift:latest

# Install Claude Code dependencies
RUN \
  DEBIAN_FRONTEND=noninteractive \
  apt-get update && \
    apt-get install -y \
      ripgrep \
      nodejs \
      npm
