<?php
// $Id$

// HTTP helpers

function send_json_headers () {
    header("Expires: Sat, 26 Jul 1997 05:00:00 GMT");
    header("Cache-Control: no-store, no-cache, must-revalidate");
    header("Pragma: no-cache");
    header("Content-Type: text/plain; charset=UTF-8");
}

?>
