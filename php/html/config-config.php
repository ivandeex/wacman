<?php
// $Id$

// Return translations

require '../lib/common.php';

send_json_headers();
$lang = get_config('language', 'en');
$trans = isset($translations[$lang]) ? $translations[$lang] : array();
echo "var trans = " . json_encode($trans) . ";\n";
echo "var config = " . json_encode($config) . ";\n";
echo "var all_attrs = " . json_encode($all_attrs) . ";\n";
?>
