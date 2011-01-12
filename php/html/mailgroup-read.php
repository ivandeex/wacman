<?php
// $Id$

// Retrieve mail group object

require '../lib/common.php';

send_headers();
$id = req_param('uid');
if (empty($id))  error_page("uid: required parameter wrong or not specified");

$srv = 'cgp';
$mgrp = create_obj('mailgroup');

$res = cgp_cmd($srv, 'GetGroup', $id.'@'.get_config('mail_domain'));
if ($res['code'])  error_page($res['error']);

$data = $res['data'];
set_attr($mgrp, 'uid', $id);
set_attr($mgrp, 'cn', nvl($data['RealName']));
set_attr($mgrp, 'groupMember', join_list($data['Members']));
unset($data['RealName']);
unset($data['Members']);
set_attr($mgrp, 'params', cgp_pack($srv, $data));

echo(obj_json_encode($mgrp));
?>
