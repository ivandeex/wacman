// $Id$

/////////////////////////////////////////////////////////
// users
//

var user_obj = {
    name: 'user',
    title: ' Users ',

    list_url: 'user-list.php',
    read_url: 'user-read.php',
    write_url: 'user-write.php',
    id_attr: 'uid',

    do_add: function () {
    },

    do_delete: function () {
    },

    do_refresh: function () {
        this.store.reload();
    },

    do_save: function () {
        obj_submit(this);
    },

    do_revert: function () {
    },

    do_change: function (sm) {
    },

    do_load: function (sm, row_idx, rec) {
        obj_load(this, rec);
    },

    do_unselect: function () {
    },

    do_entry: function (entry, ev) {
        var val = trim(entry.getValue());
        if (val == entry._attr.val)
            return;
        var obj = entry._attr.obj;
        obj_setup(obj);
        set_attr(obj, entry._attr.desc.name, val);
        user_rework(obj);
        update_obj_gui(obj);
        Ext.getCmp('user_panel').setTitle(
                get_attr(obj, 'uid') + ' (' + get_attr(obj, 'cn') + ') ...');
    }
};

/////////////////////////////////////////////////////////
// groups
//

var group_obj = {
    name: 'group',
    title: ' Groups ',

    list_url: 'group-list.php',
    read_url: 'group-read.php',
    write_url: 'group-write.php',
    id_attr: 'cn',

    do_add: function () {
    },

    do_delete: function () {
    },

    do_refresh: function () {
        this.store.reload();
    },

    do_save: function () {
    },

    do_revert: function () {
    },

    do_change: function (sm) {
    },

    do_load: function (sm, row_idx, rec) {
        obj_load(this, rec);
    },

    do_unselect: function () {
    },

    do_entry: function (entry, ev) {
        var val = trim(entry.getValue());
        if (val == entry._attr.val)
            return;
        var obj = entry._attr.obj;
        obj_setup(obj);
        set_attr(obj, entry._attr.desc.name, val);
        group_rework(obj);
        update_obj_gui(obj);
        Ext.getCmp('group_panel').setTitle(get_attr(obj, 'cn') + ' ...');
    }
};

/////////////////////////////////////////////////////////
// mailgroups
//

var mailgroup_obj = {
    name: 'mailgroup',
    title: ' Mail groups ',

    list_url: 'mailgroup-list.php',
    read_url: 'mailgroup-read.php',
    write_url: 'mailgroup-write.php',
    id_attr: 'uid',

    do_add: function () {
    },

    do_delete: function () {
    },

    do_refresh: function () {
        this.store.reload();
    },

    do_save: function () {
    },

    do_revert: function () {
    },

    do_change: function (sm) {
    },

    do_load: function (sm, row_idx, rec) {
        obj_load(this, rec);
    },

    do_unselect: function () {
    },

    do_entry: function (entry, ev) {
        var val = trim(entry.getValue());
        if (val == entry._attr.val)
            return;
        var obj = entry._attr.obj;
        obj_setup(obj);
        set_attr(obj, entry._attr.desc.name, val);
        mailgroup_rework(obj);
        update_obj_gui(obj);
        Ext.getCmp('mailgroup_panel').setTitle(get_attr(obj, 'uid') + ' ...');
    }
};

/////////////////////////////////////////////////////////
// Rework
//

function get_attr(obj, name) {
    if (!(name in obj.attr)) {
        debug_log('%s: undefined attribute in get_attr()', name);
        return '';
    }
    return trim(obj.attr[name].val);
}

function cond_set(obj, name, val) {
    if (!(name in obj.attr)) {
        debug_log('%s: undefined attribute in cond_set()', name);
        return false;
    }
    at = obj.attr[name];
    if (at.desc.disable || has_attr(obj, name))
        return false;
    set_attr(obj, name, val);
    return true;
}

function set_attr(obj, name, val) {
    if (!(name in obj.attr)) {
        debug_log('%s: undefined attribute in set_attr()', name);
        return;
    }
    val = trim(val);
    var at = obj.attr[name];
    if (at.desc.disable)
        return;
    at.val = val;
    if (val == '')
        at.state = 'empty';
    else if (val == at.old)
        at.state = 'orig';
    else if (('entry' in at) && (val == at.entry.getValue()))
        at.state = 'user';
    else
        at.state = 'calc';
    if (val == '')
        at.requested = false;
}

