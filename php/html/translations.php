<?php
// $Id: group-list.php 1585 2010-12-14 02:28:00Z vitki $

// Return translations

require '../lib/common.php';

send_json_headers();

$lang = get_config('language', 'en');
$trans = isset($translations[$lang]) ? $translations[$lang] : array();

echo 'var trans = ' . json_encode($trans) . ';';
?>
