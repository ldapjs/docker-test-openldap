FROM debian:12-slim
MAINTAINER Rafael Römhild <rafael@roemhild.de>

# Install slapd and requirements
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get \
        install -y --no-install-recommends \
            bash \
            slapd \
            ldap-utils \
            openssl \
            ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir /etc/ldap/ssl /bootstrap

ENV LDAP_DEBUG_LEVEL=256

# ADD run script
COPY ./run.sh /run.sh

# ADD bootstrap files
ADD ./bootstrap /bootstrap

# Initialize LDAP with data
RUN /usr/bin/bash /bootstrap/slapd-init.sh

VOLUME ["/etc/ldap/slapd.d", "/etc/ldap/ssl", "/var/lib/ldap", "/run/slapd"]

EXPOSE 389 636

CMD ["/usr/bin/bash", "/run.sh"]
ENTRYPOINT []