function has_attr(obj, name) {
    if (!(name in obj.attr)) {
        debug_log('%s: undefined attribute in has_attr()', name);
        return false;
    }
    switch (obj.attr[name].state) {
        case 'force':
        case 'empty':
        case 'calc':
            return false;
        case 'user':
        case 'orig':
            return true;
        default:
            return trim(obj.attr[name].val) != '';
    }
}

function trim(s) {
    s = (s == undefined ? '' : '' + s);
    return s.replace(/^\s\s*/, '').replace(/\s\s*$/, '');
}

function str_translate(s, from, to) {
    var sl = s.length;
    var tl = to.length;
    var xlat = [];
    if (sl<1 || tl<1) return s;
    var i;
    for (i = 0; i < 256; i++)  xlat[i] = i;
    for (i = 0; i < tl; i++)  xlat[ from.charCodeAt(i) ] = to.charCodeAt(i);
    var r = '';
    for (i = 0; i < sl; i++)
        r += String.fromCharCode( xlat[ s.charCodeAt(i) ] );
    return r.replace(/_+/g, '_');
}

function str2bool(s) {
    if (s == undefined || s == null)
        return false;
    s = trim(s);
    if (s.length < 1)
        return false;
    return ("yto1".indexOf(s.charAt(0).toLowerCase()) >= 0);
}

function bool2str(v) {
    return str2bool(v) ? 'Yes' : 'No';
}

function string2id(s) {
    var max_id_len = 16;

    // initialize conversion tables
    if (! string2id.rus2lat) {
        // russian to latin
        string2id.rus2lat = [];
        var rus_b = "\u0410\u0411\u0412\u0413\u0414\u0415\u0416\u0417\u0418\u0419\u041a\u041b\u041c\u041d\u041e\u041f\u0420\u0421\u0422\u0423\u0424\u0425\u0426\u0427\u0428\u0429\u042a\u042b\u042c\u042d\u042e\u042f";
        var lat_b = "ABVGDEWZIJKLMNOPRSTUFHC4WWXYXEUQ";
        var rus_s = "\u0430\u0431\u0432\u0433\u0434\u0435\u0436\u0437\u0438\u0439\u043a\u043b\u043c\u043d\u043e\u043f\u0440\u0441\u0442\u0443\u0444\u0445\u0446\u0447\u0448\u0449\u044a\u044b\u044c\u044d\u044e\u044f";
        var lat_s = "abvgdewzijklmnoprstufhc4wwxyxeuq";
        var i;
        for (i = 0; i < 0x450 - 0x400; i++)
            string2id.rus2lat[i] = i;
        for (i = 0; i < rus_b.length; i++)
            string2id.rus2lat[rus_b.charCodeAt(i) - 0x400] = lat_b.charCodeAt(i);
        for (i = 0; i < rus_s.length; i++)
            string2id.rus2lat[rus_s.charCodeAt(i) - 0x400] = lat_s.charCodeAt(i);            

        // convert uppercase to lowercase latin, leave only latin and digits
        string2id.char2id = [];
        for (i = 0; i < 256; i++) {
            if (i >= '0'.charCodeAt(0) && i <= '9'.charCodeAt(0))
                string2id.char2id[i] = i;
            else if (i >= 'a'.charCodeAt(0) && i <= 'z'.charCodeAt(0))
                string2id.char2id[i] = i;
            else if (i >= 'A'.charCodeAt(0) && i <= 'Z'.charCodeAt(0))
                string2id.char2id[i] = i + 'a'.charCodeAt(0) - 'A'.charCodeAt(0);
            else
                string2id.char2id[i] = '_'.charCodeAt(0);
        }
    }

    s = trim(s);
    var n = s.length;
    if (n > max_id_len)
        n = max_id_len;

    var r = '';
    for (var i = 0; i < n; i++) {
        var c = s.charCodeAt(i);
        c = (c >= 0x400 && c < 0x450) ? string2id.rus2lat[c - 0x400] : c;
        c = (c > 0 && c < 256) ? string2id.char2id[c] : '_';
        r += String.fromCharCode(c);
    }
	return r;
}

