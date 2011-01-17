<?php
// $Id$

// Collection of functions used throughout userman.

function real_path ($path) {
    $real = realpath($path);
    return empty($real) ? $path : $real;
}

define('HTDOCDIR', realpath(LIBDIR.'../html').'/');
define('CONFDIR',  realpath(LIBDIR.'../config').'/');
define('CSSDIR',   'css/');
define('JSDIR',    'js/');


/////////////////////////////////
// HTTP helpers
//

function req_exists ($name) {
    return (isset($_POST[$name]) || isset($_GET[$name]));
}


function req_param ($name) {
    return nvl(isset($_POST[$name]) ? $_POST[$name]
                : (isset($_GET[$name]) ? $_GET[$name] : ''));
}


function req_list () {
    return array_unique(array_merge(array_keys($_POST), array_keys($_GET)));
}


function send_headers ($mime = "text/plain") {
    static $headers_sent;
    if ($headers_sent)
        return;
    $headers_sent = true;
    if ($mime == 'text')  $mime = 'text/plain';
    if ($mime == 'html')  $mime = 'text/html';
    header("Expires: Sat, 26 Jul 1997 05:00:00 GMT");
    header('Last-Modified: ' . gmdate('D, d M Y H:i:s') . ' GMT');
    header("Cache-Control: no-store, no-cache, must-revalidate");
    header('Cache-Control: post-check=0, pre-check=0', false);
    header("Pragma: no-cache");
    header("Content-Type: $mime; charset=UTF-8");
}


function json_error ($msg) {
    return "{success:false,message:" . json_encode($msg) . "}\n";
}


function json_ok ($val = null) {
    return "{success:true" . (is_null($val)? "" : ",data:" . json_encode($val)) . "}\n";
}


function error_page ($msg) {
    if (!is_array($msg))  $msg = array($msg);
    foreach ($msg as &$line) {
        if (function_exists('_T'))  $line = _T($line);
        if (function_exists('log_err'))  log_err($line);
    }
    send_headers();
    echo(json_error($msg));
    exit();
}


//
// Wrapper for setting cookies, which takes into consideration
// phpLDAPadmin configuration values. On success, true is returned. On
// failure, false is returned.
//
// @param string $name The name of the cookie to set.
// @param string $val The value of the cookie to set.
// @param int $expire (optional) The duration in seconds of this cookie. If unspecified, $cookie_time
//            is used from config.php
// @param string $dir (optional) The directory value of this cookie (see php.net/setcookie)
//
function set_a_cookie ($name, $val, $expire = null, $dir = null) {
    $ret = false;

    if ($expire == null) {
        $cookie_time = get_config('session_cookie_time');
        $expire = $cookie_time == 0 ? null : time() + $cookie_time;
    }

    if ($dir == null)  $dir = dirname( $_SERVER['PHP_SELF'] );

    if (@setcookie($name, $val, $expire, $dir)) {
        $_COOKIE[$name] = $val;
        $ret = true;
    }

    return $ret;
}


/////////////////////////////////
// Basic functions
//

function str2bool($s) {
    if (empty($s))  return false;
    $s = trim($s);
    if (empty($s))  return false;
    return (strpos("yto1", strtolower(substr($s,0,1))) !== FALSE);
}


function bool2str($v) {
    return str2bool($v) ? 'Yes' : 'No';
}


function nvl ($s) {
    return empty($s) ? '' : trim($s);
}


/////////////////////////////////
// List functions
//

function split_list ($str, $as_string = false) {
    $str = nvl($str);
    if (empty($str))  return array();
    $arr = preg_split('!(?:\s*[,;: ]\s*)+!', $str);
    sort($arr);
    return $as_string ? implode(',', $arr) : $arr;
}


function join_list ($arr) {
    if (empty($arr))
        return '';
    sort($arr);
    return nvl(implode(',', $arr));
}


function append_list ($a, $b, $as_string = false) {
    if (! is_array($a))  $a = split_list($a);
    if (! is_array($b))  $b = split_list($b);
    $r = array();
    foreach ($a as $x)  { if (nvl($x) != '')  $r[$x] = 1; }
    foreach ($b as $x)  { if (nvl($x) != '')  $r[$x] = 1; }
    $r = array_keys($r);
    if ($as_string)  return join_list($r);
    sort($r);
    return $r;
}


function remove_list ($a, $b, $asstring = false) {
    if (! is_array($a))  $a = split_list($a);
    if (! is_array($b))  $b = split_list($b);
    $r = array();
    foreach ($a as $x)  { if (nvl($x) != '')  $r[$x] = 1; }
    foreach ($b as $x)  unset($r[$x]);  // FIXME: gotta clean undefined values
    $r = array_keys($r);
    if ($asstring)
        return join_list($r);
    sort($r);
    return $r;
}


function compare_lists ($a, $b) {
    if (! is_array($a))  $a = split_list($a);
    if (! is_array($b))  $b = split_list($b);
    $only_a = array();
    $only_b = array();
    $common = array();
    foreach ($a as $x)  {
        if (array_search($x, $b) !== false)
            $common[$x] = 1;
        else
            $only_a[$x] = 1;
    }
    foreach ($b as $x)  {
        if (array_search($x, $a) !== false)
            $common[$x] = 1;
        else
            $only_b[$x] = 1;
    }
    return array(join_list(array_keys($only_a)),
                join_list(array_keys($only_b)),
                join_list(array_keys($common)));
}


