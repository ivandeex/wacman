<?php
// $Id$

// Return translations

require '../lib/common.php';

send_json_headers();

$lang = get_config('language', 'en');
$trans = isset($translations[$lang]) ? $translations[$lang] : array();

echo 'var trans = ' . json_encode($trans) . ';';
?>
