<?php
// $Id$

// Retrieve group object

require '../lib/common.php';

send_headers();
$id = req_param('id');
if (empty($id))  error_page("id is missing");

$grp = create_obj('group');
$msg = obj_read($grp, 'uni', $id);
echo($msg ? json_error($msg) : obj_json_encode($grp));
?>
