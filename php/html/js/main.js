// $Id$


/////////////////////////////////////////////////////////
// String utilities
//

var MAX_ID_LEN = 16;

function strTrim(s) {
    s = (s == undefined ? '' : '' + s);
    return s.replace(/^\s\s*/, '').replace(/\s\s*$/, '');
}

function strTranslate(s, from, to) {
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
    s = strTrim(s);
    if (s.length < 1)
        return false;
    return ("yto1".indexOf(s.charAt(0).toLowerCase()) >= 0);
}

function bool2str(v) {
    return str2bool(v) ? 'Yes' : 'No';
}

function string2id(s) {
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

    s = strTrim(s);
    var n = s.length;
    if (n > MAX_ID_LEN)
        n = MAX_ID_LEN;

    var r = '';
    for (var i = 0; i < n; i++) {
        var c = s.charCodeAt(i);
        c = (c >= 0x400 && c < 0x450) ? string2id.rus2lat[c - 0x400] : c;
        c = (c > 0 && c < 256) ? string2id.char2id[c] : '_';
        r += String.fromCharCode(c);
    }
	return r;
}

function formatTelnum (telnum) {
    telnum = strTrim(telnum).replace(/[^0-9]/g, '');
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

function _T() {
	var args = arguments;
	var msg = (args[0] in translations) ? translations[args[0]] : args[0];
	for (i = 1; i < args.length; i++)
	    msg = msg.replace('%s', args[i]);
	return msg;
};

function debug() {
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
// Data object
//

// create namespace
Ext.ns('Userman');

var std_lists;

Userman.Object = Ext.extend(Ext.util.Observable, {

    RIGHT_GAP: 20,
    COL_GAP: 2,
    LABEL_WIDTH: 150,
    TAB_PADDING: '10px',
    FORM_TIMEOUT: 10,

    name: undefined,
    list: undefined,
    title: undefined,
    enabled: false,

    list_url: undefined,
    read_url: undefined,
    write_url: undefined,
    delete_url: undefined,
    id_attr: undefined,

    tab_panel: null,
    list_panel: undefined,
    list_store: undefined,

    form_panel: undefined,
    form_tabs: undefined,
    form: undefined,
    obj_attrs: undefined,
    Data: undefined,
    data: undefined,
    changed: false,

    attr: {},
    list_cols: [],
    list_width: 0,

    constructor : function(config){
        Ext.apply(this, config);
        this.attr = {};
        this.list_cols = [];
        this.list_width = this.COL_GAP + 1;
        this.list_store = std_lists[this.list].store;
        this.form_tabs = [];

        this.list_url = this.list_url || this.name + '-list.php';
        this.read_url = this.read_url || this.name + '-read.php';
        this.write_url = this.write_url || this.name + '-write.php';
        this.delete_url = this.delete_url || this.name + '-delete.php';

        // setup visual attributes
        var form_attrs = gui_attrs[this.name] || [];
        for (var i = 0; i < form_attrs.length; i++) {
            var tab_name = form_attrs[i][0];
            var tab_attrs = form_attrs[i][1];
            var fields = [];

            for (var j = 0; j < tab_attrs.length; j++) {
                var at = this.setupField(tab_attrs[j]);
                if (at.field)
                    fields.push(at.field);
            }

            if (fields.length) {
                this.form_tabs.push({
                    title: _T(tab_name),
                    layout: 'form',
                    autoScroll: true,
                    //autoHeight: true,
                    bodyStyle: 'padding: ' + this.TAB_PADDING,
                    labelWidth: this.LABEL_WIDTH,
                    labelSeparator: '',
                    items: fields
                });
            }
	    }

        // setup non-visual attributes
        for (var name in all_attrs[this.name]) {
            if (!(name in this.attr))
                this.setupField(name);
        }

        this.obj_attrs = [];
        for (var name in all_attrs[this.name])
            this.obj_attrs.push(name);
        this.Data = Ext.data.Record.create(this.obj_attrs);
        this.data = new this.Data ();
    },

    onCreate: function () {
        for (var i = 0; i < this.obj_attrs.length; i++)
            this.vset(this.obj_attrs[i], '');
        this.form.loadRecord(this.data);
        this.onUnselect();
    },

    delete: function () {
    },

    refresh: function () {
        this.list_store.reload();
    },

    load: function (sm, row, rec) {
        var params = {};
        params[this.id_attr] = rec.get(this.id_attr);
        var _this = this;
        this.form.load({
            method: 'GET',
            url: this.read_url,
            params: params,
            waitTitle: params[this.id_attr],
            waitMsg: _T('Loading...'),

            success: function (form, action) {
                _this.loadData(action.result.data);
            },

            failure: function (form, action) {
                _this.form.reset();
                Ext.Msg.alert(_T(action.failureType), _T(action.response.statusText));
            }
        });
    },

    save: function () {
        this.form.submit();
        this.markChanged(false);
    },

    onRevert: function () {
        if (!this.changed)
            return;
        var _this = this;
        Ext.Msg.confirm(this.vget(this.id_attr), _T('Really revert changes ?'),
                        function (reply) {
                            if (reply == 'yes') {
                                _this.doRevert();
                            }
                        });
    },

    doRevert: function () {
        this.data.reject();
        this.form.loadRecord(this.data);
        this.markChanged(false);
    },

    onLeave: function (sm, row, rec) {
        return true;
    },

    onUnselect: function () {
        if (this.list_panel.rendered)
            this.list_panel.getSelectionModel().clearSelections();
        // force UI changes
        this.changed = true;
        this.markChanged(false);
    },

    onModified: function (field, ev) {
        var val = strTrim(field.getValue());
        if (val == this.vget(field._attr.name))
            return;
        this.vset(field._attr.name, val);

        this.rework();
        this.fillDefs();
        this.form.loadRecord(this.data);
        this.markChanged(this.data.dirty);
        Ext.getCmp(this.name + '_panel').setTitle(this.formTitle() + ' ...');
    },

    formTitle: function() {
        return '';
    },

    rework: function () {
    },

    loadData: function (data) {
        this.data = new this.Data (data);
        this.markChanged(false);
    },

    markChanged: function (changed) {
        if (changed == this.changed)
            return;
        this.changed = changed;
        var ids1 = [
            this.name + '_list',
            this.btnId('add'),
            this.btnId('delete'),
            this.btnId('refresh')
            ];
        var ids0 = [
            this.btnId('save'),
            this.btnId('revert'),
        ];
        if (changed) {
            // swap two sets
            var tmp = ids1;
            ids1 = ids0;
            ids0 = tmp;
        }
        ids1.forEach(function(id) { Ext.getCmp(id).enable(); });
        ids0.forEach(function(id) { Ext.getCmp(id).disable(); });
    },

    vset: function (name, val) {
        var at = this.attr[name];
        if (at.disable)
            return;
        val = strTrim(val);
        this.data.set(name, val);
        if (val == '') {
            at.requested = false; // re-enable nextSeq() requests
            at.can_set = true; // empty - modifiable
        } else if (!this.data.isModified(name)) {
            at.can_set = false; // original - not modifiable
        } else if (at.field && at.field.getValue() == val) {
            at.can_set = false; // entered by user - not modifiable
        } else {
            at.can_set = true; // calculated - modifiable
        }
    },

    isAuto: function (name) {
        return (this.attr[name].can_set && !this.attr[name].disable);
    },

    vget: function (name) {
        return strTrim(this.data.get(name));
    },

    setIf: function (name, val) {
        if (this.isAuto(name)) {
            this.vset(name, val);
            return true;
        }
        return false;
    },

    getSubst: function (what, override) {
        var dn = strTrim((what in config) ? config[what] : '');
        var name;
    	while ((name = dn.match(/\$\((\w+)\)/)) != null) {
	    	name = name[1];
	    	var val = '';
	    	if (override != undefined && override != null && (name in override))
	    	    val = strTrim(override[name]);
	    	if (val == '')
	    	    val = this.vget(name);
         	if (val == '') {
	            dn = '';
	            break;
            }
            dn = dn.replace(/\$\((\w+)\)/, val);
	    }
    	return dn;
    },

    // ###### constant and copy-from fields ########
    fillDefs: function () {
        for (var name in this.attr) {
            var desc = this.attr[name].desc;
            if (desc.defval != null)
                this.setIf(name, desc.defval);
            if (desc.copyfrom != null && !this.isAuto(desc.copyfrom))
                this.setIf(name, this.vget(desc.copyfrom));
        }
    },

    nextSeq: function (which, name, format) {
        if (!this.isAuto(name))
            return;
        var at = this.attr[name];
        if (at.requesting || (at.requested && this.vget(name) != ''))
            return;
        at.requesting = at.requested = true;
        //debug('nextSeq(%s,%s/%s)...', which, this.name, name);
        var _this = this;
        Ext.Ajax.request({
            url: 'next-id.php',
            method: 'GET',
            params: { which: which },
            timeout: this.FORM_TIMEOUT * 1000,
            scope: this,
            success: function (resp, opts) {
                at.requesting = false;
                var id = strTrim(resp.responseText).replace(/[^0-9]/g, '');
                if (format)
                    id = format(id);
                if (this.setIf(name, id) && this.attr[name].field)
                    this.attr[name].field.setValue(id);
                debug('nextSeq(%s,%s/%s)="%s"', which, _this.name, name, id);
            },
            failure: function (resp, opts) {
                at.requesting = false;
                debug('nextSeq(%s,%s/%s):FAIL', which, _this.name, name);
            }
        });
    },

    btnId: function (op) {
        return 'btn_' + this.name + '_' + op;
    },

    setupField: function (name) {
        var desc = all_attrs[this.name][name];

        var at = this.attr[name] = {
            can_set: true,
            name: name,
            disable: desc.disable,
            desc: desc,
            field: null,
            id: 'field_' + this.name + '_' + name,
            requesting: false,
            requested: false
        };

        if (desc.disable || !desc.visual)
             return at;

        if (desc.colwidth) {
            this.list_width += desc.colwidth + this.COL_GAP;
            this.list_cols.push({
                header: _T(desc.label),
                dataIndex: name,
                sortable: true,
                width: desc.colwidth,
            });
        }

        var cfg = {
            id: at.id,
            name: name,
            fieldLabel: _T(desc.label),
            readonly: desc.readonly,
            anchor: '-' + this.RIGHT_GAP,
            _attr: at,
        };

        if (desc.type == 'pass' && !config.show_password)
            cfg.inputType = 'password';

        if (desc.popup === 'yesno') {
            Ext.apply(cfg, {
                store: [ 'No', 'Yes' ],
                editable: false,
                allowBlank: false,
                triggerAction: 'all'
            });
            at.field = new Ext.form.ComboBox(cfg);
        } else if (desc.popup === 'gid') {
            Ext.apply(cfg, {
                store: std_lists['groups'].store,
                mode: 'local',
                allowBlank: false,
                forceSelection: false,
                triggerAction: 'all',
                displayField: 'cn',
                valueField: 'cn'
            });
            at.field = new Ext.form.ComboBox(cfg);
        } else if (desc.popup in std_lists) {
            Ext.apply(cfg, {
                store: std_lists[desc.popup].store,
                mode: 'local',
                allowBlank: true,
                forceSelection: false,
                triggerAction: 'all',
                hideOnSelect: false,
                displayField: std_lists[desc.popup].attr,
                valueField: std_lists[desc.popup].attr,
                checkField: 'checked_' + cfg.id
            });
            at.field = new Ext.ux.form.LovCombo(cfg);
        } else if (! desc.popup) {
            var _this = this;
            //cfg.enableKeyEvents = true;
            //cfg.listeners = { keypress: function(e,ev) { _this.onModified(e,ev); } };
            cfg.listeners = { valid: function(e,ev) { _this.onModified(e,ev); } };
            at.field = new Ext.form.TextField(cfg);
        } else {
            Ext.Msg.alert(_T('Unknown popup type "%s"', desc.popup));
        }

        return at;
    },

    createTab: function () {
        if (! this.form_tabs.length)
            return null;
        var _this = this;

        this.form_panel = new Ext.FormPanel({
            region: 'center',
            id: this.name + '_panel',
            title: '...',
            url: this.write_url,
            border: false,
            layout: 'fit',
            timeout: this.FORM_TIMEOUT,

            reader: new Ext.data.JsonReader({
                root: 'obj',
                idProperty: this.id_attr,
                fields: this.obj_attrs
            }),

            items: [{
                xtype: 'tabpanel',
                activeItem: 0,
                items: this.form_tabs
            }],

            bbar: [ '->', {
                text: _T('Save'),
                icon: 'images/apply.png',
                scale: 'medium',
                ctCls: config.add_button_css,
                handler: function() { _this.save() },
                id: this.btnId('save')
            },{
                text: _T('Revert'),
                icon: 'images/revert.png',
                scale: 'medium',
                ctCls: config.add_button_css,
                handler: function() { _this.onRevert(); },
                id: this.btnId('revert')
            },
            ' ' ]
        });
        this.form = this.form_panel.getForm();

        this.list_panel = new Ext.grid.GridPanel({
            store: this.list_store,
            title: _T(this.title),
            id: this.name + '_list',

            colModel: new Ext.grid.ColumnModel({
                columns: this.list_cols
            }),

            selModel: new Ext.grid.RowSelectionModel({
                singleSelect: true,
                listeners: {
                    rowdeselect: function(sm, row, rec) {
                        if (_this.onLeave(sm, row, rec))
                            this.unlock();
                        else
                            this.lock();
                    },
                    rowselect: function(sm, row, rec) {
                        _this.load(sm, row, rec);
                    }
                }
            }),

            region: 'west',
            split: true,
            collapsible: true,
            //collapseMode: 'mini',
            width: this.list_width,
            minSize: 50
        });

        var obj_buttons = [ ' ', {
                text: _T('Create'),
                icon: 'images/add.png',
                scale: 'medium',
                ctCls: config.add_button_css,
                handler: function() { _this.onCreate(); },
                id: this.btnId('add')
            },{
                text: _T('Delete'),
                icon: 'images/delete.png',
                scale: 'medium',
                ctCls: config.add_button_css,
                handler: function() { _this.delete(); },
                id: this.btnId('delete')
            },{
                text: _T('Refresh'),
                icon: 'images/refresh.png',
                scale: 'medium',
                ctCls: config.add_button_css,
                handler: function() { _this.refresh(); },
                id: this.btnId('refresh')
            },
            '->', new AjaxIndicator()
            ];

        this.tab_panel = {
            title: _T(this.title),
            layout: 'border',
            items: [ this.list_panel, this.form_panel ],
            bbar: {
                xtype: 'toolbar',
                items: obj_buttons
            }
        };

        this.enabled = true;
        return this.tab_panel;
    }

});

/////////////////////////////////////////////////////////
// users
//

Userman.User = Ext.extend(Userman.Object, {
    name: 'user',
    list: 'users',
    title: ' Users ',
    id_attr: 'uid',

    formTitle: function () {
        return this.vget('uid') + ' (' + this.vget('cn') + ')';
    },

    rework: function () {
        var uid = this.vget('uid');
        var cn = this.vget('cn');
        var gn = this.vget('givenName');
        var sn = this.vget('sn');

        // ############# POSIX ############

        // name
        if (this.isAuto('cn'))
            this.setIf('cn', (cn = gn + (sn && gn ? ' ' : '') + sn));

        // identifier
        if (this.isAuto('uid'))
            uid = sn == '' ? gn : gn.substr(0, 1) + sn;
        this.vset('uid', (uid = string2id(uid)));

        //#this.vset('objectClass', append_list(this.vget('objectClass'), config.unix_user_classes));

        this.setIf('dn', this.getSubst('unix_user_dn'));
        this.setIf('ntDn', this.getSubst('ad_user_dn'));

        // assign next available UID number
        if (this.isAuto('uidNumber')) {
            var uidn = this.vget('uidNumber');
            uidn = uidn.replace(/[^0-9]/g, '');
            this.vset('uidNumber', uidn);
        }
        this.nextSeq('unix_uidn', 'uidNumber');

        // mail
        if (uid != '')
            this.setIf('mail', uid + '@' + config.mail_domain);

        // home directory
        if (uid != '')
            this.setIf('homeDirectory', config.home_root + '/' + uid);

        // ############# Active Directory ############

        //#this.vset('ntObjectClass', append_list(this.vget('ntObjectClass'), config.ad_user_classes));

        //#this.setIf('objectCategory', config.ad_user_category+','+path2dn(config.ad_domain));

        this.setIf('userPrincipalName', uid+'@'+config.ad_domain);

        //#var pass = this.vget('password');
        //#if (pass === config.OLD_PASS) {
        //#    this.vset('userAccountControl', this.vget('userAccountControl', array(orig => true)));
        //#} else {
        //#    var uac = this.vget('userAccountControl') || ADS_UF_NORMAL_ACCOUNT;
        //#    uac &= ~(ADS_UF_PASSWD_NOT_REQUIRED | ADS_UF_DONT_EXPIRE_PASSWD);
        //#    uac |= (pass == '' ? ADS_UF_PASSWD_NOT_REQUIRED : ADS_UF_DONT_EXPIRE_PASSWD);
        //#    this.vset('userAccountControl', uac);
        //#}

        // ######## CommuniGate Pro ########

        var telnum = this.vget('telnum');
        this.vset('telnum', formatTelnum(telnum));
        this.nextSeq('cgp_telnum', 'telnum', formatTelnum);

        this.vset('domainIntercept', bool2str(this.vget('domainIntercept')) );
        this.vset('userIntercept', bool2str(this.vget('userIntercept')) );
    }

});

/////////////////////////////////////////////////////////
// groups
//

Userman.Group = Ext.extend(Userman.Object, {
    name: 'group',
    list: 'groups',
    title: ' Groups ',
    id_attr: 'cn',

    formTitle: function () {
        return this.vget('cn');
    },

    rework: function () {
        this.vset('objectClass', config.unix_group_classes);
        this.vset('cn', string2id(this.vget('cn')));
        this.vset('gidNumber', this.vget('gidNumber').replace(/[^0-9]/g, ''));
        this.nextSeq('unix_gidn', 'gidNumber');
        this.vset('dn', this.getSubst('unix_group_dn'));
    }

});

/////////////////////////////////////////////////////////
// mailgroups
//

Userman.Mailgroup = Ext.extend(Userman.Object, {
    name: 'mailgroup',
    list: 'mailgroups',
    title: ' Mail groups ',
    id_attr: 'uid',

    formTitle: function () {
        return this.vget('uid');
    },

    rework: function () {
        this.vset('uid', string2id(this.vget('uid')));
        this.setIf('cn', this.vget('uid'));

        // ###### constant (& not copyfrom) fields ########
        this.fillDefs();
    }

});


/////////////////////////////////////////////////////////
// GUI
//

function hidePreloader() {
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

////////
// fixes bug in LovCombo: the value did not change after onblur
// because auto-inserted blanks do not pass regexp in setValue

Ext.override(Ext.ux.form.LovCombo, {
    getCheckedDisplay:function() {
		return this.getCheckedValue(this.displayField);
	}
});


std_lists = {
    'users': {
        url: 'user-list.php',
        attr: 'uid',
        fields: [ 'uid', 'cn' ]
    },
    'groups': {
        url: 'group-list.php',
        attr: 'cn',
    },
    'mailgroups': {
        url: 'mailgroup-list.php',
        attr: 'uid'
    },
    'mailusers': {
        url: 'mailuser-list.php',
        attr: 'uid'
    }
};

function setupStdLists () {
    for (var name in std_lists) {
        var list = std_lists[name];
        var fields = [ list.attr ];
        if (list.fields)
            fields = list.fields;
        list.store = new Ext.data.JsonStore({
            url: list.url,
            root: 'rows',
            idProperty: list.attr,
            fields: fields,
            autoLoad: false
        });
        list.store.load();
    }
}

function main() {

    hidePreloader();
    Ext.QuickTips.init();
    setupStdLists();

    var objs = [
        new Userman.User()
        ,new Userman.Group(),
        ,new Userman.Mailgroup()
    ];
    var tabs = [];
    objs.forEach(function(obj) {
        var tab = obj.createTab();
        if (tab)  tabs.push(tab);
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

    objs.forEach(function(obj) {
        if (obj.enabled)  obj.onUnselect();
    });

    //Ext.util.Observable.capture(Ext.getCmp('field_user_sn'), console.info);
};

Ext.onReady(main);

