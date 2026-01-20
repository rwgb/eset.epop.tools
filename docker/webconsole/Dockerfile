FROM tomcat:9.0-jdk11

LABEL maintainer="ESET Protect Docker POC"
LABEL description="ESET Web Console Container"

# Environment variables
ENV CATALINA_HOME=/usr/local/tomcat
ENV ESET_WEBCONSOLE_URL=https://download.eset.com/com/eset/apps/business/era/webconsole/latest/era_x64.war

# Install required tools
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    openssl \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Remove default webapps
RUN rm -rf ${CATALINA_HOME}/webapps/*

# Create webapp directory
RUN mkdir -p ${CATALINA_HOME}/webapps/era

# Download ESET Web Console WAR
RUN wget -O /tmp/era.war "${ESET_WEBCONSOLE_URL}" && \
    unzip /tmp/era.war -d ${CATALINA_HOME}/webapps/era && \
    rm /tmp/era.war

# Generate self-signed SSL certificate
RUN mkdir -p ${CATALINA_HOME}/conf && \
    keytool -genkey -noprompt \
    -alias tomcat \
    -keyalg RSA \
    -keysize 2048 \
    -validity 365 \
    -keystore ${CATALINA_HOME}/conf/keystore.jks \
    -storepass changeit \
    -keypass changeit \
    -dname "CN=eset-webconsole, OU=IT, O=Company, L=City, ST=State, C=US"

# Copy custom server.xml with HTTPS configuration
COPY server.xml ${CATALINA_HOME}/conf/server.xml

# Set proper permissions
RUN chown -R root:root ${CATALINA_HOME}/webapps/era && \
    chmod -R 755 ${CATALINA_HOME}/webapps/era

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose ports
EXPOSE 8080 8443

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=5 \
    CMD curl -f http://localhost:8080/era/ || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["catalina.sh", "run"]
