<?php
// $Id$

// Return list of users from LDAP

require '../lib/common.php';

send_headers();
$res = obj_list('group', 'uni');
echo($res['code'] ? json_error($res['error']) : json_ok($res['data']));
?>
