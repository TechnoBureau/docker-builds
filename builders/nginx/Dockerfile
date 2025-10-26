ARG basebuilder=registry.access.redhat.com/ubi9/ubi
ARG baseruntime=scratch
ARG VERSION=9.x.x

FROM ${basebuilder} AS builder

COPY prebuildfs /

RUN curl -L https://download.opensuse.org/repositories/home:/ganapathi/UBI9/home:ganapathi.repo -o /etc/yum.repos.d/technobureau.repo

ENV DISALLOW_PACKAGES="coreutils,grep,sed,gawk,findutils,diffutils,util-linux-core"

RUN install_packages_chroot nginx-all-modules nginx geolite2-country openssl-fips-provider

RUN echo "nonroot:x:65532:65532:NonRoot User:/home/nonroot:/bin/sh" >> /tmp/null/rootfs/etc/passwd && \
    echo "nonroot:x:65532:" >> /tmp/null/rootfs/etc/group

ENV chroot="/tmp/null/rootfs"

COPY prebuildfs ${chroot}/
RUN mkdir -p ${chroot}/home/nonroot/
COPY rootfs/docker-entrypoint-initdb.d/ ${chroot}/home/nonroot/docker-entrypoint-initdb.d/
COPY rootfs/scripts/ ${chroot}/home/nonroot/scripts/
COPY rootfs/nginx/ ${chroot}/etc/nginx/
RUN [ -d "${chroot}/home/nonroot" ] && chown -R 65532:0 ${chroot}/home/nonroot || true
RUN [ -d "${chroot}/var/log/nginx" ] && chown -R 65532:65532 ${chroot}/var/log/nginx || true
RUN [ -d "${chroot}/etc/nginx" ] && chown -R 65532:65532 ${chroot}/etc/nginx || true

RUN ln -sf /dev/stdout "${chroot}/var/log/nginx/access.log"
RUN ln -sf /dev/stderr "${chroot}/var/log/nginx/error.log"

FROM ${baseruntime} AS runtime

ENV HOME=/home/nonroot

COPY --from=builder /tmp/null/rootfs/ /

USER nonroot

WORKDIR ${HOME}

#RUN /home/nonroot/scripts/nginx/postunpack.sh

ENV APP_VERSION="1.28.0" \
    APP_NAME="nginx" \
    NGINX_HTTPS_PORT_NUMBER="" \
    NGINX_HTTP_PORT_NUMBER="8080" \
    PATH="/home/nonroot/common/bin:/home/nonroot/nginx/sbin:/home/nonroot/scripts/nginx/:$PATH"

STOPSIGNAL SIGQUIT

ENTRYPOINT [ "entrypoint.sh" ]
CMD [ "run.sh" ]
