# ============================================================================
# Stage 1: Build pjproject (required for chan_pjsip and WebRTC support)
# ============================================================================
FROM debian:bullseye-slim AS pjproject-builder

ARG PJSIP_VERSION=2.12

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    wget \
    tar \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src

RUN wget https://github.com/pjsip/pjproject/archive/refs/tags/${PJSIP_VERSION}.tar.gz -O pjproject.tar.gz && \
    tar -xzf pjproject.tar.gz && \
    cd pjproject-${PJSIP_VERSION} && \
    ./configure CFLAGS="-fPIC -DNDEBUG -DPJ_HAS_IPV6=1" \
        --prefix=/usr \
        --libdir=/usr/lib \
        --enable-shared \
        --disable-sound \
        --disable-resample \
        --disable-video \
        --disable-opencore-amr && \
    make -j$(nproc) && \
    make install && \
    ldconfig

# ============================================================================
# Stage 2: Build Asterisk with TLS, WebRTC, and ODBC support
# ============================================================================
FROM debian:bullseye-slim

ARG ASTERISK_VERSION=20

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    tar \
    ca-certificates \
    curl \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src

RUN wget "http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-${ASTERISK_VERSION}-current.tar.gz" -O asterisk.tar.gz || \
    wget "http://downloads.asterisk.org/pub/telephony/asterisk/old-releases/asterisk-${ASTERISK_VERSION}.tar.gz" -O asterisk.tar.gz && \
    tar -zxvf asterisk.tar.gz && rm asterisk.tar.gz && \
    mv asterisk-* asterisk-source

WORKDIR /usr/src/asterisk-source

# Install Asterisk build prerequisites
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive contrib/scripts/install_prereq install -y

# === ADDED: Clean up after install_prereq before installing explicit deps ===
RUN apt-get clean && apt-get autoremove -y

# === VERIFIED: Consolidated and explicit dependencies for build and runtime ===
RUN apt-get update && apt-get install -y --no-install-recommends \
    # --- For ODBC support ---
    libmariadb-dev \
    unixodbc-dev \
    mariadb-client \
    odbc-mariadb \
    unixodbc \
    libmariadb3 \
    # --- Other Asterisk module dependencies ---
    uuid-dev \
    libjansson-dev \
    libjansson4 \
    # Other common build tools that might be needed
    libssl-dev \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src

COPY --from=pjproject-builder /usr/lib/libpj*.so* /usr/lib/
COPY --from=pjproject-builder /usr/include/pj /usr/include/pj
COPY --from=pjproject-builder /usr/lib/pkgconfig/ /usr/lib/pkgconfig/
COPY --from=pjproject-builder /usr/bin/pjsua* /usr/bin/
RUN ldconfig

WORKDIR /usr/src/asterisk-source

RUN ./configure && \
    make menuselect.makeopts && \
    menuselect/menuselect \
        --enable res_http_websocket \
        --enable res_srtp \
        --enable res_pjsip_transport_websocket \
        --enable codec_opus \
        --enable chan_pjsip \
        --enable res_odbc \
        --enable cdr_adaptive_odbc \
        --enable func_odbc \
        --enable app_mixmonitor \
        --enable func_periodic_hook \
        menuselect.makeopts && \
    make -j$(nproc) && \
    make install && \
    make samples && \
    make config


# === NEW: Explicitly create asterisk user and group ===
# Asterisk's make install might not always create the user/group on minimal systems,
# so we ensure they exist before trying to chown directories.
RUN addgroup --system asterisk && \
    adduser --system --ingroup asterisk --no-create-home --shell /bin/false asterisk

# ============================================================================
# Final Image Configuration
# ============================================================================

# === ADDED: Create recording directory and set permissions ===
RUN mkdir -p /var/spool/asterisk/monitor && \
    chown -R asterisk:asterisk /var/spool/asterisk/monitor && \
    chmod -R 775 /var/spool/asterisk/monitor
# ============================================================

RUN mkdir -p /etc/asterisk/keys && \
cat > /etc/asterisk/keys/localhost.cnf <<EOF
[req]
default_bits       = 2048
prompt             = no
default_md         = sha256
distinguished_name = dn
x509_extensions    = v3_req
[dn]
C=IN
ST=TN
L=Chennai
O=Asterisk Docker
OU=IT
CN=localhost
[v3_req]
subjectAltName = @alt_names
[alt_names]
DNS.1 = localhost
EOF
RUN openssl req -x509 -nodes -days 3650 \
    -newkey rsa:2048 \
    -keyout /etc/asterisk/keys/asterisk.key \
    -out /etc/asterisk/keys/asterisk.pem \
    -config /etc/asterisk/keys/localhost.cnf \
    -extensions v3_req && \
    chmod 600 /etc/asterisk/keys/* && \
    chown root:root /etc/asterisk/keys/*

COPY src/http.conf       /etc/asterisk/http.conf
COPY src/rtp.conf        /etc/asterisk/rtp.conf
COPY src/pjsip.conf      /etc/asterisk/pjsip.conf
COPY src/modules.conf    /etc/asterisk/modules.conf
COPY src/extensions.conf /etc/asterisk/extensions.conf
COPY src/manager.conf    /etc/asterisk/manager.conf
COPY src/voicemail.conf  /etc/asterisk/voicemail.conf
COPY src/confbridge.conf /etc/asterisk/confbridge.conf
COPY src/res_odbc.conf          /etc/asterisk/res_odbc.conf
COPY src/cdr_adaptive_odbc.conf /etc/asterisk/cdr_adaptive_odbc.conf
COPY src/odbc.ini               /etc/asterisk/odbc.ini
COPY src/odbc.ini               /etc/odbc.ini
COPY src/func_odbc.conf         /etc/asterisk/func_odbc.conf
COPY src/odbcinst.ini          /etc/odbcinst.ini
COPY src/cdr.conf /etc/asterisk/cdr.conf

# Purge build-time dependencies while preserving runtime libraries.
# We explicitly installed runtime libs earlier (libmariadb3, unixodbc, libjansson4, etc.)
# so purging the -dev packages won't remove them.
# However, we need to be careful not to auto-remove dependencies that pjproject needs.
RUN apt-get purge -y \
    build-essential \
    autoconf \
    automake \
    libtool \
    pkg-config \
    git \
    wget \
    curl \
    libmariadb-dev \
    unixodbc-dev \
    uuid-dev \
    libjansson-dev \
    libssl-dev \
  && apt-get autoremove -y --purge \
  && apt-get clean \
  && rm -rf /usr/src/* /var/cache/apt/* /var/lib/apt/lists/*

EXPOSE 5038/tcp 
EXPOSE 5060/udp
EXPOSE 5061/tcp
EXPOSE 8088/tcp
EXPOSE 8089/tcp
EXPOSE 10000-10100/udp 

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["asterisk", "-f", "-cvvvvv"]