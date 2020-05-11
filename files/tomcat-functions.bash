
configure_context_path() {
  if [ "$CONTEXT_PATH" == "ROOT" -o -z "$CONTEXT_PATH" ]; then
    CONTEXT_PATH=
  else
    log_notice "Setting context path to: $CONTEXT_PATH"
  fi

  if [ -e "${INSTALL_DIR}/conf/server.xml" ]; then
    xmlstarlet edit --pf --inplace --update '//Context/@path' -v "$CONTEXT_PATH" "${INSTALL_DIR}/conf/server.xml"
  else
    log_crit "File not found: ${INSTALL_DIR}/conf/server.xml"
  fi
}

configure_jndi_mail() {
  local server_xml_file=${1:-${INSTALL_DIR}/conf/server.xml}

  MAIL_RES_NAME=${MAIL_RES_NAME:-'mail/smtp'}

  MAIL_HOST=${MAIL_HOST:-"$(hostname)"}

  MAIL_PORT=${MAIL_PORT:-"25"}

  MAIL_DEBUG=${MAIL_DEBUG:-'false'}

  ## create the data source resource element
  xmlstarlet edit --pf --inplace \
    --subnode '//Context' -t elem -n 'MailResource' -v '' \
    --insert '//Context/MailResource' -t attr -n 'name' -v "$MAIL_RES_NAME" \
    --insert '//Context/MailResource' -t attr -n 'type' -v 'javax.mail.Session' \
    --insert '//Context/MailResource' -t attr -n 'auth' -v 'Container' \
    --insert '//Context/MailResource' -t attr -n 'mail.smtp.host' -v "$MAIL_HOST" \
    --insert '//Context/MailResource' -t attr -n 'mail.smtp.port' -v "$MAIL_PORT" \
    --insert '//Context/MailResource' -t attr -n 'mail.smtp.user' -v "$MAIL_USER" \
    --insert '//Context/MailResource' -t attr -n 'password'       -v "$MAIL_PASSWORD" \
    --insert '//Context/MailResource' -t attr -n 'mail.debug'     -v "$MAIL_DEBUG" \
    --insert '//Context/MailResource' -t attr -n 'mail.smtp.auth' -v 'true' \
    --insert '//Context/MailResource' -t attr -n 'mail.transport.protocol' -v 'smtp' \
    --rename '//Context/MailResource' -v 'Resource' \
    $server_xml_file

  log_info "JNDI mail resource created"
}

configure_proxy_connector() {
  local server_xml_file=${1:-${INSTALL_DIR}/conf/server.xml}

  local XPATH='//Server/Service'

  PROXY_PORT=${PROXY_PORT:-"80"}

  log_notice "Configuring Tomcat connector for proxy frontend: $PROXY_NAME:$PROXY_PORT"

  ## Get default connector attribute names
  ATTR_NAMES=($(xmlstarlet sel \
    --template --match "${XPATH}/Connector/@*" --value-of "name()" --output ' ' \
    $server_xml_file))

  ## Get default connector attribute values
  ATTR_VALUES=($(xmlstarlet sel \
    --template --match "${XPATH}/Connector/@*" --value-of "(.)" --output ' ' \
    $server_xml_file))

  ## Add proxy connector element
  xmlstarlet edit --pf --inplace \
    --insert ${XPATH}/Connector --type elem --name 'proxyConnector' --value '' \
    $server_xml_file

  ## Add proxy connector attributes
  for index in ${!ATTR_NAMES[*]}; do
    attr_name=${ATTR_NAMES[$index]}
    attr_value=${ATTR_VALUES[$index]}

    #echo "current attr: $attr_name = $attr_value"

    ## Increment port number of default connector
    if [ "$attr_name" == "port" ]; then
      xmlstarlet edit --pf --inplace \
        --update ${XPATH}/Connector/@port --value $(($attr_value + 1)) \
        $server_xml_file
    fi

    ## Add attribute
    xmlstarlet edit --pf --inplace \
      --insert ${XPATH}/proxyConnector --type attr --name "$attr_name" --value "$attr_value" \
      $server_xml_file
  done

  ## Add proxy settings
  xmlstarlet edit --pf --inplace \
    --insert ${XPATH}/proxyConnector -t attr -n 'proxyName' -v "$PROXY_NAME" \
    --insert ${XPATH}/proxyConnector -t attr -n 'proxyPort' -v "$PROXY_PORT" \
    $server_xml_file

  ## Rename proxy connector (after adding proxy settings)
  xmlstarlet edit --pf --inplace \
    --rename ${XPATH}/proxyConnector -v 'Connector' \
    $server_xml_file
}