function get_obj_config (obj, what, override) {
    var dn = trim(what in config ? config[what] : '');
    var name;
	while ((name = dn.match(/\$\((\w+)\)/)) != null) {
		name = name[0];
		var val = '';
		if (override != undefined && (name in override))
		    val = trim(override[name]);
		if (val == '')
		    val = get_attr(obj, name);
		if (val == '') {
			dn = '';
			break;
		}
		dn = dn.replace(/\$\((\w+)\)/, val);
	}
	return dn;
}

function obj_setup (obj) {
    if (obj.form_is_setup)
        return;
    for (var name in obj.attr) {
        var attr = obj.attr[name];
        if (attr.desc.disable)
            continue;
        if (!('entry' in attr) || attr.entry == null)
            attr.entry = Ext.getCmp(attr.id);
        attr.val = trim(attr.entry.getValue());
    }
    obj.form = Ext.getCmp(obj.name + '_form');
    obj.form_is_setup = true;
}

function obj_load (obj, rec) {
    obj_setup(obj);
    var url = obj.read_url + '?' + obj.id_attr + '=' + rec.get(obj.id_attr);
    var form = obj.form;
    form.load({
        url: url,
        waitMsg: _T('Loading...')
    });
}

function obj_submit (obj) {
    obj_setup(obj);
    var form = obj.form;
    form.submit({});
}

function update_obj_gui (obj, only) {
    for (var name in obj.attr) {
        var attr = obj.attr[name];
        if (! attr.desc.disable && ('entry' in attr) && (!only || name == only)) {
            if (attr.val != trim(attr.entry.getValue()))
                attr.entry.setValue(attr.val);
        }
    }
}

function obj_fill_defs (obj) {
    for (var name in obj.attr) {
        var desc = obj.attr[name].desc;
        if ('defval' in desc)
            cond_set(obj, name, desc.defval);
        if (('copyfrom' in desc) && has_attr(obj, desc.copyfrom))
            cond_set(obj, name, get_attr(obj, desc.copyfrom));
    }
}

function request_next_id (which, obj, name, format) {
    if (has_attr(obj, name))
        return;
    var at = obj.attr[name];
    if (at.requested && at.val != '')
        return;
    at.requested = true;
    debug_log('request_id(%s,%s,%s) in progress (state=%s)', which, obj.name, name, obj.attr[name].state);
    Ext.Ajax.request({
        url: 'next-id.php?which=' + which,
        success: function (resp, opts) {
            var id = trim(resp.responseText);
            id = id.replace(/[^0-9]/g, '');
            if (format)
                id = format(id);
            if (cond_set(obj, name, id))
                update_obj_gui(obj, name);
            debug_log('request_id(%s,%s,%s) returns "%s"', which, obj.name, name, id);
        },
        failure: function (resp, opts) {
            debug_log('request_id(%s,%s,%s) failed', which, obj.name, name);
        }
    });
}

function format_telnum (telnum) {
    telnum = trim(telnum).replace(/[^0-9]/g, '');
    var len = config.telnum_len;
    if (telnum.length < len) {
        while (telnum.length < len)
            telnum = '0' + telnum;
        return telnum;
    }
    if (telnum.length > len)
        telnum = telnum.substr(telnum.length - len, len);
    return telnum;
}

