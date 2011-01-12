<?php
// $Id$

// Return list of users from LDAP

require '../lib/common.php';

function sort_users ($a, $b) {
    return strcmp($a['uid'], $b['uid']);
}

send_headers();
echo(uldap_json_encode(
        uldap_search('uni', "(objectClass=person)", array('uid', 'cn')),
        'sort_users'
        ));
?>
