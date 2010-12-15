<?php
// $Id$

// Return list of users from LDAP

require '../lib/common.php';

uldap_connect_all();
send_json_headers();

$mgroups = cli_cmd('ListGroups', get_config('mail_domain'));
if ($mgroups['code']) {
    echo json_error($mgroups['error']);
} else {
    $arr = array();
    foreach ($mgroups['data'] as $name)
        $arr[] = array('cn' => $name);
    echo "{success:true,rows:" . json_encode($arr) . "}\n";
}

uldap_disconnect_all();
?>
