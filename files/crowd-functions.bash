## Crowd configuration settings for SSO:
##
##    Set your SSO domain
##    Optional: Configure Trusted Proxy Servers
##    Optional: Enforce a secure connection, such as SSL, for all SSO requests

## Configure JIRA to use Crowd's SSO:
##
##    If JIRA is running, shut it down first
##    Edit $INSTALL_DIR/atlassian-jira/WEB-INF/classes/seraph-config.xml file:
##        <!--<authenticator class="com.atlassian.jira.security.login.JiraSeraphAuthenticator"/>-->
##        <authenticator class="com.atlassian.jira.security.login.SSOSeraphAuthenticator"/>
##    Copy the crowd.properties file from $INSTALL_DIR/client/conf/ to $INSTALL_DIR/atlassian-jira/WEB-INF/classes.
##    Edit $INSTALL_DIR/atlassian-jira/WEB-INF/classes/crowd.properties.
##    Restart JIRA

## Configure Confluence to use Crowd's SSO:
##
##    If Confluence is running, shut it down first
##    Edit $INSTALL_DIR/confluence/WEB-INF/classes/seraph-config.xml file:
##        <!-- <authenticator class="com.atlassian.confluence.user.ConfluenceAuthenticator"/> -->
##        <authenticator class="com.atlassian.confluence.user.ConfluenceCrowdSSOAuthenticator"/>
##    Copy the crowd.properties file from $INSTALL_DIR/client/conf/ to $INSTALL_DIR/confluence/WEB-INF/classes.
##    Edit $INSTALL_DIR/confluence/WEB-INF/classes/crowd.properties.
##    Restart Confluence

set_crowd_sso_properties() {
  local sso_doamin=${1:-".$(hostname --domain)"}
  local trusted_proxies=${2:-"$PROXY_NAME"}
  local enforce_secure=${3:-"false"}

}

create_crowd_properties_file() {
  local application_name="$1"
  local application_password="$2"
  local crowd_base_url=${3:-"http://crowd:8095/crowd"}
  local session_validation_interval="${4:-"2"}"

  if [ -z "$5" ];then
    log_err "No crowd.properties file specified"
    return 0
  else
    local crowd_file="$5"
    log_info "Setting properties in ${5}"
  fi

  cat <<-EOF > "$crowd_file"
    application.name                        ${application_name}
    application.password                    ${application_password}
    application.login.url                   ${crowd_base_url}/console/

    crowd.server.url                        ${crowd_base_url}/services/
    crowd.base.url                          ${crowd_base_url}/

    session.isauthenticated                 session.isauthenticated
    session.tokenkey                        session.tokenkey
    session.validationinterval              ${session_validation_interval}
    session.lastvalidation                  session.lastvalidation
  EOF
}

set_authenticator() {
  local authenticator_class_name="$1"
  local target_path="${2:-"${INSTALL_DIR}/*/WEB-INF/classes/seraph-config.xml"}"

  xmlstarlet edit --pf --inplace \
    --update "//security-config/authenticator/@class" --value "$authenticator_class_name" \
    $target_path
}
