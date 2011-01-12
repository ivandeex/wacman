<?php
// $Id$

// Create or update a mail group

require '../lib/common.php';

send_headers();
$id = req_param("_id");
$idold = req_param("_idold");
$update = !empty($idold);
if (empty($id))  error_page("_id: required parameter missing");

$srv = 'cgp';
$domain = get_config('mail_domain');
$reply = null;

// pack settings
$params = array();
if (req_exists('params')) {
    $params = cgp_unpack($srv, req_param('params'), $msg);
    if (! empty($msg))
        error_page($msg);
    if (! is_array($params))
        error_page("Mail group parameters should be an array");
}
if (req_exists('cn'))
    $params['RealName'] = req_param('cn');
//if (req_exists('groupMember'))
//    $params['Members'] = split_list(req_param('groupMember'));

// rename the group if needed
if ($update && $id != $idold) {
    $res = cgp_cmd($srv, 'RenameGroup', $idold.'@'.$domain, $id.'@'.$domain);
    if ($res['code'])
        error_page(_T('Cannot rename mail group "%s" to "%s": %s',
                        $idold, $id, $res['error']));
    $reply = array('refresh' => true);
}

$res = cgp_cmd($srv, ($update ? 'SetGroup' : 'CreateGroup'), $id.'@'.$domain, $params);
echo($res['code']?json_error($res['error']):json_ok($reply));
?>
