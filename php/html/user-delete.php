<?php
// $Id$

// Delete user object

require '../lib/common.php';

send_json_headers();

$uid = isset($_GET['uid']) ? $_GET['uid'] : '';
if (empty($uid)) {
    echo json_error("uid: required parameter wrong or not specified");
    exit;
}

echo json_error('oops');
srv_disconnect_all();

?>
