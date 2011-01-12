<?php
// $Id$

// Retrieve mail group object

require '../lib/common.php';

send_headers();
$id = req_param('uid');
if (empty($id))  error_page("uid: required parameter wrong or not specified");

$mgrp = create_obj('mailgroup');
$msg = obj_read($mgrp, 'cgp', null, $id);
if ($msg)  error_page($msg);
echo(obj_json_encode($mgrp));
?>
