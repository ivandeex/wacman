<?php
// $Id$

// Return list of users from LDAP

require '../lib/common.php';

uldap_connect_all();
send_json_headers();

$res = cli_cmd('ListGroups', get_config('mail_domain'));
if ($res['code']) {
    echo json_error($res['error']);
} else {
    $arr = array();
    foreach ($res['data'] as $name)
        $arr[] = array('uid' => $name);
    echo "{success:true,rows:" . json_encode($arr) . "}\n";
}

uldap_disconnect_all();
?>