//
// Custom error handler. When a PHP error occurs,
// PHP will call this function rather than printing the typical PHP error string.
// This provides phpLDAPadmin the ability to format an error message more "pretty"
// and provide a link for users to submit a bug report. This function is not to
// be called by users. It is exclusively for the use of PHP internally. If this
// function is called by PHP from within a context where error handling has been
// disabled (ie, from within a function called with "@" prepended), then this
// function does nothing.
//
// @param int $errno The PHP error number that occurred (ie, E_ERROR, E_WARNING, E_PARSE, etc).
// @param string $errstr The PHP error string provided (ie, "Warning index "foo" is undefined)
// @param string $file The file in which the PHP error ocurred.
// @param int $lineno The line number on which the PHP error ocurred
//
function error_handler ($errno, $errstr, $file, $lineno) {
    // error_reporting will be 0 if the error context occurred
    // within a function call with '@' preprended (ie, @ldap_bind() );
    // So, don't report errors if the caller has specifically
    // disabled them with '@'
    if (0 == ini_get( 'error_reporting' ) || 0 == error_reporting())
        return;

    $file = basename($file);
    $caller = basename($_SERVER['PHP_SELF']);
    $errtype = "";
    switch ($errno) {
        case E_STRICT: $errtype = "E_STRICT"; break;
        case E_ERROR: $errtype = "E_ERROR"; break;
        case E_WARNING: $errtype = "E_WARNING"; break;
        case E_PARSE: $errtype = "E_PARSE"; break;
        case E_NOTICE: $errtype = "E_NOTICE"; break;
        case E_CORE_ERROR: $errtype = "E_CORE_ERROR"; break;
        case E_CORE_WARNING: $errtype = "E_CORE_WARNING"; break;
        case E_COMPILE_ERROR: $errtype = "E_COMPILE_ERROR"; break;
        case E_COMPILE_WARNING: $errtype = "E_COMPILE_WARNING"; break;
        case E_USER_ERROR: $errtype = "E_USER_ERROR"; break;
        case E_USER_WARNING: $errtype = "E_USER_WARNING"; break;
        case E_USER_NOTICE: $errtype = "E_USER_NOTICE"; break;
        case E_ALL: $errtype = "E_ALL"; break;
        default: $errtype = _T('Unrecognized error number: ') . $errno;
    }

    $errstr = preg_replace("/\s+/", " ", $errstr);
    if ($errno == E_NOTICE) {
        echo sprintf(_T(
            '<center><table class=\'notice\'><tr><td colspan=\'2\'><center><img src=\'images/warning.png\' height=\'12\' width=\'13\' alt="Warning" />
            <b>You found a non-fatal phpLDAPadmin bug!</b></td></tr><tr><td>Error:</td><td><b>%s</b> (<b>%s</b>)</td></tr><tr><td>File:</td>
            <td><b>%s</b> line <b>%s</b>, caller <b>%s</b></td></tr><tr><td>Versions:</td><td>PLA: <b>%s</b>, PHP: <b>%s</b>, SAPI: <b>%s</b>
            </td></tr><tr><td>Web server:</td><td><b>%s</b></td></tr>
            <tr><td colspan=\'2\'><center><a target=\'new\' href=\'%s\'>Please check and see if this bug has been reported here</a>.</center></td></tr>
            <tr><td colspan=\'2\'><center><a target=\'new\' href=\'%s\'>If it hasnt been reported, you may report this bug by clicking here</a>.</center></td></tr>
            </table></center><br />'),
            $errstr, $errtype, $file,
            $lineno, $caller, 'current', phpversion(), php_sapi_name(),
            $_SERVER['SERVER_SOFTWARE'],
            get_href('search_bug',"&summary_keyword=".htmlspecialchars($errstr)),get_href('add_bug')
            );
        return;
    }

    $server = isset($_SERVER['SERVER_SOFTWARE']) ? $_SERVER['SERVER_SOFTWARE'] : 'undefined';
    $phpself = isset($_SERVER['PHP_SELF']) ? basename( $_SERVER['PHP_SELF'] ) : 'undefined';
    error_page(sprintf(_T(
        'Congratulations! You found a bug in phpLDAPadmin.<br /><br />
        <table class=\'bug\'>
        <tr><td>Error:</td><td><b>%s</b></td></tr>
        <tr><td>Level:</td><td><b>%s</b></td></tr>
        <tr><td>File:</td><td><b>%s</b></td></tr>
        <tr><td>Line:</td><td><b>%s</b></td></tr>
        <tr><td>Caller:</td><td><b>%s</b></td></tr>
        <tr><td>PLA Version:</td><td><b>%s</b></td></tr>
        <tr><td>PHP Version:</td><td><b>%s</b></td></tr>
        <tr><td>PHP SAPI:</td><td><b>%s</b></td></tr>
        <tr><td>Web server:</td><td><b>%s</b></td></tr>
        </table>
        <br />
        Please report this bug by clicking below!'), $errstr, $errtype, $file,
        $lineno, $phpself, 'current',
        phpversion(), php_sapi_name(), $server)
        );
}

?>
