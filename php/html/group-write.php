<?php
// $Id$

// Retrieve group object

require '../lib/common.php';

send_headers();
$id = req_param('_id');
if (empty($id))  error_page("_id: required parameter missing");

$grp = create_obj('group');
$idold = req_param("_idold");
if (!empty($idold)) {
    // it's an update of existing group
    $msg = obj_read($grp, 'uni', $idold, array('objectClass' => 'posixGroup', 'cn' => '$_ID'));
    if ($msg)  error_page($msg);
}

// rename the group if needed
$renamed = false;
if (!empty($idold) && $id != $idold) {
    $dn_old = get_attr($grp, 'dn');
    $rdn_new = make_new_rdn('group', $id, $dn_old, $idold);
    error_page("old=$dn_old new=$rdn_new");
    $res = uldap_entry_rename($srv, $dn_old, $rdn_new);
    if ($res['code'])
        error_page(_T('Cannot rename group "%s" to "%s": %s', $idold, $id, $res['error']));
    $renamed = true;
}

obj_update($grp);
$msg = obj_write($grp, 'uni', $id, $idold);
if ($msg)  error_page($msg);

echo(json_ok(array('refresh' => $renamed)));
?>
