ARG STACK_VERSION
FROM --platform=linux/amd64 heroku/heroku:${STACK_VERSION}-build AS build

# This ARG duplication is required since the lines before and after the 'FROM' are in different scopes.
ARG STACK_VERSION
ENV STACK="heroku-${STACK_VERSION}"

# On Heroku-24 and later the default user is not root.
# Once support for Heroku-22 and older is removed, the `useradd` steps below can be removed.
USER root

# Emulate the platform where root access is not available
RUN useradd -m non-root-user && mkdir -p /layers && chown non-root-user /layers
USER non-root-user
COPY --chown=non-root-user . /buildpack

# Sanitize the environment seen by the buildpack, to prevent reliance on
# environment variables that won't be present when it's run by Heroku CI.
# The layers directory must be at the same path in both stages, since the layer
# env vars written during build contain absolute paths.
RUN env -i PATH=$PATH HOME=$HOME CNB_STACK_ID=$STACK CNB_LAYERS_DIR=/layers /buildpack/bin/detect
RUN env -i PATH=$PATH HOME=$HOME CNB_STACK_ID=$STACK CNB_LAYERS_DIR=/layers /buildpack/bin/build

# We must then test against the run image since that has fewer system libraries installed.
FROM --platform=linux/amd64 heroku/heroku:${STACK_VERSION}
USER root
# Emulate the platform where root access is not available
RUN useradd -m non-root-user && mkdir -p /app && chown non-root-user /app
USER non-root-user
COPY --from=build --chown=non-root-user /layers /layers
# Emulate the CNB lifecycle, which applies each layer's env/ directory at launch.
COPY --chown=non-root-user support/apply-layer-env.sh /apply-layer-env.sh
RUN echo 'source /apply-layer-env.sh /layers/chrome-with-chromedriver/env' > /app/.profile
ENV HOME=/app
WORKDIR /app
# We have to use a login bash shell otherwise the .profile script won't be run.
CMD ["bash", "-l"]
