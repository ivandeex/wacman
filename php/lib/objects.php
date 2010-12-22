<?php
// $Id$

// Attribute helpers


$all_lc_attrs = null;


function attribute_enabled ($objtype, $name) {
    if ($objtype == 'user') {
        if ($name == 'domainIntercept')
            return false;
        if ($name == 'password2' && get_config('show_password'))
            return false;
        if ($name == 'real_uidn' || $name == 'real_gidn') {
            if (! get_config('prefer_nss_ids'))
                return false;
        }
    }
    return true;
}


function setup_all_attrs () {

    global $all_attrs;
    global $servers;
    global $ldap_rw_subs;
    global $convtype2subs;
    global $gui_attrs;
    global $all_lc_attrs;

    $all_lc_attrs = array();

    foreach ($all_attrs as $objtype => &$descs) {

        foreach ($servers as $srv => &$cfg) {
            $cfg['attrhash'] = array();
            $cfg['attrhash'][$objtype] = array();
        }

        $all_lc_attrs[$objtype] = array();

        foreach ($descs as $name => &$desc) {

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
                $sub = null;
                if (isset($convtype2subs[$desc['conv']]));
                    $sub = $convtype2subs[$desc['conv']][$dir];
                if (empty($sub))
                    $sub = 'conv_none';
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

            $subs = $ldap_rw_subs[ $desc['disable'] ? 'none' : $desc['type'] ];
            if (! $subs)
                log_error('type "%s" of "%s" attribute "%s" is not supported',
                            $desc['type'], $objtype, $name);
            $desc['ldap_read'] = $subs[0];
            $desc['ldap_write'] = $subs[1];
            $desc['ldap_write_final'] = $subs[2];

            $all_lc_attrs[$objtype][strtolower($name)] =& $desc;
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
                $all_attrs[$objtype][$name]['visual'] = true;
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
        );

    foreach ($all_attrs[$objtype] as $name => &$desc) {
        $obj['attrs'][$name] = array(
            'name' => $name,
            'type' => $desc['type'],
            'obj' => &$obj,
            'desc' => &$desc,
            'ldap' => array(),
            'val' => ''
        );
    }

    foreach (array_keys($servers) as $srv) {
        $obj['attrlist'][$srv] =& $servers[$srv]['attrlist'][$objtype];
        $obj['ldap'][$srv] = array();
    }

    return $obj;
}


function get_attr (&$obj, $name, $param = array()) {
    if (!isset($obj['attrs'][$name]))
        error_page(_T('attribute "%s" undefined in object "%s"', $name, $obj['type']));
    return nvl($obj['attrs'][$name]['val']);
}


function set_attr (&$obj, $name, $val) {
    if (!isset($obj['attrs'][$name]))
        error_page(_T('attribute "%s" undefined in object "%s"', $name, $obj['type']));
    $obj['attrs'][$name]['val'] = $val;
}


function obj_json_encode (&$obj) {
    $ret = array();
    foreach ($obj['attrs'] as $name => &$at)
        $ret[$name] = $at['val'];
    return "{success:true,obj:" . json_encode($ret) . "}\n";            
}


function obj_read (&$obj, $srv, $filter) {
    global $servers;

    if ($servers[$srv]['disable']) {
        $obj['ldap'][$srv] = array(); # FIXME Net::LDAP::Entry->new;
        return null;
    }

    $res = uldap_search($srv, $filter, $obj['attrlist'][$srv]);
    if ($res['code'] || $res['data']['count'] == 0) {
        $obj['ldap'][$srv] = array(); # FIXME Net::LDAP::Entry->new;
        log_debug('uldap_obj_read(%s) [%s]: failed with code %d error "%s"', $srv, $filter, $res['code'], $res['error']);
        return $res['error'] ? $res['error'] : 'not found';
    }
    $obj['ldap'][$srv] = $res['data'];

    foreach ($obj['attrs'] as $name => &$at) {
        if (isset($at['desc']['ldap'][$srv])) {
            $val = call_user_func ($at['desc']['ldap_read'], $at, $srv,
                                    $obj['ldap'][$srv], $at['desc']['ldap'][$srv]);
            $at['val'] = nvl($val);
        }
    }

    return 0;
}


function obj_write (&$obj, $srv) {
    global $servers;

    if ($servers[$srv]['disable'])
        return null;

    $ldap =& $obj['ldap'][$srv];
    $changed = false;
    $msg = null;

    log_debug('start writing to "%s"...', $srv);

    foreach ($obj['attrs'] as $name => &$at) {
        if (isset($at['desc']['ldap'][$srv])) {
            if (call_user_func ($at['desc']['ldap_write'], $at, $srv, $ldap,
                                $at['desc']['ldap'][$srv], nvl($at['val'])))
                $changed = true;
        }
	}

    if ($changed) {
        $res = uldap_update($srv, $ldap);
        log_debug('writing to "%s" returns code %d', $srv, $res['code']);
        // Note: code 82 = `no values to update'
        if ($res['code'] && $res['code'] != 82)
            $msg = $res['error'];
    } else {
        log_debug('no need to write to "%s"', $srv);		
    }

    foreach ($obj['attrs'] as $name => $at) {
        if (isset($at['desc']['ldap'][$srv])) {
            if (call_user_func ($at['desc']['ldap_write_final'], $at, $srv, $ldap,
                                $at['desc']['ldap'][$srv], nvl($at['val'])))
                $changed = true;
        }
    }

    return $msg;
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
