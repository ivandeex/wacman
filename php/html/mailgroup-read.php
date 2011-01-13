<?php
// $Id$

// Retrieve mail group object

require '../lib/common.php';

send_headers();
$id = req_param('id');
if (empty($id))  error_page("id is missing");

$mgrp = create_obj('mailgroup');
$msg = obj_read($mgrp, 'cgp', $id);
if ($msg)  error_page($msg);
echo(obj_json_encode($mgrp));
?>
