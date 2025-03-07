#!/bin/bash

# shellcheck disable=SC1090,SC1091

set -o errexit
set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purposes

# Load SonarQube environment
. /opt/bitnami/scripts/sonarqube-env.sh

# Load libraries
. /opt/bitnami/scripts/libsonarqube.sh
. /opt/bitnami/scripts/libfile.sh
. /opt/bitnami/scripts/libfs.sh
. /opt/bitnami/scripts/liblog.sh

info "Updating PID files location"
# PIDDIR appears in branch 8 
replace_in_file "${SONARQUBE_BIN_DIR}/sonar.sh" "PIDDIR=\"\.\"" "PIDDIR=\"../../pids\""
# PIDFile appears in branch 9
replace_in_file "${SONARQUBE_BIN_DIR}/sonar.sh" "PIDFILE=\".*" "PIDFILE=\"/opt/bitnami/sonarqube/pids/\$APP_NAME.pid\""

# The file wrapper.conf only exist in branch 8.
if [[ -f "${SONARQUBE_CONF_DIR}/wrapper.conf" ]]; then
    info "Updating log file location"
    replace_in_file "${SONARQUBE_CONF_DIR}/wrapper.conf" "\.\./\.\./sonar\.YYYYMMDD\.log" "../../sonar.log"

    # Log rotation will be handled externally
    # Refer to "Log Rotation" section in https://docs.sonarqube.org/latest/instance-administration/system-info/
    info "Disabling log rolling"
    replace_in_file "${SONARQUBE_CONF_DIR}/wrapper.conf" "^[#\s]*wrapper.logfile.rollmode\s*=.*" "wrapper.logfile.rollmode=NONE"
fi

# Ensure the SonarQube base directory exists and has proper permissions
# Based on https://github.com/SonarSource/docker-sonarqube/blob/master/9/community/Dockerfile#L129
info "Configuring file permissions for SonarQube"


ensure_group_exists "$SONARQUBE_DAEMON_GROUP" --gid "$SONARQUBE_DAEMON_GROUP_ID"
ensure_user_exists "$SONARQUBE_DAEMON_USER" --system --uid "$SONARQUBE_DAEMON_USER_ID" --group "$SONARQUBE_DAEMON_GROUP" --append-groups "root"
for dir in "$SONARQUBE_DATA_DIR" "$SONARQUBE_EXTENSIONS_DIR" "$SONARQUBE_LOGS_DIR" "$SONARQUBE_TMP_DIR" "$SONARQUBE_MOUNTED_PROVISIONING_DIR" "${SONARQUBE_BASE_DIR}/pids" "$SONARQUBE_VOLUME_DIR"; do
    ensure_dir_exists "$dir"
    # Use daemon:root ownership for compatibility when running as a non-root user
    configure_permissions_ownership "$dir" -d "775" -f "664" -u "$SONARQUBE_DAEMON_USER" -g "root"
done
# The installation directory needs to be writable in order for persistence logic to work (i.e. deleting folders inside it)
# The 'sonar.sh' file needs to be writable when running as a non-root user since it si going to be modified during initialization
chmod g+w "$SONARQUBE_CONF_FILE" "$SONARQUBE_BASE_DIR"