function user_rework (usr) {
    var uid = get_attr(usr, 'uid');
    var cn = get_attr(usr, 'cn');
    var gn = get_attr(usr, 'givenName');
    var sn = get_attr(usr, 'sn');

    // ############# POSIX ############

    // name
    if (! has_attr(usr, 'cn'))
        cond_set(usr, 'cn', (cn = gn + (sn && gn ? ' ' : '') + sn));

    // identifier
    if (! has_attr(usr, 'uid'))
        uid = sn == '' ? gn : gn.substr(0, 1) + sn;
    set_attr(usr, 'uid', (uid = string2id(uid)));

    //#set_attr(usr, 'objectClass', append_list(get_attr(usr, 'objectClass'), config.unix_user_classes));

    cond_set(usr, 'dn', get_obj_config(usr, 'unix_user_dn'));
    cond_set(usr, 'ntDn', get_obj_config(usr, 'ad_user_dn'));
    cond_set(usr, 'cgpDn', get_obj_config(usr, 'cgp_user_dn'));

    // assign next available UID number
    if (has_attr(usr, 'uidNumber')) {
        var uidn = get_attr(usr, 'uidNumber');
        uidn = uidn.replace(/[^0-9]/g, '');
        set_attr(usr, 'uidNumber', uidn);
    }
    request_next_id('unix_uidn', usr, 'uidNumber');

    // mail
    if (uid != '')
        cond_set(usr, 'mail', uid + '@' + config.mail_domain);

    // home directory
    if (uid != '')
        cond_set(usr, 'homeDirectory', config.home_root + '/' + uid);

    // ############# Active Directory ############

    //#set_attr($usr, 'ntObjectClass', append_list(get_attr($usr, 'ntObjectClass'), config.ad_user_classes));

    //#cond_set($usr, 'objectCategory', config.ad_user_category+','+path2dn(config.ad_domain));

    cond_set(usr, 'userPrincipalName', uid+'@'+config.ad_domain);

    //#var pass = get_attr(usr, 'password');
    //#if (pass == config.OLD_PASS) {
    //#    set_attr($usr, 'userAccountControl', get_attr($usr, 'userAccountControl', orig => 1));
    //#} else {
    //#    my $uac = get_attr($usr, 'userAccountControl');
    //#    $uac = ADS_UF_NORMAL_ACCOUNT unless $uac;
    //#    $uac &= ~(ADS_UF_PASSWD_NOT_REQUIRED | ADS_UF_DONT_EXPIRE_PASSWD);
    //#    $uac |= $pass eq '' ? ADS_UF_PASSWD_NOT_REQUIRED : ADS_UF_DONT_EXPIRE_PASSWD;
    //#    set_attr($usr, 'userAccountControl', $uac);
    //#}

    // ######## CommuniGate Pro ########
    //set_attr(usr, 'cgpObjectClass', append_list(get_attr($usr, 'cgpObjectClass'), config.cgp_user_classes));

    var telnum = get_attr(usr, 'telnum');
    set_attr(usr, 'telnum', format_telnum(telnum));
    request_next_id('cgp_telnum', usr, 'telnum', format_telnum);

    set_attr(usr, 'domainIntercept', bool2str(get_attr(usr, 'domainIntercept')) );
    set_attr(usr, 'userIntercept', bool2str(get_attr(usr, 'userIntercept')) );

    // ###### constant and copy-from fields ########
    obj_fill_defs(usr);
}

function group_rework (grp) {
    set_attr(grp, 'objectClass', config.unix_group_classes);

    var val;
    val = get_attr(grp, 'cn');
    set_attr(grp, 'cn', string2id(val));

    set_attr(grp, 'gidNumber', get_attr(grp, 'gidNumber').replace(/[^0-9]/g, ''));
    request_next_id('unix_gidn', grp, 'gidNumber');

    set_attr(grp, 'dn', get_obj_config(grp, 'unix_group_dn'));
}

function mailgroup_rework (mgrp) {
    set_attr(mgrp, 'uid', string2id(get_attr(mgrp, 'uid')));
    set_attr(mgrp, 'dn', get_obj_config(mgrp, 'cgp_user_dn'));
    cond_set(mgrp, 'cn', get_attr(mgrp, 'uid'));

    // ###### constant (& not copyfrom) fields ########
    obj_fill_defs(mgrp);
}

/////////////////////////////////////////////////////////
// Custom fields
//

Ext.form.FillerField = Ext.extend(Ext.form.TextField, {
});
Ext.reg('fillerfield', Ext.form.FillerField);

popup_functions = {
    yesno: 'create_yesno_chooser',
    gid: 'create_group_chooser',
    groups: 'create_user_groups_editor',
    users: 'create_group_users_editor',
    mgroups: 'create_user_mail_groups_editor',
    mailusers: 'create_mailgroup_users_editor'
};

Ext.form.PopupField = Ext.extend(Ext.form.TriggerField, {
    onTriggerClick: function() {
        if (this._attr.desc.popup in popup_functions) {
            func = popup_functions[this._attr.desc.popup];
            Ext.Msg.alert('popup', func);
        }
    }
});
Ext.reg('popupfield', Ext.form.PopupField);

/////////////////////////////////////////////////////////
// Messages and logging
//

function _T() {
	var args = arguments;
	var msg = (args[0] in translations) ? translations[args[0]] : args[0];
	for (i = 1; i < args.length; i++)
	    msg = msg.replace('%s', args[i]);
	return msg;
};

