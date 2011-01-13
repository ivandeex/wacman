<?php
// $Id$

// Return list of users from LDAP

require '../lib/common.php';

function sort_groups ($a, $b) {
    return strcmp($a['cn'], $b['cn']);
}

send_headers();
echo(uldap_json_encode(
        uldap_search('uni', "(objectClass=posixGroup)", array('cn')),
        'sort_groups'
        ));
?>
