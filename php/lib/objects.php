<?php
// $Id$

// Attribute helpers


function setup_all_attrs () {

    global $all_attrs;
    global $gui_attrs;
    global $data_accessors;
    global $data_converters;
    global $servers;
    global $config;

    foreach ($all_attrs as $objtype => &$descs) {

        foreach ($servers as $srv => &$cfg) {
            $cfg['attrhash'] = array();
            $cfg['attrhash'][$objtype] = array();
        }

        foreach ($descs as $name => &$desc) {

            if ($name == '_accessors')
                continue;   // it's an accessor descriptor
            // others are attribute descriptors

            $desc['name'] = $name;
            $desc['visual'] = false;
            if (empty($desc['type']))
                $desc['type'] = 'string';
            if (isset($desc['label']))
			    $desc['label'] = _T($desc['label']);
            if (! isset($desc['readonly']))
                $desc['readonly'] = false;
            if (! isset($desc['verify']))
                $desc['verify'] = false;
            if (! isset($desc['colwidth']))
                $desc['colwidth'] = null;

            if (! isset($desc['popup']))
			    $desc['popup'] = null;
            if (! isset($desc['checkbox']))
			    $desc['checkbox'] = false;
            if ($desc['checkbox'])
                $desc['popup'] = 'yesno';
			
            if (! isset($desc['defval'])) {
                $cfg_def = "default_value_${objtype}_${name}";
                $desc['defval'] = isset($config[$cfg_def]) ? $config[$cfg_def] : null;
            }

            if (! isset($desc['conv']))
                $desc['conv'] = 'none';

            foreach (array(0,1) as $dir) {
                $sub = isset($data_converters[$desc['conv']]) ? $data_converters[$desc['conv']][$dir] : null;
                if (empty($sub))  $sub = 'conv_none';
                $desc[$dir ? 'disp2attr' : 'attr2disp'] = $sub;
            }

            if (isset($desc['copyfrom']) && !isset($descs[$desc['copyfrom']]))
                log_error('%s attribute "%s" is copy-from unknown "%s"',
                            $objtype, $name, $desc['copyfrom']);
            if (! isset($desc['copyfrom']))
                $desc['copyfrom'] = null;

            if (! isset($desc['disable']))
			    $desc['disable'] = false;

            $ldap = isset($desc['ldap']) ? $desc['ldap'] : '';
            if (! is_array($ldap)) {
                $arr = split_list($ldap);
                $ldap = array();
                foreach ($arr as $x)  $ldap[$x] = '';
            }

            foreach (array_keys($ldap) as $srv) {

				// 'ntuser' is a special set of unix attributes
				// they can be either supported as 'uni' or unsupported
				if ($srv == 'ntuser') {
                    if (get_config('ntuser_support', false)) {
                        $ldap[$srv = 'uni'] = $ldap['ntuser'];
                        unset($ldap['ntuser']);
                    } else {
                        unset($ldap['ntuser']);
                        continue;
                    }
                }

                if (! isset($servers[$srv])) {
                    log_error('wrong server "%s" in objtype "%s" descriptor "%s"',
                                print_r($srv, 1), $objtype, $name);
                    continue;
                }

                if (empty($ldap[$srv]))
                    $ldap[$srv] = $name;

                $ldapattr = $ldap[$srv];
				$cfg =& $servers[$srv];
                if (isset($cfg['attrhash'][$objtype][$ldapattr])) {
                    if (! empty($desc['is_duplicate']))
                        log_error('duplicate attribute "%s" as "%s" for server "%s"',
                                    $name, $ldapattr, $srv);
                } else if (empty($ldap['disable'])) {
                    $cfg['attrhash'][$objtype][$ldapattr] = 1;
                }
            }

            $desc['ldap'] = $ldap;
            if (empty($ldap) || ! attribute_enabled($objtype, $name))
                $desc['disable'] = 1;

            if ($desc['disable'])
                $subs = $data_accessors['none'];
            else if (is_array($desc['type']))
                $subs = $desc['type'];
            else
                $subs = $data_accessors[ $desc['type'] ];
            if (!is_array($subs))
                error_page(_T('type "%s" of "%s" attribute "%s" is not supported',
                                $desc['type'], $objtype, $name));
            $desc['ldap_read'] = $subs[0];
            $desc['ldap_write'] = $subs[1];
            $desc['ldap_write_final'] = $subs[2];
        }

        foreach ($servers as $srv => &$cfg) {
            $arr = array_keys($cfg['attrhash'][$objtype]);
            sort($arr);
            $cfg['attrlist'][$objtype] = $arr;
            unset($cfg['attrhash']);
        }
    }

    // mark visual attributes
    foreach ($gui_attrs as $objtype => &$obj_gui) {
        foreach ($obj_gui as &$gui_tab) {
            foreach ($gui_tab[1] as $name) {
                if (isset($all_attrs[$objtype][$name])) {
                    $all_attrs[$objtype][$name]['visual'] = true;
                } else {
                    log_error('cannot mark attribute "%s" in object "%s" as visual',
                                $name, $objtype);
                }
            }
        }
    }
}