function debug_log() {
    if (!('debug' in config) || !str2bool(config.debug))
        return;
    if ((typeof console === 'undefined') || console == null)
        return;
	var args = arguments;
	var msg = args[0];
	for (i = 1; i < args.length; i++)
	    msg = msg.replace('%s', args[i]);
    console.log(msg);
}

/////////////////////////////////////////////////////////
// AJAX indicator
//

AjaxIndicator = Ext.extend(Ext.Button, {
    disabled: true,
    scale: 'medium',
    ajax_urls : null,

    initComponent : function() {
        this.ajax_urls = [];
        Ext.Ajax.on('beforerequest', function(c,o) { this.addReq(c,o); }, this);
        Ext.Ajax.on('requestcomplete', function(c,r,o) { this.remReq(c,r,o); }, this);
        Ext.Ajax.on('requestexception', function(c,r,o) { this.remReq(c,r,o); }, this);
        this.hideProgress();
        log_debug('%s: init', this.idid);
    },

    addReq: function (conn, o) {
        if (this.ajax_urls.indexOf(o.url) < 0) {
            this.ajax_urls.push(o.url);
            this.showProgress();
        }
    },

    remReq: function (conn, resp, o) {
        this.ajax_urls.remove(o.url);
        if (this.ajax_urls.length <= 0)
            this.hideProgress();
    },

    showProgress: function() {
        this.setIcon('images/throbber-24.gif');
    },

    hideProgress: function() {
        this.setIcon('images/userman-32.png');
    },
});

/////////////////////////////////////////////////////////
// GUI
//

function btn_id (obj, op) {
    return 'btn_' + obj.name + '_' + op;
}

