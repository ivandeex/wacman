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
        switch ($srv) {
            case 'uni': $cur_oid = $idold; break;
            case 'ads': $cur_oid = get_attr($usr, 'cn'); break;
            case 'cgp': $cur_oid = get_attr($usr, 'mail'); break;
            default:    $cur_oid = ''; break;
        }
        if (empty($cur_oid))  continue;

        $msg = obj_read($usr, $srv, $cur_oid);
        if ($msg && $srv == 'uni')
            error_page($msg);
        if ($msg)
            log_error('user "%s" not found on server %s: %s', $idold, $srv, json_encode($msg));
        // flush reading errors
        $usr['msg'] = array();
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
    if ($msg && $srv == 'uni')
        error_page($msg);
}

// create user's home directory
$home = get_attr($usr, 'homeDirectory');
if ($home && str2bool(get_config('create_homes')) && $home != "-" && !file_exists($home))
    $msg = create_user_home($usr, $home);

echo($msg ? json_error($msg) : json_ok(array('refresh' => $usr['renamed'])));
?>
