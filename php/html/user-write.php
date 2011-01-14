<?php
// $Id$

// Create or update a user record

require '../lib/common.php';

send_headers();
$id = req_param('_id');
if (empty($id))  error_page("_id: required parameter missing");

$usr = create_obj('user');
$idold = req_param('_idold');
if (!empty($idold)) {
    // it's an update of existing user
    foreach (array_keys($servers) as $srv) {
        $msg = obj_read($usr, $srv, $idold);
        if ($msg && $srv == 'uni')  error_page($msg);
        break;
    }
}
obj_update($usr);

foreach (array_keys($servers) as $srv) {
    $msg = obj_write($usr, $srv, $id, $idold);
    if ($msg)  error_page($msg);
    break;
}
echo(json_ok(array('refresh' => $usr['renamed'])));
?>
