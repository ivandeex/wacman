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
$gid = $_GET['uid'];
$mgrp = create_obj('mailgroup');

$res = cli_cmd('GetGroup', $gid.'@'.get_config('mail_domain'));
if ($res['code']) {
    echo json_error($res['error']);
    uldap_disconnect_all();
    exit;
}

$data = $res['data'];
init_attr($mgrp, 'uid', $gid);
init_attr($mgrp, 'cn', nvl($data['RealName']));
unset($data['RealName']);
init_attr($mgrp, 'groupMember', join_list($data['Members']));
unset($data['Members']);
init_attr($mgrp, 'params', dict2str($data));

echo obj_json_encode($mgrp);
uldap_disconnect_all();

?>
