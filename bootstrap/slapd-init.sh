#!/usr/bin/bash
set -eu

readonly DATA_DIR="/bootstrap/data"
readonly CONFIG_DIR="/bootstrap/config"

readonly LDAP_DOMAIN=planetexpress.com
readonly LDAP_ORGANISATION="Planet Express, Inc."
readonly LDAP_BINDDN="cn=admin,dc=planetexpress,dc=com"
readonly LDAP_SECRET=GoodNewsEveryone

readonly LDAP_SSL_KEY="/etc/ldap/ssl/ldap.key"
readonly LDAP_SSL_CERT="/etc/ldap/ssl/ldap.crt"


# Note 2023-07-25: the HDB backend has been archived in slapd >=2.5. The
# primary backend recommended by the OpenLDAP project is the MDB backend.
#
# Note 2023-08-02: the MDB backend has a longstanding bug with CNs that
# exceed 512 characters (https://bugs.openldap.org/show_bug.cgi?id=10088).
# Somehow, this prevents us from using it.
# https://github.com/ldapjs/node-ldapjs/blob/1cc6a73/test-integration/client/issues.test.js#L12-L41
# triggers the issue, but neither the CN value nor the full DN exceeds the
# imposed 512 character limit.
#
# Note 2023-08-15: https://bugs.openldap.org/show_bug.cgi?id=10088#c13 indicates
# that the bug is triggered with RDNs exceeding 256 characters because of some
# "normalizer" feature. Our solution at this time is to reduce the length of
# our offending RDN. Our original issue, https://github.com/ldapjs/node-ldapjs/issues/480
# states a problem with with RDNs exceeding 132 characters, so we will reduce
# our test to exceed that but not offend OpenLDAP.
reconfigure_slapd() {
    echo "Reconfigure slapd..."
    cat <<EOL | debconf-set-selections
slapd slapd/internal/generated_adminpw password ${LDAP_SECRET}
slapd slapd/internal/adminpw password ${LDAP_SECRET}
slapd slapd/password2 password ${LDAP_SECRET}
slapd slapd/password1 password ${LDAP_SECRET}
slapd slapd/dump_database_destdir string /var/backups/slapd-VERSION
slapd slapd/domain string ${LDAP_DOMAIN}
slapd shared/organization string ${LDAP_ORGANISATION}
slapd slapd/backend string MDB
slapd slapd/purge_database boolean true
slapd slapd/move_old_database boolean true
slapd slapd/allow_ldap_v2 boolean false
slapd slapd/no_configuration boolean false
slapd slapd/dump_database select when needed
EOL

    DEBIAN_FRONTEND=noninteractive dpkg-reconfigure slapd
}


make_snakeoil_certificate() {
    echo "Make snakeoil certificate for ${LDAP_DOMAIN}..."
    openssl req -subj "/CN=${LDAP_DOMAIN}" \
                -new \
                -newkey rsa:2048 \
                -days 365 \
                -nodes \
                -x509 \
                -keyout ${LDAP_SSL_KEY} \
                -out ${LDAP_SSL_CERT}

    chmod 600 ${LDAP_SSL_KEY}
}

configure_base() {
    echo "Configure base..."
    ldapmodify -Y EXTERNAL -H ldapi:/// -f ${CONFIG_DIR}/00_base_config.ldif -Q
}

configure_tls() {
    echo "Configure TLS..."
    ldapmodify -Y EXTERNAL -H ldapi:/// -f ${CONFIG_DIR}/tls.ldif -Q
}


configure_logging() {
    echo "Configure logging..."
    ldapmodify -Y EXTERNAL -H ldapi:/// -f ${CONFIG_DIR}/logging.ldif -Q
}

configure_msad_features(){
  echo "Configure MS-AD Extensions"
  ldapmodify -Y EXTERNAL -H ldapi:/// -f ${CONFIG_DIR}/msad.ldif -Q
}

configure_memberof_overlay(){
  echo "Configure memberOf overlay..."
  ldapmodify -Y EXTERNAL -H ldapi:/// -f ${CONFIG_DIR}/memberof.ldif -Q
}

load_initial_data() {
    echo "Load data..."
    local data=$(find ${DATA_DIR} -maxdepth 1 -name \*_\*.ldif -type f | sort)
    for ldif in ${data}; do
        echo "Processing file ${ldif}..."
        ldapadd -x -H ldapi:/// \
          -D ${LDAP_BINDDN} \
          -w ${LDAP_SECRET} \
          -f ${ldif}
    done

    local data=$(find ${DATA_DIR}/large-group -maxdepth 2 -name \*_\*.ldif -type f | sort)
    for ldif in ${data}; do
      echo "Processing file ${ldif}..."
      ldapadd -x -H ldapi:/// \
        -D ${LDAP_BINDDN} \
        -w ${LDAP_SECRET} \
        -f ${ldif}
    done
}


## Init

reconfigure_slapd
make_snakeoil_certificate
chown -R openldap:openldap /etc/ldap
slapd -h "ldapi:///" -u openldap -g openldap

configure_base
configure_msad_features
configure_tls
configure_logging
configure_memberof_overlay
load_initial_data

kill -INT `cat /run/slapd/slapd.pid`

exit 0
