<?php
// $Id$

// Create or update a mail group

require '../lib/common.php';

send_headers();
$id = req_param("_id");
if (empty($id))  error_page("_id: required parameter missing");

$mgrp = create_obj('mailgroup');
$idold = req_param("_idold");
if (!empty($idold)) {
    // it's an update of existing mail group
    $msg = obj_read($mgrp, 'cgp', null, $idold);
    if ($msg)  error_page($msg);
}

obj_update($mgrp);
$msg = obj_write($mgrp, 'cgp', $id, $idold);
if ($msg)  error_page($msg);

echo(json_ok(array('refresh' => $mgrp['renamed'])));
//$p=array('refresh'=>$mgrp['renamed']);foreach(req_list() as $n) $p[$n]=req_param($n);echo(json_ok($p));
?>
