ARG basebuilder=registry.access.redhat.com/ubi9/ubi
ARG baseruntime=scratch
ARG VERSION=9.x.x

FROM ${basebuilder} AS builder

COPY prebuildfs /

RUN install_packages_chroot redhat-release

RUN echo "nonroot:x:65532:65532:NonRoot User:/home/nonroot:/bin/sh" >> /tmp/null/rootfs/etc/passwd && \
    echo "nonroot:x:65532:" >> /tmp/null/rootfs/etc/group

FROM ${baseruntime} AS runtime

ENV HOME /home/nonroot

COPY --from=builder /tmp/null/rootfs/ /

USER nonroot

WORKDIR ${HOME}

ENV APP_NAME="ubi" \
    APP_VERSION="9.6"

CMD /bin/sh