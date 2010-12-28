<?php
// $Id$

// Retrieve group object

require '../lib/common.php';

send_json_headers();
if (empty($_GET['cn'])) {
    echo json_error("cn: required parameter wrong or not specified");
    exit;
}

$grp = create_obj('group');
set_attr($grp, 'cn', $_GET['cn']);
$msg = obj_read($grp, 'uni', "(&(objectClass=posixGroup)(cn=\${cn}))");
echo $msg ? json_error($msg) : obj_json_encode($grp);
srv_disconnect_all();

?>
