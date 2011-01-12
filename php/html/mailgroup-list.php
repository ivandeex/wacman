<?php
// $Id$

// Return list of users from LDAP

require '../lib/common.php';

$res = cgp_cmd('cgp', 'ListGroups', get_config('mail_domain'));
if ($res['code'])  error_page($res['error']);
send_headers();

$mgroups = array();
foreach ($res['data'] as $name)  $mgroups[] = $name;
asort($mgroups);
$res = array();
foreach ($mgroups as $name)  $arr[] = array('uid' => $name);
echo(json_ok($arr));
?>
