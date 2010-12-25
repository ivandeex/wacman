<?php
// $Id$

// Retrieve mail group object

require '../lib/common.php';

send_json_headers();
if (empty($_GET['uid'])) {
    echo json_error("uid: required parameter wrong or not specified");
    exit;
}

uldap_connect_all();
$id = $_GET['uid'];
$mgrp = create_obj('mailgroup');

$res = cgp_cmd('cli', 'GetGroup', $id.'@'.get_config('mail_domain'));
if ($res['code']) {
    echo json_error($res['error']);
    uldap_disconnect_all();
    exit;
}

$data = $res['data'];
set_attr($mgrp, 'uid', $id);
set_attr($mgrp, 'cn', nvl($data['RealName']));
set_attr($mgrp, 'groupMember', join_list($data['Members']));
unset($data['RealName']);
unset($data['Members']);
set_attr($mgrp, 'params', cgp_string('cli', $data));

echo obj_json_encode($mgrp);
uldap_disconnect_all();

?>
