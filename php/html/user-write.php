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
        if ($msg && $srv == 'uni')
            error_page($msg);
        else if ($msg)
            log_error('user "%s" not found on server %s', $idold, $srv);
    }
}

$mail_old = get_attr($usr, 'mail');
$cn_old = get_attr($usr, 'cn');
obj_update($usr);

foreach (array_keys($servers) as $srv) {
    switch ($srv) {
        case 'uni':
        default:
            list($cur_oid, $old_oid) = array($id, $idold);
            break;
        case 'ads':
            list($cur_oid, $old_oid) = array(get_attr($usr, 'cn'), $cn_old);
            break;
        case 'cgp':
            list($cur_oid, $old_oid) = array(get_attr($usr, 'mail'), $mail_old);
            break;
    }
    $msg = obj_write($usr, $srv, $cur_oid, $old_oid);
    if ($msg)  error_page($msg);
}
echo(json_ok(array('refresh' => $usr['renamed'])));
?>
