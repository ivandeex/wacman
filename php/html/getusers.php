<?php
// $Id$

// Return list of users from LDAP

require '../lib/common.php';

configure();
ldap_connect_to('uni');
$res = ldap_search_for('uni', "(objectClass=person)", array('uid', 'cn'));
$msg = get_error();
if (empty($res) && !empty($msg)) {
    echo "{success:false,message:".json_encode($msg)."}";
} else {
    echo "{success:true,rows:".json_encode($res)."}";
}
?>
