#!/usr/bin/env bash

project_root=$(dirname "$0")/..

# ---------------------------
# Tomcat setup
# ---------------------------

if hash catalina 2>/dev/null; then
  CATALINA_HOME=$(catalina  | grep CATALINA_HOME | awk '{ print $NF }')
  if [ ! -d "$CATALINA_HOME" ]; then
    >&2 echo "Error: Value for CATALINA_HOME ('$CATALINA_HOME') does not point to a directory."
    >&2 echo "Is your tomcat installation setup correctly?"
    exit 1
  fi
else
  >&2 echo "Error: Could not find a 'catalina' executable on the PATH. Do you have tomcat installed?"
  exit 1
fi

# ---------------------------
# Build
# ---------------------------

mvn --file "$project_root"/EIDAS-Parent package -P embedded -P coreDependencies -Dmaven.test.skip=true

# ---------------------------
# Deploy
# ---------------------------

# Deploy the SP
cp "$project_root"/EIDAS-SP/target/SP.war "$CATALINA_HOME/webapps"

# Deploy the Connector Node
cp "$project_root"/EIDAS-Node/target/EidasNode.war "$CATALINA_HOME/webapps/ConnectorNode.war"

# Deploy the IdP
cp "$project_root"/EIDAS-IdP-1.0/target/IdP.war "$CATALINA_HOME/webapps"

# Hack - reconfigure the Node to be a proxy node instead of a connector node
FILES_TO_REPLACE=$(git grep '${NODE_' | cut -d: -f1 | grep .xml | sort -u)
for file in $FILES_TO_REPLACE; do
  sed -i '.original' 's/${NODE_/${PROXY_NODE_/g' $file
done

FILES_TO_REPLACE=$(git grep 'EIDAS_CONFIG_REPOSITORY' | cut -d: -f1 | grep .xml | sort -u)
for file in $FILES_TO_REPLACE; do
  sed -i '.configoriginal' 's/EIDAS_CONFIG_REPOSITORY/PROXY_EIDAS_CONFIG_REPOSITORY/g' $file
done

mvn --file EIDAS-Parent package -P embedded -P coreDependencies -Dmaven.test.skip=true

# Deploy the Proxy Node
cp "$project_root"/EIDAS-Node/target/EidasNode.war "$CATALINA_HOME/webapps/ProxyNode.war"

# Restore the modified files from their backups
find . -name "*.configoriginal" -exec sh -c 'mv -f $0 ${0%.configoriginal}' {} \;
find . -name "*.original" -exec sh -c 'mv -f $0 ${0%.original}' {} \;

# ---------------------------
# Environment Variables
# ---------------------------

export EIDAS_CONFIG_REPOSITORY="$project_root"/EIDAS-Config/
export PROXY_EIDAS_CONFIG_REPOSITORY="$project_root"/EIDAS-Config-Proxy-Node/

# Stub SP
export STUB_SP_KEYSTORE="$project_root/EIDAS-Node/target/EidasNode/WEB-INF/stubSpKeystore.jks"
export STUB_SP_KEYSTORE_PASSWORD="Password"
export STUB_SP_ENCRYPTION_CERTIFICATE_DISTINGUISHED_NAME="CN=Test Stub SP Encryption 20161026, OU=Government Digital Service, O=Cabinet Office, L=London, ST=Greater London, C=UK"
export STUB_SP_ENCRYPTION_CERTIFICATE_SERIAL_NUMBER="41573ab34ef7100cb77e4c5aca551826cf86a1e9"
export STUB_SP_SIGNING_CERTIFICATE_DISTINGUSHED_NAME="CN=Test Stub SP Metadata Signing 20161026, OU=Government Digital Service, O=Cabinet Office, L=London, ST=Greater London, C=UK"
export STUB_SP_SIGNING_CERTIFICATE_SERIAL_NUMBER="123f7141d99aa3b6ad31211dabb9ca7abdc08b5d"

