<?php
// $Id$

// Retrieve user object

require '../lib/common.php';

send_headers();
$id = req_param('id');
if (empty($id))  error_page('id is missing');

$usr = create_obj('user');

foreach (array_keys($servers) as $srv) {
    switch ($srv) {
        case 'uni': $cur_oid = $id; break;
        case 'ads': $cur_oid = get_attr($usr, 'cn'); break;
        case 'cgp': $cur_oid = get_attr($usr, 'mail'); break;
        default:    $cur_oid = ''; break;
    }
    if (empty($cur_oid))  continue;

    $msg = obj_read($usr, $srv, $cur_oid);
    if ($msg && $srv == 'uni')
        error_page($msg);
    else if ($msg)
        log_error('user "%s" not found on server %s', $id, $srv);
}

echo(obj_json_encode($usr));
?>
