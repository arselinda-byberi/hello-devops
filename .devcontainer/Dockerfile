FROM mcr.microsoft.com/devcontainers/python:1-3.12-bookworm
# The base image ships a Yarn apt repository whose signing key has expired,
# which makes every "apt-get update" (and so the Docker feature) fail.
# We don't use Yarn, so remove that repository.
RUN grep -rl yarnpkg /etc/apt/sources.list.d/ | xargs -r rm -f