# Connector Node
export NODE_KEYSTORE="$project_root/EIDAS-Node/target/EidasNode/WEB-INF/connectorNodeKeystore.jks"
export NODE_KEYSTORE_PASSWORD="Password"

export NODE_ENCRYPTION_CERTIFICATE_DISTINGUISHED_NAME="CN=Test Connector Encryption 20161026, OU=Government Digital Service, O=Cabinet Office, L=London, ST=Greater London, C=UK"
export NODE_SIGNING_CERTIFICATE_DISTINGUISHED_NAME="CN=Test Connector Metadata Signing 20161026, OU=Government Digital Service, O=Cabinet Office, L=London, ST=Greater London, C=UK"

export NODE_ENCRYPTION_CERTIFICATE_SERIAL_NUMBER="1dcfdeedc8983a5f13f2338e0814b6e47090b3d7"
export NODE_SIGNING_CERTIFICATE_SERIAL_NUMBER="56520de46a76cb6ad7b9c238dd253d88904da9d8"

# Proxy Node
# Hack: PROXY_* variables are only needed for running locally due to instances running in
# the same application and therefore getting the same environment variables:
export PROXY_NODE_KEYSTORE="$project_root/EIDAS-Node/target/EidasNode/WEB-INF/proxyNodeKeystore.jks"
export PROXY_NODE_KEYSTORE_PASSWORD="Password"

export PROXY_NODE_ENCRYPTION_CERTIFICATE_DISTINGUISHED_NAME="CN=Test Proxy Encryption 20161026, OU=Government Digital Service, O=Cabinet Office, L=London, ST=Greater London, C=UK"
export PROXY_NODE_SIGNING_CERTIFICATE_DISTINGUISHED_NAME="CN=Test Proxy Metadata Signing 20161026, OU=Government Digital Service, O=Cabinet Office, L=London, ST=Greater London, C=UK"

export PROXY_NODE_ENCRYPTION_CERTIFICATE_SERIAL_NUMBER="6641716bee633fb618dbd85b7d41e63b62046c2d"
export PROXY_NODE_SIGNING_CERTIFICATE_SERIAL_NUMBER="203b6cb0714922c675e08606187e75c4c4457a1c"

# Stub IdP
export STUB_IDP_KEYSTORE="$project_root/EIDAS-Node/target/EidasNode/WEB-INF/stubIdpKeystore.jks"
export STUB_IDP_KEYSTORE_PASSWORD="Password"
export STUB_IDP_ENCRYPTION_CERTIFICATE_DISTINGUISHED_NAME="CN=Test Stub IdP Encryption 20161031, OU=Government Digital Service, O=Cabinet Office, L=London, ST=Greater London, C=UK"
export STUB_IDP_ENCRYPTION_CERTIFICATE_SERIAL_NUMBER="723c0f7f4b45dea5296e53f565535174d0df5218"
export STUB_IDP_SIGNING_CERTIFICATE_DISTINGUISHED_NAME="CN=Test Stub IdP Metadata Signing 20161026, OU=Government Digital Service, O=Cabinet Office, L=London, ST=Greater London, C=UK"
export STUB_IDP_SIGNING_CERTIFICATE_SERIAL_NUMBER="5ae2153c3f9a99824df394abd65f9e1e8ca53365"

# URLs
export SP_URL='http://localhost:8080/SP'
export CONNECTOR_URL='http://localhost:8080/ConnectorNode'
export PROXY_URL='http://localhost:8080/ProxyNode'
export NODE_METADATA_SSO_LOCATION='http://localhost:8080/ConnectorNode/ColleagueRequest'
export PROXY_NODE_METADATA_SSO_LOCATION='http://localhost:8080/ProxyNode/ColleagueRequest'
export IDP_URL='http://localhost:8080/IdP'
export IDP_SSO_URL='https://localhost:8080/IdP'

# ---------------------------
# Start Tomcat
# ---------------------------

catalina jpda run
