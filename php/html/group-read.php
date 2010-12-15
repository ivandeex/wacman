<?php
// $Id$

// Retrieve group object

require '../lib/common.php';

send_json_headers();
if (empty($_GET['cn'])) {
    echo json_error("cn: required parameter wrong or not specified");
    exit;
}

uldap_connect_all();
$cn = $_GET['cn'];
$grp = create_obj('group');

$msg = obj_read($grp, 'uni', "(&(objectClass=posixGroup)(cn=$cn))");
if ($msg) {
    echo json_error($msg);
    uldap_disconnect_all();
    exit;
}

echo obj_json_encode($grp);
uldap_disconnect_all();

?>
