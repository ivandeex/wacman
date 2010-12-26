<?php
// $Id$

// Return list of users from LDAP

require '../lib/common.php';

send_json_headers();

$res = cgp_cmd('cgp', 'ListGroups', get_config('mail_domain'));
if ($res['code']) {
    echo json_error($res['error']);
} else {
    $arr = array();
    foreach ($res['data'] as $name)
        $arr[] = array('uid' => $name);
    echo "{success:true,rows:" . json_encode($arr) . "}\n";
}

srv_disconnect_all();
?>
