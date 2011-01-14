<?php
// $Id$

// Retrieve user object

require '../lib/common.php';

send_headers();
$id = req_param('id');
if (empty($id))  error_page("id is missing");

$usr = create_obj('user');

foreach (array_keys($servers) as $srv) {
    $msg = obj_read($usr, $srv, $id);
    if ($msg && $srv == 'uni')  error_page($msg);
}

echo(obj_json_encode($usr));
?>
