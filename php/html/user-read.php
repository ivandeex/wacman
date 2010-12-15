<?php
// $Id$

// Retrieve user object

require '../lib/common.php';

uldap_connect_all();
send_json_headers();

$usr = create_obj('user');

$uid = isset($_GET['uid']) ? $_GET['uid'] : '';
if (empty($uid)) {
    echo json_error("uid: required parameter wrong or not specified");
    uldap_disconnect_all();
    exit;
}

if (! $servers['uni']['disable']) {
    $msg = obj_read($usr, 'uni', "(&(objectClass=person)(uid=$uid))");
    if ($msg) {
        echo json_error($msg);
        uldap_disconnect_all();
        exit;
    }
}

if (! $servers['ads']['disable']) {
    $uid = get_attr($usr, 'uid');
    $cn = get_attr($usr, 'cn');
    $msg = obj_read($usr, 'ads', "(&(objectClass=user)(cn=$cn))");
    if ($msg)
        log_info('will create windows user "%s" for uid "%s"', $cn, $uid);
}

if (! $servers['cgp']['disable']) {
    $uid = get_attr($usr, 'uid');
    $cgp_msg = obj_read($usr, 'cgp', "(&(objectClass=CommuniGateAccount)(uid=$uid))");
    if ($msg)
        log_info('will create mail account for uid "%s"', $uid);
}

echo obj_json_encode($usr);
uldap_disconnect_all();

?>
