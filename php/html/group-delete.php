<?php
// $Id$

// Delete group object

require '../lib/common.php';

send_json_headers();
if (empty($_GET['cn'])) {
    echo json_error("cn: required parameter wrong or not specified");
    exit;
}

echo json_error('oops');
srv_disconnect_all();

?>
