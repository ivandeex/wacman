<?php
// $Id$

// Delete user object

require '../lib/common.php';

send_json_headers();
$id = nvl(isset($_GET['uid']) ? $_GET['uid'] : '');
if (empty($id)) {
    echo json_error("uid: required parameter wrong or not specified");
    exit;
}
if (is_reserved($id)) {
    echo json_error("Cannot delete reserved object");
    exit;
}
echo json_error('oops');
srv_disconnect_all();

?>
