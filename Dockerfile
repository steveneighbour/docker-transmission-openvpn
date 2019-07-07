FROM ubuntu:16.04

VOLUME /data
VOLUME /config

ARG DOCKERIZE_ARCH=amd64
ARG DOCKERIZE_VERSION=v0.6.1
ARG DUMBINIT_VERSION=1.2.2

# Update, upgrade and install core software
RUN apt update \
    && apt -y upgrade \
    && apt -y install software-properties-common wget git curl jq \
    && add-apt-repository ppa:transmissionbt/ppa \
    && wget -O - https://swupdate.openvpn.net/repos/repo-public.gpg | apt-key add - \
    && echo "deb http://build.openvpn.net/debian/openvpn/stable xenial main" > /etc/apt/sources.list.d/openvpn-aptrepo.list \
    && apt update \
    && apt install -y sudo transmission-cli transmission-common transmission-daemon curl rar unrar zip unzip ufw iputils-ping openvpn bc tzdata \
    python2.7 python2.7-pysqlite2 && ln -sf /usr/bin/python2.7 /usr/bin/python2 \
    && wget https://github.com/Secretmapper/combustion/archive/release.zip \
    && unzip release.zip -d /opt/transmission-ui/ \
    && rm release.zip \
    && mkdir /opt/transmission-ui/transmission-web-control \
    && curl -sL `curl -s https://api.github.com/repos/ronggang/transmission-web-control/releases/latest | jq --raw-output '.tarball_url'` | tar -C /opt/transmission-ui/transmission-web-control/ --strip-components=2 -xz \
    && ln -s /usr/share/transmission/web/style /opt/transmission-ui/transmission-web-control \
    && ln -s /usr/share/transmission/web/images /opt/transmission-ui/transmission-web-control \
    && ln -s /usr/share/transmission/web/javascript /opt/transmission-ui/transmission-web-control \
    && ln -s /usr/share/transmission/web/index.html /opt/transmission-ui/transmission-web-control/index.original.html \
    && git clone git://github.com/endor/kettu.git /opt/transmission-ui/kettu \
    && apt install -y tinyproxy telnet \
    && wget https://github.com/Yelp/dumb-init/releases/download/v${DUMBINIT_VERSION}/dumb-init_${DUMBINIT_VERSION}_amd64.deb \
    && dpkg -i dumb-init_${DUMBINIT_VERSION}_amd64.deb \
    && rm -rf dumb-init_${DUMBINIT_VERSION}_amd64.deb \
    && curl -L https://github.com/jwilder/dockerize/releases/download/${DOCKERIZE_VERSION}/dockerize-linux-${DOCKERIZE_ARCH}-${DOCKERIZE_VERSION}.tar.gz | tar -C /usr/local/bin -xzv \
    && apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && groupmod -g 1000 users \
    && useradd -u 911 -U -d /config -s /bin/false abc \
    && usermod -G users abc

ADD openvpn/ /etc/openvpn/
ADD transmission/ /etc/transmission/
ADD tinyproxy /opt/tinyproxy/
ADD scripts /etc/scripts/

ENV OPENVPN_USERNAME=**None** \
    OPENVPN_PASSWORD=**None** \
    OPENVPN_PROVIDER=**None** \
    GLOBAL_APPLY_PERMISSIONS=true \
    ENABLE_UFW=false \
    UFW_ALLOW_GW_NET=false \
    UFW_EXTRA_PORTS= \
    UFW_DISABLE_IPTABLES_REJECT=false \
    PUID= \
    PGID= \
    DROP_DEFAULT_ROUTE= \
    WEBPROXY_ENABLED=false \
    WEBPROXY_PORT=8888 \
    HEALTH_CHECK_HOST=google.com

HEALTHCHECK --interval=5m CMD /etc/scripts/healthcheck.sh

# package version
# (stable-download or testing-download)
ARG NZBGET_BRANCH="stable-download"

RUN \
 echo "**** install packages ****" && \
 apk add --no-cache \
	curl \
	p7zip \
	python2 \
	unrar \
	wget && \
 echo "**** install nzbget ****" && \
 mkdir -p \
	/app/nzbget && \
 curl -o /tmp/json -L "http://nzbget.net/info/nzbget-version-linux.json" && \
 NZBGET_VERSION=$(grep "${NZBGET_BRANCH}" /tmp/json  | cut -d '"' -f 4) && \
 curl -o /tmp/nzbget.run -L "${NZBGET_VERSION}" && \
 #curl -o /tmp/nzbget.run -L "https://github.com/nzbget/nzbget/releases/download/v21.0/nzbget-21.0-bin-linux.run" && \
 sh /tmp/nzbget.run --destdir /app/nzbget && \
 echo "**** configure nzbget ****" && \
 mkdir -p /defaults && \
 cp /app/nzbget/nzbget.conf /defaults/nzbget.conf && \
 sed -i \
	-e "s#\(MainDir=\).*#\1/downloads#g" \
	-e "s#\(ScriptDir=\).*#\1$\{MainDir\}/scripts#g" \
	-e "s#\(WebDir=\).*#\1$\{AppDir\}/webui#g" \
	-e "s#\(ConfigTemplate=\).*#\1$\{AppDir\}/webui/nzbget.conf.template#g" \
 /defaults/nzbget.conf && \
 echo "**** cleanup ****" && \
 rm -rf \
	/tmp/*

# add local files
COPY root/ /

# ports and volumes
VOLUME /config /downloads
# Expose port and run
EXPOSE 6789
CMD ["dumb-init", "/etc/openvpn/start.sh"]
