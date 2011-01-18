<?php
// $Id$

// Create or update a group object

require '../lib/common.php';

send_headers();
$srv = 'uni';
$id = req_param('_id');
if (empty($id))  error_page("_id: required parameter missing");

$grp = create_obj('group');
$idold = req_param("_idold");
if (!empty($idold)) {
    // it's an update of existing group
    $msg = obj_read($grp, $srv, $idold, array('objectClass' => 'posixGroup', 'cn' => '$_ID'));
    if ($msg)  error_page($msg);
}
obj_update($grp);

$msg = obj_write($grp, $srv, $id, $idold);
echo($msg ? json_error($msg) : json_ok(array('refresh' => $grp['renamed'])));
?>