////////////////////////////////////////////////////////
//       Objects
//


function & create_obj ($objtype) {
    global $all_attrs;
    global $servers;
    if (! isset($all_attrs[$objtype]))
        log_error('unknown object type "%s"', $objtype);
    $obj = array(
        'type' => $objtype,
        'changed' => 0,
        'attrs' => array(),
        'ldap' => array(),
        'attrlist' => array(),
        '_accessors' => array(),
        );

    foreach ($all_attrs[$objtype] as $name => &$desc) {
        if ($name == '_accessors') {
            // accessor descriptor
            $obj[$name] = $desc;
            continue;
        }
        // others are attribute descriptors
        $obj['attrs'][$name] = array(
            'name'  => $name,
            'type'  => $desc['type'],
            'desc'  => &$desc,
            'ldap'  => array(),
            'val'   => '',
            'dirty' => false,
        );
    }

    foreach (array_keys($servers) as $srv) {
        $obj['attrlist'][$srv] =& $servers[$srv]['attrlist'][$objtype];
        $obj['ldap'][$srv] = array();
    }

    return $obj;
}


//
// Fetch object values from CGP/LDAP server
//
function obj_read (&$obj, $srv, $id) {
    global $servers;

    $obj['idold'] = null;
    $obj['id'] = $id;
    $obj['renamed'] = false;
    $obj['ldap'][$srv] = array();
    $obj['msg'] = '';

    if ($servers[$srv]['disable'])  return null;

    $reader = @$obj['_accessors'][$srv]['read'];
    if (empty($reader))
        error_page(_T('Reader not defined for "%s" on server "%s"', $obj['type'], $srv));

    if (is_array($reader)) {
        // Read the object using LDAP
        $filter = "(";
        if (count($reader) > 1)  $filter .= "&";
        foreach ($reader as $name => $val) {
            if ($val === '$_ID')
                $val = $id;
            else if (is_string($val) && $val[0] == '$')
                $val = get_attr($obj, substr($val, 1));
            $filter .= "({$name}={$val})";
        }
        $filter .= ")";
        $res = uldap_search($srv, $filter, $obj['attrlist'][$srv]);
    }
    else {
        // Read the object using a custom function
        $filter = $reader . "()";
        $res = $reader($obj, $srv, $id);
    }

    $obj['ldap'][$srv] = uldap_pop($res);
    if (empty($res['data'])) {
        log_debug('obj_read(%s) [%s]: failed with "%s"',
                    $srv, $filter, $res['error']);
        $obj['msg'] = $res['error'] ? $res['error'] : 'not found';
    }
    if ($obj['msg'])  error_page($obj['msg']);
    $ldap =& $obj['ldap'][$srv];

    foreach ($obj['attrs'] as $attr_name => &$at) {
        if (! isset($at['desc']['ldap'][$srv])) // attribute exists for this server?
            continue;
        $read_func = $at['desc']['ldap_read'];
        $ldap_name = $at['desc']['ldap'][$srv];
        $val = nvl($read_func($obj, $at, $srv, $ldap, $ldap_name));
        // FIXME: use NULL as a "don't change" mark
        if (!empty($val))  $at['val'] = $val;
    }

    return '';
}


