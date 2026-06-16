# The hapiproject/hapi image is JRE-only (no shell, no curl/wget), so a Docker
# CMD/CMD-SHELL healthcheck has nothing to run. Copy a statically-linked busybox
# (musl, fully self-contained — works regardless of the base image's libc) so the
# container can health-check /fhir/metadata with `busybox wget`.
FROM busybox:musl AS busybox

FROM hapiproject/hapi:latest
COPY --from=busybox /bin/busybox /busybox/busybox
