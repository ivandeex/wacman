<?php
// $Id$

// Code to be executed at the top of each Userman page.

@define('LIBDIR','../lib/');
ini_set('display_errors',1);
error_reporting(E_ALL);

// For PHP5 backward/forward compatibility
if (! defined('E_STRICT'))
    define('E_STRICT',2048);

#ob_start();
require_once realpath(LIBDIR.'functions.php');
#ob_end_clean();

if (phpversion() < 5)
    error_page('Sorry, Userman is a PHP5 application.');

// Our error handler receives all error notices that pass the error_reporting() level set above.
#set_error_handler('error_handler');
// Disable error reporting until all our required functions are loaded.
#error_reporting(0);
error_reporting(E_ALL);

// Include all function libraries
$includes = array(
    'language.php',
    'logging.php',
    'config.php',
    'http.php',
    'ldap.php',
    'CLI.php',
    'communigate.php',
    'attrs.php'
    );

foreach ($includes as $file) {
    require_once realpath(LIBDIR . $file);
}

// We are now ready for error reporting.
#error_reporting(E_DEBUG);

// Make sure this PHP install has LDAP extension
if (! extension_loaded('ldap'))
    error_page("Your install of PHP appears to be missing LDAP support.");

// Make sure that we have php-xml loaded.
if (! function_exists('xml_parser_create'))
    error_page("Your install of PHP appears to be missing XML support");

// Make sure their session save path is writable, if they are using a file system session module, that is.
if (! strcasecmp('Files', session_module_name() && ! is_writable(realpath(session_save_path()))))
    error_page('Please check session.save_path in php.ini: "'.session_save_path().'" is not writable.');

// Strip slashes from GET, POST, and COOKIE variables if this
// PHP install is configured to automatically addslashes()
if (get_magic_quotes_gpc() && (! isset($slashes_stripped) || ! $slashes_stripped)) {
    array_stripslashes($_REQUEST);
    array_stripslashes($_GET);
    array_stripslashes($_POST);
    array_stripslashes($_COOKIE);
    $slashes_stripped = true;
}

configure();
setup_language();
setup_all_attrs();
#pla_session_start();

?>
