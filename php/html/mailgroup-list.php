<?php
// $Id$

// Return list of users from LDAP

require '../lib/common.php';

uldap_connect_all();
send_json_headers();

$mgroups = cli_cmd('ListGroups', get_config('mail_domain'));
if (is_null($mgroups)) {
    echo "{success:false,message:" . json_encode(get_error()) . "}\n";
} else {
    $arr = array();
    foreach ($mgroups as $name)
        $arr[] = array('cn' => $name);
    echo "{success:true,rows:" . json_encode($arr) . "}\n";
}

uldap_disconnect_all();
?>
