<?php
// $Id$

// Retrieve user object

require '../lib/common.php';

uldap_connect_all();
send_json_headers();

$uid = isset($_GET['uid']) ? $_GET['uid'] : '';
if (empty($uid)) {
    echo json_error("uid: required parameter wrong or not specified");
    uldap_disconnect_all();
    exit;
}

$searches = array(
    'uni' => "(&(objectClass=person)(uid=\${uid}))",
    'ads' => "(&(objectClass=user)(cn=\${cn}))",
    'cgp' => "(&(objectClass=CommuniGateAccount)(uid=\${uid}))",
    'cli' => ""
);

$usr = create_obj('user');
set_attr($usr, 'uid', $uid);

foreach ($searches as $srv => $filter) {
    if ($servers[$srv]['disable'])
        continue;
    $msg = obj_read($usr, $srv, $filter);
    if (! $msg)
        continue;
    if ($srv == 'uni') {
        echo json_error($msg);
        uldap_disconnect_all();
        exit;
    }
    log_info('will create "%s" user for uid "%s"', $srv, $uid);
}

echo obj_json_encode($usr);
uldap_disconnect_all();

?>
