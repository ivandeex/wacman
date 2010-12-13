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
    pla_error('Sorry, Userman is a PHP5 application.');

// Our error handler receives all error notices that pass the error_reporting() level set above.
#set_error_handler('pla_error_handler');
// Disable error reporting until all our required functions are loaded.
#error_reporting(0);
error_reporting(E_ALL);

require_once realpath(LIBDIR . 'translations.php');
require_once realpath(LIBDIR . 'logging.php');
require_once realpath(LIBDIR . 'config.php');
require_once realpath(LIBDIR . 'ldap.php');

// We are now ready for error reporting.
#error_reporting(E_DEBUG);

// Make sure this PHP install has LDAP extension
if (! extension_loaded('ldap'))
    pla_error("Your install of PHP appears to be missing LDAP support.");

// Make sure that we have php-xml loaded.
if (! function_exists('xml_parser_create'))
    pla_error("Your install of PHP appears to be missing XML support");

// Make sure their session save path is writable, if they are using a file system session module, that is.
if (! strcasecmp('Files', session_module_name() && ! is_writable(realpath(session_save_path()))))
    pla_error('Please check session.save_path in php.ini: "'.session_save_path().'" is not writable.');

setup_language();

#pla_session_start();

// Strip slashes from GET, POST, and COOKIE variables if this
// PHP install is configured to automatically addslashes()
if (get_magic_quotes_gpc() && (! isset($slashes_stripped) || ! $slashes_stripped)) {
    array_stripslashes($_REQUEST);
    array_stripslashes($_GET);
    array_stripslashes($_POST);
    array_stripslashes($_COOKIE);
    $slashes_stripped = true;
}

?>
