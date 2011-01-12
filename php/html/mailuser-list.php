<?php
// $Id$

// Return list of users from LDAP

require '../lib/common.php';

send_headers();

$res = cgp_cmd('cgp', 'ListAccounts', get_config('mail_domain'));
if ($res['code'])  error_page($res['error']);

$arr = array();
foreach ($res['data'] as $name => $dummy)
    $arr[] = array('uid' => $name);
echo(json_ok($arr));

srv_disconnect_all();
?>
