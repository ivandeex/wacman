<?php
// $Id$

// HTTP helpers

function send_json_headers ($mime = "text/plain") {
    if ($mime == 'text')  $mime = 'text/plain';
    if ($mime == 'html')  $mime = 'text/html';
    header("Expires: Sat, 26 Jul 1997 05:00:00 GMT");
    header("Cache-Control: no-store, no-cache, must-revalidate");
    header("Pragma: no-cache");
    header("Content-Type: $mime; charset=UTF-8");
}

function json_error ($msg) {
    return '{success:false,message:' . json_encode($msg) . '}';
}

function json_ok () {
    return '{success:true}';
}

?>
