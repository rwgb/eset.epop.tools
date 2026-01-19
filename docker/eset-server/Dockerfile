FROM ubuntu:24.04

LABEL maintainer="ESET Protect Docker POC"
LABEL description="ESET Protect On-Prem Server Container"

# Prevent interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive
ENV ESET_INSTALLER_URL=https://download.eset.com/com/eset/apps/business/era/server/linux/latest/server_linux_x86_64.sh

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    unixodbc \
    unixodbc-dev \
    libmysqlclient21 \
    mysql-client \
    ca-certificates \
    supervisor \
    net-tools \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p /var/opt/eset/RemoteAdministrator \
    /var/log/eset/RemoteAdministrator \
    /etc/opt/eset/RemoteAdministrator/Server/Cert \
    /opt/eset/installers

# Install MySQL ODBC Connector
ARG ODBC_VERSION=8.0.40
RUN cd /tmp && \
    wget https://dev.mysql.com/get/Downloads/Connector-ODBC/8.0/mysql-connector-odbc-${ODBC_VERSION}-linux-glibc2.28-x86-64bit.tar.gz && \
    tar -xzf mysql-connector-odbc-${ODBC_VERSION}-linux-glibc2.28-x86-64bit.tar.gz && \
    cd mysql-connector-odbc-${ODBC_VERSION}-linux-glibc2.28-x86-64bit && \
    cp lib/libmyodbc8* /usr/local/lib/ && \
    cp bin/myodbc-installer /usr/local/bin/ && \
    chmod 755 /usr/local/lib/libmyodbc8* && \
    chmod 755 /usr/local/bin/myodbc-installer && \
    echo "/usr/local/lib" > /etc/ld.so.conf.d/mysql-odbc.conf && \
    ldconfig && \
    myodbc-installer -a -d -n "MySQL ODBC 8.0 Driver" -t "Driver=/usr/local/lib/libmyodbc8w.so" && \
    myodbc-installer -a -d -n "MySQL ODBC 8.0" -t "Driver=/usr/local/lib/libmyodbc8a.so" && \
    cd / && rm -rf /tmp/mysql-connector-odbc-*

# Download ESET installer
RUN wget -O /opt/eset/installers/server_linux_x86_64.sh "${ESET_INSTALLER_URL}" && \
    chmod +x /opt/eset/installers/server_linux_x86_64.sh

# Copy entrypoint and supervisor configuration
COPY entrypoint.sh /opt/eset/entrypoint.sh
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

RUN chmod +x /opt/eset/entrypoint.sh

# Expose ESET ports
EXPOSE 2222 2223

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=5 \
    CMD curl -k -f https://localhost:2223 || exit 1

ENTRYPOINT ["/opt/eset/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
