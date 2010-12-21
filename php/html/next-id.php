<?php
// $Id$

// Return list of users from LDAP

require '../lib/common.php';

uldap_connect_all();
send_json_headers();

$which = isset($_GET['which']) ? $_GET['which'] : '';
if (empty($which)) {
    echo json_error("which: required parameter wrong or not specified");
    uldap_disconnect_all();
    exit;
}

switch ($which) {
    case 'unix_uidn':
        echo '2001';
        break;
    case 'unix_gidn':
        echo '3002';
        break;
    case 'cgp_telnum':
        echo '105';
        break;
    default:
        echo '0';
        log_error('unknown id type "%s"', $which);
        break;
}

uldap_disconnect_all();
?>
