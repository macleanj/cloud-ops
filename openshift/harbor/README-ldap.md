# https://ruzickap.github.io/k8s-harbor/part-05/#ldap-authentication
export LDAPTLS_REQCERT=never
export LDAPSEARCH_PASSWORD=

# List users which are in Active Directory (Example)
ldapsearch -LLL -s sub -H ldaps://ADDS.eulisa.local:636 -x -b DC="eulisa,DC=local" -D "CN=bind_user,OU=SERVICE_USERS,OU=IBM,DC=eulisa,DC=local" -w "${LDAPSEARCH_PASSWORD}" "(cn=jerome*)" dn name description objectclass memberOf

# List groups which are in Active Directory (Example)
ldapsearch -LLL -s sub -H ldaps://ADDS.eulisa.local:636 -x -b "DC=eulisa,DC=local" -D "CN=bind_user,OU=SERVICE_USERS,OU=IBM,DC=eulisa,DC=local" -w "${LDAPSEARCH_PASSWORD}" "(cn=user*)" dn name description objectclass member
ldapsearch -LLL -s sub -H ldaps://ADDS.eulisa.local:636 -x -b "DC=eulisa,DC=local" -D "CN=bind_user,OU=SERVICE_USERS,OU=IBM,DC=eulisa,DC=local" -w "${LDAPSEARCH_PASSWORD}" dn name description objectclass member

Mind the objectclass to be used for the search in other applicatons