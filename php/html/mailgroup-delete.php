<?php
// $Id$

// Delete mail group object

require '../lib/common.php';

send_headers();
$id = req_param('uid');
if (empty($id))  error_page("uid: required parameter missing");
if (is_reserved($id))  error_page("Cannot delete reserved object");

$res = cgp_cmd('cgp', 'DeleteGroup', $id.'@'.get_config('mail_domain'));
echo($res['code'] ? json_error($res['error']) : json_ok());
srv_disconnect_all();

?>
