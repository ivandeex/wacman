<?php
// $Id$

// Return list of users from LDAP

require '../lib/common.php';

ldap_connect_all();
echo ldap_encode_json(ldap_search_for('uni', "(objectClass=person)", array('uid', 'cn')));
?>