configure_tomcat_connector() {
  local default_port=${1:-"8080"}
  local ssl_port=${2:-"8443"}
  local server_xml_file=${3:-${INSTALL_DIR}/conf/server.xml}

  local ssl_certificate_file=${SSL_CERTIFICATE_FILE:-"/etc/atlassian/ssl/$(hostname).crt"}
  local ssl_certificate_key_file=${SSL_CERTIFICATE_KEY_FILE:-"/etc/atlassian/ssl/$(hostname).key"}
  local ssl_certificate_chain_file=${SSL_CERTIFICATE_CHAIN_FILE:-"/etc/atlassian/ssl/ca_chain.crt"}

  local XPATH="//Server/Service/Connector"

  ## Set default transport scheme and port
  SCHEME="http"
  PORT=$default_port

  ## Configure attributes for SSL/TLS
  if [ "$SSL_ENABLED" == "true" ]; then
    SCHEME="https"
    PORT=$ssl_port
    PROXY_PORT=${PROXY_PORT:-"443"}
  fi

  log_notice "Configuring Tomcat connector with port: $PORT"

  ## Set port number of default connector
  xmlstarlet edit --pf --inplace --update ${XPATH}/@port --value $PORT "$server_xml_file"

  if [ "$SSL_ENABLED" == "true" ]; then
    log_notice "Configuring Tomcat connector with SSL support."

    /usr/local/bin/issue-pki-cert -F $(hostname) -a "localhost,$(hostname -s)"

    ## Java truststore configuration for self-signed certs
    keytool \
      -delete \
      -alias tomcat_ca \
      -keystore /usr/lib/jvm/java-8-oracle/jre/lib/security/cacerts \
      -storepass changeit || true

    keytool \
      -importcert \
      -trustcacerts \
      -noprompt \
      -file /etc/atlassian/ssl/ca.crt \
      -alias tomcat_ca \
      -keystore /usr/lib/jvm/java-8-oracle/jre/lib/security/cacerts \
      -storepass changeit

    ## Set SSL parameters for default connector
    FOUND_PROTO=$(xmlstarlet sel --template -i ${XPATH}/@protocol -o 'true' --else -o 'false' "$server_xml_file")
    log_debug "Found protocol property: $FOUND_PROTO"

    if [ "$FOUND_PROTO" == "false" ]; then
      xmlstarlet edit --pf --inplace \
        --append $XPATH -t attr -n 'protocol' -v 'org.apache.coyote.http11.Http11AprProtocol' \
        "$server_xml_file"
    else
      xmlstarlet edit --pf --inplace \
        --update "${XPATH}/@protocol" -v 'org.apache.coyote.http11.Http11AprProtocol' \
        "$server_xml_file"
    fi

    xmlstarlet edit --ps --inplace \
      --append $XPATH -t attr -n 'scheme'           -v 'https' \
      --append $XPATH -t attr -n 'secure'           -v 'true' \
      --append $XPATH -t attr -n 'SSLEnabled'       -v 'true' \
      --append $XPATH -t attr -n 'SSLProtocol'      -v 'all' \
      --append $XPATH -t attr -n 'SSLVerifyClient'  -v 'false' \
      --append $XPATH -t attr -n 'SSLCertificateFile'      -v "${ssl_certificate_file}" \
      --append $XPATH -t attr -n 'SSLCertificateKeyFile'   -v "${ssl_certificate_key_file}" \
      --append $XPATH -t attr -n 'SSLCertificateChainFile' -v "${ssl_certificate_chain_file}" \
      "$server_xml_file"
  fi
}
