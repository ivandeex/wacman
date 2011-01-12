<?php
// $Id$

// Retrieve user object

require '../lib/common.php';

send_headers();
$uid = req_param('uid');
if (empty($uid))  error_page("uid: required parameter wrong or not specified");

$searches = array(
    'uni' => "(&(objectClass=person)(uid=\${uid}))",
    'ads' => "(&(objectClass=user)(cn=\${cn}))",
    'cgp' => ""
);

$usr = create_obj('user');
set_attr($usr, 'uid', $uid);

foreach ($searches as $srv => $filter) {
    if ($servers[$srv]['disable'])
        continue;
    $msg = obj_read($usr, $srv, $filter);
    if (! $msg)
        continue;
    if ($srv == 'uni') {
        echo json_error($msg);
        srv_disconnect_all();
        exit;
    }
    log_info('will create "%s" user for uid "%s"', $srv, $uid);
}

echo(obj_json_encode($usr));
srv_disconnect_all();

?>