function create_obj_tab (obj) {

    var col_gap = 2;
    var label_width = 150;
    var right_gap = 20;

    obj.attr = {};
    obj.form_is_setup = false;
    obj.changed = false;
    obj.enabled = false;

    var form_attrs = gui_attrs[obj.name];
    if (! form_attrs)
        return null;

    var obj_attrs = [];
    for (var name in all_attrs[obj.name])
        obj_attrs.push(name);
    obj.rec = Ext.data.Record.create(obj_attrs);

    obj.store = new Ext.data.Store({
        url: obj.list_url,
        autoLoad: true,
        reader: new Ext.data.JsonReader({
            root: 'rows',
            idProperty: obj.id_attr
        }, obj.rec)
    });

    var desc_tabs = [];
    var list_cols = [];
    var list_width = col_gap;

    for (var i = 0; i < form_attrs.length; i++) {

        var tab_name = form_attrs[i][0];
        var tab_attrs = form_attrs[i][1];
        var entries = [];

        for (var j = 0; j < tab_attrs.length; j++) {

            var attr_name = tab_attrs[j];
            var desc = all_attrs[obj.name][attr_name];
            if (!desc) {
                Ext.Msg.alert(_T('attribute "%s" in object "%s" not defined', attr_name, obj.name));
                continue;
            }

            attr = {
                val: '',
                old: '',
                state: 'empty',
                obj: obj,
                desc: desc,
                requested: false,
                id: 'field_' + obj.name + '_' + attr_name
            };
            obj.attr[desc.name] = attr;
            if (desc.disable)
                continue;

            if ('colwidth' in desc) {
                list_width += desc.colwidth + col_gap;
                list_cols.push({
                    header: _T(desc.label),
                    dataIndex: attr_name,
                    sortable: true,
                    width: desc.colwidth,
                });
            }

            var entry = {
                xtype: desc.popup ? 'popupfield' : 'fillerfield',
                name: desc.name,
                fieldLabel: _T(desc.label),
                readonly: desc.readonly,
                anchor: '-' + right_gap,
                listeners: { valid: obj.do_entry },
                id: attr.id,
                _attr: attr,
            };

            if (desc.type == 'pass' && !config.show_password)
                entry.inputType = 'password';

            entries.push(entry);
        }

        if (entries.length) {
            desc_tabs.push({
                title: _T(tab_name),
                layout: 'form',
                autoScroll: true,
                //autoHeight: true,
                bodyStyle: 'padding: 10px',
                labelWidth: label_width,
                labelSeparator: '',
                items: entries
            });
        }
	}

    if (! desc_tabs.length)
        return null;

    var form_btn_prefix = '';// + _T(obj.title) + ': ';

    var desc_form = {
        region: 'center',
        margins: '0 0 0 0',
        layout: 'fit',

        xtype: 'form',
        url: obj.write_url,
        border: false,
        id: obj.name + '_form',

        reader: new Ext.data.JsonReader({
            root: 'obj',
            idProperty: obj.id_attr
        }, obj.rec),

        items: [{
            xtype: 'tabpanel',
            activeItem: 0,
            items: desc_tabs
        }],

        bbar: [ '->', {
            text: form_btn_prefix + _T('Save'),
            icon: 'images/apply.png',
            scale: 'medium',
            ctCls: config.add_button_css,
            handler: function() { obj.do_save() },
            id: btn_id(obj, 'save')
        },{
            text: form_btn_prefix + _T('Revert'),
            icon: 'images/revert.png',
            scale: 'medium',
            ctCls: config.add_button_css,
            handler: function() { obj.do_revert(); },
            id: btn_id(obj, 'revert')
        },
        ' ' ]
    };

    var desc_panel = {
        region: 'center',
        title: '...',
        layout: 'fit',
        id: obj.name + '_panel',
        items: [ desc_form ]
    };

    var list_panel = {
        xtype: 'grid',
        store: obj.store,
        title: _T(obj.title),
        id: obj.name + '_list',

        colModel: new Ext.grid.ColumnModel({
            columns: list_cols
        }),

        selModel: new Ext.grid.RowSelectionModel({
            singleSelect: true,
            listeners: {
                rowdeselect: function(sm) { obj.do_change(sm); },
                rowselect: function(sm, row, rec) { obj.do_load(sm, row, rec); }
            }
        }),

        region: 'west',
        split: true,
        collapsible: true,
        //collapseMode: 'mini',
        width: list_width,
        minSize: 50
    };

    var obj_btn_prefix = '';// + _T(obj.title) + ': ';

    var obj_buttons = [ ' ', {
            text: obj_btn_prefix  + _T('Create'),
            icon: 'images/add.png',
            scale: 'medium',
            ctCls: config.add_button_css,
            handler: function() { obj.do_add(); },
            id: btn_id(obj, 'add')
        },{
            text: obj_btn_prefix  + _T('Delete'),
            icon: 'images/delete.png',
            scale: 'medium',
            ctCls: config.add_button_css,
            handler: function() { obj.do_delete(); },
            id: btn_id(obj, 'delete')
        },{
            text: obj_btn_prefix  + _T('Refresh'),
            icon: 'images/refresh.png',
            scale: 'medium',
            ctCls: config.add_button_css,
            handler: function() { obj.do_refresh(); },
            id: btn_id(obj, 'refresh')
        },
        '->', new AjaxIndicator()
        ];

    var obj_tab = {
        title: _T(obj.title),
        layout: 'border',
        items: [ list_panel, desc_panel ],
        bbar: {
            xtype: 'toolbar',
            items: obj_buttons
        }
    };

    obj.enabled = true;
    return obj_tab;
}

/////////////////////////////////////////////////////////
// Main
//

function main() {
    hide_preloader();

    Ext.QuickTips.init();

    var objs = [ user_obj, group_obj, mailgroup_obj ];
    var tabs = [];
    objs.forEach(function(obj) {
        var tab = create_obj_tab(obj);
        if (tab != null)
            tabs.push(tab);
    });

    new Ext.Viewport({
        defaults: {
            bodyStyle: 'padding: 5px;',
        },
        layout: 'border',
        id: 'viewport',
        items: [{
            xtype: 'tabpanel',
            region: 'center',
            activeTab: 0,
            items: tabs
        }]
    });

    objs.forEach(function(obj) { if (obj.enabled) obj.do_unselect(); });

    //Ext.util.Observable.capture(Ext.getCmp('field_user_sn'), console.info);
};

/////////////////////////////////////////////////////////
// preloader
//

function hide_preloader() {
    var pre_mask = Ext.get('preloading-mask');
    var pre_box = Ext.get('preloading-box');
    //	Hide loading message			
    pre_box.fadeOut({ duration: 0.2, remove: true });
    //	Hide loading mask
    pre_mask.setOpacity(0.9);
    pre_mask.shift({
        xy: pre_box.getXY(),
        width: pre_box.getWidth(),
        height: pre_box.getHeight(),
        remove: true,
        duration: 0.7,
        opacity: 0.1,
        easing: 'bounceOut'
    });
}

Ext.onReady(main);