//
// Send object values to LDAP/CGP server
//
function obj_write (&$obj, $srv, $id, $idold) {
    global $servers;

    if ($servers[$srv]['disable'])
        return null;

    $ldap =& $obj['ldap'][$srv];
    $changed = false;
    $msg = null;

    $writer = @$obj['_accessors'][$srv]['write'];
    if (empty($writer))
        error_page(_T('Writer not defined for "%s" on server "%s"', $obj['type'], $srv));

    log_debug('start writing to "%s"...', $srv);

    // CGP will use IDs for writing
    $obj['idold'] = $idold;
    $obj['id'] = $id;
    $obj['renamed'] = false;    // can be set to true by subordinate writes

    foreach ($obj['attrs'] as $attr_name => &$at) {
        if (! isset($at['desc']['ldap'][$srv]))
            continue;
        // If we used call_user_func(), all parameters would be passed by value,
        // and the "renamed" magic would not work.
        // If we used call_user_func_array(), we would need to mark
        // all passed by reference parameters by "&" in the call time array.
        // The variable function used here honors pass by reference
        // in function prototypes (at least in PHP 5.2.16).
        $write_func = $at['desc']['ldap_write'];
        $ldap_name = $at['desc']['ldap'][$srv];
        if ($write_func($obj, $at, $srv, $ldap, $ldap_name, nvl($at['val'])))
            $changed = true;
	}

    if (!$changed && !empty($idold)) {
        // not changed and not creating
        log_debug('nothing to write to "%s"', $srv);		
    } else {
        if ($writer !== 'LDAP') {
            $res = $writer($obj, $srv, $id, $idold, $ldap);
        } else {
            $res = uldap_update($srv, $ldap);
        }
        log_debug('writing to "%s" returns "%s"', $srv, $res['error']);
        // Note: code 82 = `no values to update'
        if ($res['code'] && $res['code'] != 82)
            $msg = $res['error'];
    }

    foreach ($obj['attrs'] as $attr_name => &$at) {
        if (! isset($at['desc']['ldap'][$srv]))
            continue;
        $post_func = $at['desc']['ldap_write_final'];
        $ldap_name = $at['desc']['ldap'][$srv];
        if ($post_func($obj, $at, $srv, $ldap, $ldap_name, nvl($at['val'])))
            $changed = true;
    }

    return $msg;
}


////////////////////////////////////////////////////////
//       Attribute helpers
//


function get_attr (&$obj, $name, $param = array()) {
    if (!isset($obj['attrs'][$name])) {
        log_error('get_attr: attribute "%s" undefined in object "%s"', $name, $obj['type']);
        return '';
    }
    return nvl($obj['attrs'][$name]['val']);
}


function set_attr (&$obj, $name, $val) {
    if (!isset($obj['attrs'][$name]))
        log_error('set_attr: attribute "%s" undefined in object "%s"', $name, $obj['type']);
    else
        $obj['attrs'][$name]['val'] = $val;
}


//
// Update object values from web request
//
function obj_update (&$obj) {
    foreach ($obj['attrs'] as $name => &$at) {
        if (req_exists($name)) {
            $at['val'] = req_param($name);
            $at['dirty'] = true;
        }
    }
}


function obj_json_encode (&$obj) {
    $ret = array();
    foreach ($obj['attrs'] as $name => &$at)  $ret[$name] = $at['val'];
    return json_ok($ret);
}


////////////////////////////////////////////////////////
//       Visualization
//


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


?>
