<?php
// $Id$

// Return list of users from LDAP

require '../lib/common.php';

ldap_connect_all();
send_json_headers();
echo ldap_encode_json(ldap_search_for('uni', "(objectClass=posixGroup)", array('cn')));
ldap_disconnect_all();
?>
