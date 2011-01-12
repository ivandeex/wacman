<?php
// $Id$

// Return list of users from LDAP

require '../lib/common.php';

send_headers();

$res = cgp_cmd('cgp', 'ListGroups', get_config('mail_domain'));
if ($res['code'])  error_page($res['error']);

$mgroups = array();
foreach ($res['data'] as $name)  $mgroups[] = $name;
asort($mgroups);
$res = array();
foreach ($mgroups as $name)  $arr[] = array('uid' => $name);
echo(json_ok($arr));

srv_disconnect_all();
?>
