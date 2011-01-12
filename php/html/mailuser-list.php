<?php
// $Id$

// Return list of users from LDAP

require '../lib/common.php';

$res = cgp_cmd('cgp', 'ListAccounts', get_config('mail_domain'));
if ($res['code'])  error_page($res['error']);
send_headers();

$arr = array();
foreach ($res['data'] as $name => $dummy)
    $arr[] = array('uid' => $name);
echo(json_ok($arr));
?>
