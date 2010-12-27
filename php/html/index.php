<?php
// $Id$

// Sanity checking
define('LIBDIR','../lib/');
ini_set('display_errors',1);
error_reporting(E_ALL);

// General functions needed to proceed.
ob_start();
if (! is_readable(LIBDIR.'common.php')) {
	ob_end_clean();
	die("Fatal error: cannot read 'common.php'");
}
require LIBDIR.'common.php';
ob_end_clean();
// Start the show!
?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML Basic 1.0//EN" "http://www.w3.org/TR/xhtml-basic/xhtml-basic10.dtd">
<html>
<head>
  <title>Userman</title>
  <link rel="shortcut icon" href="userman.ico" type="image/x-icon" />
<?php foreach (split_list(get_config('theme_css')) as $css): ?>
  <link rel="stylesheet" type="text/css" href="<?php echo $css ?>" />
<?php endforeach ?>
  <link rel="stylesheet" type="text/css" href="css/userman.css" />
<?php foreach (split_list(get_config('ext_js')) as $js): ?>
  <script type="text/javascript" src="<?php echo $js ?>"></script>
<?php endforeach ?>
  <link rel="stylesheet" type="text/css" href="<?php echo get_config('lovcombo_dir').'/css/Ext.ux.form.LovCombo.css' ?>" />
  <script type="text/javascript" src="<?php echo get_config('lovcombo_dir').'/js/Ext.ux.util.js' ?>"></script>
  <script type="text/javascript" src="<?php echo get_config('lovcombo_dir').'/js/Ext.ux.form.LovCombo.js' ?>"></script>
<?php if ($ext_js_lang): ?>
  <script type="text/javascript" src="<?php echo $ext_js_lang ?>"></script>
<?php endif ?>
  <script type="text/javascript" src="config-config.php"></script>
  <script type="text/javascript" src="js/main.js"></script>
</head>
<body>
  <div id="preloading-mask"></div>
  <div id="preloading-box">
    <span id="preloading-message">Loading. Please wait...</span>
  </div>
</body>
</html>

