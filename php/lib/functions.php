<?php
// $Id$

/**
 * A collection of functions used throughout userman.
 * @author The phpLDAPadmin development team
 * @package phpLDAPadmin
 */

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


function error_page ($msg, $fatal = true) {
    if (function_exists('_T'))  $msg = _T($msg);
    if (function_exists('log_err'))  log_err($msg);
    send_headers();
    echo(json_error($msg));
    if ($fatal)  exit();
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

function split_list ($str, $asstring = false) {
    $str = nvl($str);
    if (empty($str))
        return array();
    $arr = preg_split('!(?:\s*[,;: ]\s*)+!', nvl($str));
    sort($arr);
    return $asstring ? implode(',', $arr) : $arr;
}


function join_list ($arr) {
    if (empty($arr))
        return '';
    sort($arr);
    return nvl(implode(',', $arr));
}


function append_list ($a, $b, $asstring = false) {
    if (! is_array($a))  $a = split_list($a);
    if (! is_array($b))  $b = split_list($b);
    $r = array();
    foreach ($a as $x)  { if (nvl($x) != '')  $r[$x] = 1; }
    foreach ($b as $x)  { if (nvl($x) != '')  $r[$x] = 1; }
    $r = array_keys($r);
    if ($asstring)
        return join_list($r);
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


function compare_lists ($a, $b, $asstring = false) {
    if (! is_array($a))  $a = split_list($a);
    if (! is_array($b))  $b = split_list($b);
    $h_a = array();
    foreach ($a as $x)  { $h_a[$x] = 1; }
    $h_b = array();
    foreach ($b as $x)  { $h_b[$x] = 1; }
    $onlya = array();
    $onlyb = array();
    $common = array();
    foreach ($a as $x)  { $b[$x] ? ($common[$x] = 1) : ($onlya[$x] = 1); }
    foreach ($b as $x)  { $a[$x] ? ($common[$x] = 1) : ($onlyb[$x] = 1); }
    return array(join_list(array_keys(onlya)), join_list(array_keys(onlyb)), join_list(array_keys(common)));
}


//////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////


//
// Check whether a string looks like an email address (user@example.com).
//
function is_mail_string ($s) {
    return (bool)preg_match("/^[_A-Za-z0-9-]+(\\.[_A-Za-z0-9-]+)*@[A-Za-z0-9-]+(\\.[A-Za-z0-9-]+)*$/", $s);
}


//
// Utility wrapper for setting cookies, which takes into consideration
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
    // default return
    $return = false;

    if ($expire == null) {
        $cookie_time = get_config('session_cookie_time');
        $expire = $cookie_time == 0 ? null : time() + $cookie_time;
    }

    if ($dir == null)  $dir = dirname( $_SERVER['PHP_SELF'] );

    if (@setcookie($name, $val, $expire, $dir)) {
        $_COOKIE[$name] = $val;
        $return = true;
    }

    return $return;
}


//
// Used to generate a random salt for crypt-style passwords. Salt strings are used
// to make pre-built hash cracking dictionaries difficult to use as the hash algorithm uses
// not only the user's password but also a randomly generated string. The string is
// stored as the first N characters of the hash for reference of hashing algorithms later.
//
// --- added 20021125 by bayu irawan <bayuir@divnet.telkom.co.id> ---
// --- ammended 20030625 by S C Rigler <srigler@houston.rr.com> ---
//
// @param int $length The length of the salt string to generate.
// @return string The generated salt string.
//
function random_salt ($length) {
    $possible = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ./';
    $str = "";
    mt_srand((double)microtime() * 1000000);
    while (strlen( $str ) < $length)
        $str .= substr($possible, (rand() % strlen($possible)), 1);
    return $str;
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


//
// Hashes a password and returns the hash based on the specified enc_type.
//
// @param string $password_clear The password to hash in clear text.
// @param string $enc_type Standard LDAP encryption type which must be one of
//        crypt, ext_des, md5crypt, blowfish, md5, sha, smd5, ssha, or clear.
//
function password_hash ($password_clear, $enc_type) {
    $enc_type = strtolower($enc_type);

    switch ($enc_type) {
        case 'crypt':
            $new_value = '{CRYPT}' . crypt($password_clear, random_salt(2));
            break;

        case 'ext_des':
            // extended des crypt. see OpenBSD crypt man page.
            if (! defined('CRYPT_EXT_DES') || CRYPT_EXT_DES == 0)
                log_('Your system crypt library does not support extended DES encryption.');
            $new_value = '{CRYPT}' . crypt( $password_clear, '_' . random_salt(8) );
            break;

        case 'md5crypt':
            if (! defined('CRYPT_MD5') || CRYPT_MD5 == 0)
                log_error('Your system crypt library does not support md5crypt encryption.');
            $new_value = '{CRYPT}' . crypt( $password_clear , '$1$' . random_salt(9) );
            break;

        case 'blowfish':
            if (! defined('CRYPT_BLOWFISH') || CRYPT_BLOWFISH == 0)
                log_error('Your system crypt library does not support blowfish encryption.');
            // hardcoded to second blowfish version and set number of rounds
            $new_value = '{CRYPT}' . crypt( $password_clear , '$2a$12$' . random_salt(13) );
            break;

        case 'md5':
            $new_value = '{MD5}' . base64_encode(pack('H*' , md5( $password_clear)));
            break;

        case 'sha':
            if (function_exists('sha1')) {
                // use php 4.3.0+ sha1 function, if it is available.
                $new_value = '{SHA}' . base64_encode(pack('H*' , sha1($password_clear)));
            } elseif( function_exists( 'mhash' ) ) {
                $new_value = '{SHA}' . base64_encode(mhash(MHASH_SHA1, $password_clear));
            } else {
                error_page(_T('Your PHP has no mhash(). Cannot do SHA hashes.'));
            }
            break;

        case 'ssha':
            if (function_exists('mhash') && function_exists('mhash_keygen_s2k')) {
                mt_srand( (double) microtime() * 1000000 );
                $salt = mhash_keygen_s2k(MHASH_SHA1, $password_clear, substr(pack("h*", md5(mt_rand())), 0, 8), 4);
                $new_value = "{SSHA}" . base64_encode(mhash(MHASH_SHA1, $password_clear.$salt) . $salt);
            } else {
                error_page(_T('Your PHP has no mhash(). Cannot do SHA hashes.'));
            }
            break;

        case 'smd5':
            if (function_exists('mhash') && function_exists('mhash_keygen_s2k')) {
                mt_srand( (double) microtime() * 1000000 );
                $salt = mhash_keygen_s2k(MHASH_MD5, $password_clear, substr(pack("h*", md5(mt_rand())), 0, 8), 4);
                $new_value = "{SMD5}".base64_encode( mhash( MHASH_MD5, $password_clear.$salt ).$salt );
            } else {
                error_page(_T('Your PHP has no mhash(). Cannot do SHA hashes.'));
            }
            break;

        case 'clear':
        default:
            $new_value = $password_clear;
    }

    return $new_value;
}

//
// Given a clear-text password and a hash, this function determines if the clear-text password
// is the password that was used to generate the hash. This is handy to verify a user's password
// when all that is given is the hash and a "guess".
// @param String $hash The hash.
// @param String $clear The password in clear text to test.
// @return Boolean True if the clear password matches the hash, and false otherwise.
//
function password_check ($cryptedpassword, $plainpassword) {

    if (preg_match("/{([^}]+)}(.*)/", $cryptedpassword, $cypher)) {
        $cryptedpassword = $cypher[2];
        $_cypher = strtolower($cypher[1]);
    } else {
        $_cypher = NULL;
    }

    switch ($_cypher) {
        // SSHA crypted passwords
        case 'ssha':
            // check php mhash support before using it
            if (function_exists('mhash')) {
                $hash = base64_decode($cryptedpassword);
                $salt = substr($hash, -4);
                $new_hash = base64_encode(mhash(MHASH_SHA1, $plainpassword . $salt) . $salt);
                return (strcmp( $cryptedpassword, $new_hash ) == 0);
            } else {
                error_page(_T('Your PHP has no mhash(). Cannot do SHA hashes.'));
            }
            break;

        // Salted MD5
        case 'smd5':
            // check php mhash support before using it
            if (function_exists('mhash')) {
                $hash = base64_decode($cryptedpassword);
                $salt = substr($hash, -4);
                $new_hash = base64_encode( mhash( MHASH_MD5, $plainpassword.$salt).$salt );
                return (strcmp($cryptedpassword, $new_hash) == 0);
            } else {
                error_page(_T('Your PHP has no mhash(). Cannot do SHA hashes.'));
            }
            break;

        // SHA crypted passwords
        case 'sha':
            return (strcasecmp(password_hash($plainpassword, 'sha'), "{SHA}".$cryptedpassword) == 0);
            break;

        // MD5 crypted passwords
        case 'md5':
            return (strcasecmp(password_hash($plainpassword, 'md5'), "{MD5}".$cryptedpassword) == 0);
            break;

        // Crypt passwords
        case 'crypt':
            // Check if it's blowfish crypt
            if (preg_match("/^\\$2+/", $cryptedpassword)) {
                // make sure that web server supports blowfish crypt
                if (! defined('CRYPT_BLOWFISH') || CRYPT_BLOWFISH == 0)
                    log_error('Your system crypt library does not support blowfish encryption.');
                list(,$version,$rounds,$salt_hash) = explode('$',$cryptedpassword);
                return (crypt($plainpassword, '$'. $version . '$' . $rounds . '$' .$salt_hash) == $cryptedpassword);
            }
            // Check if it's an crypted md5
            elseif (strstr( $cryptedpassword, '$1$')) {
                // make sure that web server supports md5 crypt
                if (! defined('CRYPT_MD5') || CRYPT_MD5 == 0)
                    log_error('Your system crypt library does not support md5crypt encryption.');
                list(,$type,$salt,$hash) = explode('$',$cryptedpassword);
                return (crypt($plainpassword, '$1$' . $salt ) == $cryptedpassword);
            }
            // Check if it's extended des crypt
            elseif (strstr( $cryptedpassword, '_' ) ) {
                // make sure that web server supports ext_des
                if (! defined( 'CRYPT_EXT_DES' ) || CRYPT_EXT_DES == 0)
                    log_error('Your system crypt library does not support extended DES encryption.');
                return (crypt($plainpassword, $cryptedpassword) == $cryptedpassword);
            } else {
                // Password is plain crypt
                return (crypt($plainpassword, $cryptedpassword) == $cryptedpassword);
            }
            break;

        // No crypt is given assume plaintext passwords are used
        default:
            return ($plainpassword == $cryptedpassword);
            break;
    }
}


//
// Detects password encryption type
//
// Returns crypto string listed in braces. If it is 'crypt' password,
// returns crypto detected in password hash. Function should detect
// md5crypt, blowfish and extended DES crypt. If function fails to detect
// encryption type, it returns NULL.
// @param string hashed password
// @return string
//
function get_enc_type($user_password) {
    // Capture the stuff in the { } to determine if this is crypt, md5, etc.
    $enc_type = null;

    if (preg_match("/{([^}]+)}/", $user_password, $enc_type))
        $enc_type = strtolower( $enc_type[1] );
    else
        return null;

    // handle crypt types
    if (strcasecmp( $enc_type, 'crypt') == 0) {
        if (preg_match("/{[^}]+}\\$1\\$+/", $user_password)) {
            $enc_type = "md5crypt";
        } elseif (preg_match("/{[^}]+}\\$2+/", $user_password)) {
            $enc_type = "blowfish";
        } elseif (preg_match("/{[^}]+}_+/", $user_password)) {
            $enc_type = "ext_des";
        }
        // No need to check for standard crypt,
        // because enc_type is already equal to 'crypt'.
    }
    return $enc_type;
}


//
// Returns the current time as a double (including micro-seconds) since the Unix epoch.
//
function utime () {
    $time = explode(' ',microtime());
    $usec = (double)$time[0];
    $sec = (double)$time[1];
    return $sec + $usec;
}


//
// Encryption using blowfish algorithm
//
// @param   string  original data
// @param   string  the secret
//
// @return  string  the encrypted result
//
// @author  lem9 (taken from the phpMyAdmin source)
//
function blowfish_encrypt ($data, $secret = null) {
    // If our secret is null or blank, get the default.
    if ($secret === null || ! trim($secret))
        $secret = get_config('session_blowfish');

    // If the secret isnt set, then just return the data.
    if (! trim($secret))  return $data;

    require_once LIBDIR.'blowfish.php';

    $pma_cipher = new Horde_Cipher_blowfish;
    $encrypt = '';

    for ($i = 0; $i < strlen($data); $i += 8) {
        $block = substr($data, $i, 8);
        if (strlen($block) < 8)
            $block = full_str_pad($block,8,"\0", 1);
        $encrypt .= $pma_cipher->encryptBlock($block, $secret);
    }
    return base64_encode($encrypt);
}


//
// Decryption using blowfish algorithm
//
// @param   string  encrypted data
// @param   string  the secret
//
// @return  string  original data
//
// @author  lem9 (taken from the phpMyAdmin source)
//
function blowfish_decrypt ($encdata, $secret = null) {
    // This cache gives major speed up for stupid callers :)
    static $cache = array();

    if (isset($cache[$encdata]))  return $cache[$encdata];

    // If our secret is null or blank, get the default.
    if ($secret === null || ! trim($secret))
        $secret = get_config('session_blowfish');

    // If the secret isnt set, then just return the data.
    if (! trim($secret))  return $encdata;

    require_once LIBDIR . 'blowfish.php';

    $pma_cipher = new Horde_Cipher_blowfish;
    $decrypt = '';
    $data = base64_decode($encdata);

    for ($i = 0; $i < strlen($data); $i += 8)
        $decrypt .= $pma_cipher->decryptBlock(substr($data, $i, 8), $secret);

    $cache[$encdata] = $return = trim($decrypt)
    return $return;
}


function binSIDtoText($binsid) {
    $hex_sid = bin2hex($binsid);
    $rev = hexdec(substr($hex_sid,0,2)); // Get revision-part of SID
    $subcount = hexdec(substr($hex_sid,2,2)); // Get count of sub-auth entries
    $auth = hexdec(substr($hex_sid,4,12)); // SECURITY_NT_AUTHORITY

    $result = "$rev-$auth";

    for ($x = 0; $x < $subcount; $x++) {
        $subauth[$x] = hexdec(littleEndian(substr($hex_sid,16+($x*8),8))); // get all SECURITY_NT_AUTHORITY
        $result .= "-".$subauth[$x];
    }

    return $result;
}


//
// This function returns a string automatically generated
// based on the criteria defined in the array $criteria in config.php
//
function password_generate () {
    $no_use_similiar = ! str2bool(get_config('password_use_similar'));
    $lowercase = str2bool(get_config('password_lowercase'));
    $uppercase = str2bool(get_config('password_uppercase'));
    $digits = str2bool(get_config('password_numbers'));
    $punctuation = get_config('password_punctuation');
    $length = get_config('password_length');

    $outarray = array();

    if ($no_use_similiar) {
        $raw_lower = "a b c d e f g h k m n p q r s t u v w x y z";
        $raw_numbers = "2 3 4 5 6 7 8 9";
        $raw_punc = "# $ % ^ & * ( ) _ - + = . , [ ] { } :";
    } else {
        $raw_lower = "a b c d e f g h i j k l m n o p q r s t u v w x y z";
        $raw_numbers = "1 2 3 4 5 6 7 8 9 0";
        $raw_punc = "# $ % ^ & * ( ) _ - + = . , [ ] { } : |";
    }

    $llower = explode(" ", $raw_lower);
    shuffle($llower);
    $lupper = explode(" ", strtoupper($raw_lower));
    shuffle($lupper);
    $numbers = explode(" ", $raw_numbers);
    shuffle($numbers);
    $punc = explode(" ", $raw_punc);
    shuffle($punc);

    if ($lowercase > 0)
        $outarray = array_merge($outarray, a_array_rand($llower, $lowercase));

    if ($uppercase > 0)
        $outarray = array_merge($outarray, a_array_rand($lupper, $uppercase));

    if ($digits > 0)
        $outarray = array_merge($outarray, a_array_rand($numbers, $digits));

    if ($punctuation > 0)
        $outarray = array_merge($outarray, a_array_rand($punc, $punctuation));

    $num_spec = $lowercase + $uppercase + $digits + $punctuation;

    if ($num_spec < $length) {
        $leftover = array();
        if ($lowercase > 0)
            $leftover = array_merge($leftover, $llower);
        if ($uppercase > 0)
            $leftover = array_merge($leftover, $lupper);
        if ($digits > 0)
            $leftover = array_merge($leftover, $numbers);
        if ($punctuation > 0)
            $leftover = array_merge($leftover, $punc);

        if (count($leftover) == 0)
            $leftover = array_merge($leftover,$llower,$lupper,$numbers,$punc);

        shuffle($leftover);
        $outarray = array_merge($outarray, a_array_rand($leftover, $criteria['num'] - $num_spec));
    }

    shuffle($outarray);
    return implode('', $outarray);
}

?>
