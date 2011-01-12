<?php
// $Id$

// Retrieve user object

require '../lib/common.php';

send_headers();
$id = req_param('uid');
if (empty($id))  error_page("uid: required parameter wrong or not specified");

$searches = array(
    'uni' => "(&(objectClass=person)(uid=\${ID}))",
    'ads' => "(&(objectClass=user)(cn=\${cn}))",
    'cgp' => ""
);

$usr = create_obj('user');

foreach ($searches as $srv => $filter) {
    if ($servers[$srv]['disable'])
        continue;
    $msg = obj_read($usr, $srv, $filter, $id);
    if (! $msg)
        continue;
    if ($srv == 'uni')  error_page($msg);
    log_info('will create "%s" user for uid "%s"', $srv, $id);
}

echo(obj_json_encode($usr));
?>
