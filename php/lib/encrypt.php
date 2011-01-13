<?php
// $Id$


//
// Check whether a string looks like an email address (user@example.com).
//
function is_mail_string ($s) {
    return (bool)preg_match("/^[_A-Za-z0-9-]+(\\.[_A-Za-z0-9-]+)*@[A-Za-z0-9-]+(\\.[A-Za-z0-9-]+)*$/", $s);
}


////////////////////////////////////////////////////////
//       Data conversion
//


// See 'conv' in $all_attrs descriptors
$data_converters = array(
    'none'      => array( 'conv_none', 'conv_none' ),
    'bkslash'   => array( 'bkslash_front', 'bkslash_back' ),
    'binary'    => array( 'binary_front', 'binary_back' ),
    'monotime'  => array( 'monotime_front', 'monotime_back' ),
    'decihex'	=> array( 'decihex_front', 'decihex_back' ),
    'adtime'	=> array( 'adjtime_front', 'adjtime_back' )
    );


function conv_none ($x) {
    return $x;
}


function bkslash_front ($x) {
    return preg_replace_callback(
                "!\\([8-9A-F][0-9A-F])!",
                create_function (
                    '$p',
                    'return chr(hexdec($p[1]));'
                ), $x);
}


function bkslash_back ($x) {
    return preg_replace_callback(
                "!([\x80-\xFF])!",
                create_function (
                    '$p',
                    'return sprintf("\\%02X",ord($p[1]));'
			    ), $x);
}


function binary_front ($x) {
    return preg_replace_callback(
                "!([\x80-\xFF])!",
                create_function (
                    '$p',
                    'return sprintf("%02x",ord($p[1]));'
			    ), $x);
}


function binary_back ($x) {
    return preg_replace_callback(
                "!([0-9a-f]{1,2})!",
                create_function (
                    '$p',
                    'return chr(hexdec($p[1]));'
                ), $x);
}


function monotime_front ($x) {
    if (preg_match("!^(\d{4})(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)\.0Z$!", $x, $p))
        return sprintf("%s-%s-%s.%s:%s:%s.000000;0",$p[1],$p[2],$p[3],$p[4],$p[5],$p[6]);
    return $x;
}


function monotime_back ($x) {
    if (preg_match("!^(\d{4})\-(\d\d)\-(\d\d)\;(\d\d)\:(\d\d)\:(\d\d)\.000000\;0$!", $x, $p))
        return $p[1].$p[2].$p[3].$p[4].$p[5].$p[6].".0Z";
}


function decihex_front ($x) {
    return sprintf("0x%04x",$_[0]);
}


function decihex_back ($x) {
    $x = hexdec($x);
    if ($x >= 0x80000000)
        $x = -1 - ~$x;
    return $x;
}


function adjtime_front ($x) {
    if ($x == NO_EXPIRE)
        return -1;
    if ($x == 0)
        return 0;
    $ns100ep = $x;
    if (! preg_match('/(\d{6})\d$/', $ns100ep, $parts))     // FIXME: no math since rounding problems !
        return $x;
    $us = $parts[1];
    $windsec = floor(($ns100ep - $us * 10) / 1e+7 + 0.5);
    $unixsec = $windsec - SECS1610TO1970; 
    list($y,$mo,$d,$h,$mi,$s,$us,$dst) = localtime($unixsec);
    return sprintf("%04d-%02d-%02d;%02d:%02d:%02d.%06d;%d",
                    $y+1900,$mo+1,$d,$h,$mi,$s,$us,$dst);
}


function adjtime_back ($x) {
    if ($x == -1)
        return NO_EXPIRE;
    if (preg_match('/^(\d{4})-(\d\d)-(\d\d);(\d\d):(\d\d):(\d\d)\.(\d{6});(\d)$/', $x, $p)) {
        list($all,$y,$mo,$d,$h,$mi,$s,$us,$dst) = $p;
        $unixsec = mktime($h,$mi,$s,$mo,$d,$y,$dst);
        $windsec = $unixsec + SECS1610TO1970;
        return sprintf("%.0f%06d0", $windsec, $us);
    }
    return $x;
}


////////////////////////////////////////////////////////
//       Encryption
//


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

    $cache[$encdata] = $return = trim($decrypt);
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
