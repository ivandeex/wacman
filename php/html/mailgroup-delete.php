<?php
// $Id$

// Delete mail group object

require '../lib/common.php';

send_json_headers();
$id = nvl(isset($_GET['uid']) ? $_GET['uid'] : '');
if (empty($id)) {
    echo json_error("uid: required parameter missing");
    exit;
}
if (is_reserved($id)) {
    echo json_error("Cannot delete reserved object");
    exit;
}
$res = cgp_cmd('cgp', 'DeleteGroup', $id.'@'.get_config('mail_domain'));
echo($res['code'] ? json_error($res['error']) : json_ok());
srv_disconnect_all();

?>
