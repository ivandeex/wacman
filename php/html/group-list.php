<?php
// $Id$

// Return list of users from LDAP

require '../lib/common.php';

send_json_headers();
echo uldap_json_encode(uldap_search('uni', "(objectClass=posixGroup)", array('cn')));
srv_disconnect_all();
?>
