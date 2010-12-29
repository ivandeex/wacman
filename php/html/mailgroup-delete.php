<?php
// $Id$

// Delete mail group object

require '../lib/common.php';

send_json_headers();
sleep(10);
if (empty($_GET['uid'])) {
    echo json_error("uid: required parameter wrong or not specified");
    exit;
}
echo json_error('oops');
srv_disconnect_all();

?>
