// $Id$

/////////////////////////////////////////////////////////
// translations are loaded dynamically
//

function _T() {
	var args = arguments;
	var format = args[0];
	var message = trans && trans[format] ? trans[format] : format;
	for (i = 1; i < arguments.length; i++)
	    message = message.replace('%s', arguments[i]);
	return message;
};

function test_msg(e) {
    Ext.Msg.alert('hihi','hohoho');
}

/////////////////////////////////////////////////////////
// users
//

var user_obj = { changed: false };

var user_rec = Ext.data.Record.create([
    'uid',
    'cn',
    'dn'
    ]);

var user_store = new Ext.data.Store({
    url: 'user-list.php',
    autoLoad: true,
    reader: new Ext.data.JsonReader({
        root: 'rows',
        idProperty: 'uid'
    }, user_rec)
});

function user_add() {
    test_msg();
}

function user_delete() {
    test_msg();
}

function users_refresh() {
    test_msg();
}

function user_unselect() {
}

function user_change(user_sm) {
    Ext.Msg.alert('hihi','user change');
}

function user_load(user_sm, row_idx, rec) {
    Ext.Msg.alert('hihi','user load');
}

function create_user_list() {
    return {
        xtype: 'grid',
        store: user_store,
        colModel: new Ext.grid.ColumnModel({
            columns: [{
                header: _T('Identifier'),
                dataIndex: 'uid',
                sortable: true,
                width: 100,
            },{
                header: _T('Full name'),
                dataIndex: 'dn',
                sortable: true,
                width: 190
            }]
        }),
        selModel: new Ext.grid.RowSelectionModel({
            singleSelect: true,
            listeners: {
                rowdeselect: user_change, // FIXME
                rowselect: user_load
            }
        })
    };
}

function create_user_desc() {
    return {
        html: 'user desc'
    };
}

/////////////////////////////////////////////////////////
// groups
//

var group_obj = { changed: false };

var group_rec = Ext.data.Record.create([
    'cn',
    'dn'
]);

var group_store = new Ext.data.Store({
    url: 'group-list.php',
    autoLoad: true,
    reader: new Ext.data.JsonReader({
        root: 'rows',
        idProperty: 'dn'
    }, group_rec)
});

function group_add() {
    test_msg();
}

function group_delete() {
    test_msg();
}

function groups_refresh() {
    test_msg();
}

function group_unselect() {
}

function group_change(user_sm) {
    Ext.Msg.alert('hihi','group change');
}

function group_load(user_sm, row_idx, rec) {
    Ext.Msg.alert('hihi','group load');
}

function create_group_list() {
    return {
        xtype: 'grid',
        store: group_store,
        colModel: new Ext.grid.ColumnModel({
            columns: [{
                header: _T('Group name'),
                dataIndex: 'cn',
                sortable: true,
                width: 120
            }]
        }),
        selModel: new Ext.grid.RowSelectionModel({
            singleSelect: true,
            listeners: {
                rowdeselect: group_change, // FIXME
                rowselect: group_load
            }
        })
    };
}

function create_group_desc() {
    return {
        html: 'group desc'
    };
}

/////////////////////////////////////////////////////////
// mailgroups
//

var mailgroup_rec = Ext.data.Record.create([
    'cn'
]);

var mailgroup_store = new Ext.data.Store({
    url: 'mailgroup-list.php',
    autoLoad: true,
    reader: new Ext.data.JsonReader({
        root: 'rows',
        idProperty: 'cn'
    }, mailgroup_rec)
});

function mailgroup_add() {
    test_msg();
}

function mailgroup_delete() {
    test_msg();
}

function mailgroups_refresh() {
    test_msg();
}

function mailgroup_unselect() {
}

function mailgroup_change(user_sm) {
    Ext.Msg.alert('hihi','mailgroup change');
}

function mailgroup_load(user_sm, row_idx, rec) {
    Ext.Msg.alert('hihi','group load');
}

function create_mailgroup_list() {
    return {
        xtype: 'grid',
        store: mailgroup_store,
        colModel: new Ext.grid.ColumnModel({
            columns: [{
                header: _T('Mail group name'),
                dataIndex: 'cn',
                sortable: true,
                width: 140
            }]
        }),
        selModel: new Ext.grid.RowSelectionModel({
            singleSelect: true,
            listeners: {
                rowdeselect: mailgroup_change, // FIXME
                rowselect: mailgroup_load
            }
        })
    };
}

function create_mailgroup_desc() {
    return {
        html: 'mailgroup desc'
    };
}

/////////////////////////////////////////////////////////
// AJAX indicator
//

AjaxIndicator = Ext.extend(Ext.Button, {
    disabled: true,
    scale: 'large',
    ajax_urls : new Array(),

    initComponent : function() {
        Ext.Ajax.on('beforerequest', function(conn, o) {
            if (this.ajax_urls.indexOf(o.url) == -1) {
                this.ajax_urls.push(o.url);
                this.showProgress();
            }
        }, this);

        Ext.Ajax.on('requestcomplete', function(conn, response, o) {
            this.ajax_urls.remove(o.url);
            if (this.ajax_urls.length <= 0)
                this.hideProgress();
        }, this);

        Ext.Ajax.on('requestexception', function(conn, response, o) {
            if (this.ajax_urls.length <= 0)
                this.hideProgress();
        }, this);

        this.hideProgress();
    },

    showProgress: function() { this.setIcon('images/throbber-32.gif'); },

    hideProgress: function() { this.setIcon('images/userman-32.png');  },
});

/////////////////////////////////////////////////////////
// main
//

function gui_exit() {
	if (user_obj.changed || group_obj.changed) {
		//my $resp = message_box('question', 'yes-no', _T('Exit and loose changes ?'));
		//return 1 if $resp ne 'yes';
		user_obj.changed = group_obj.changed = false;
	}
	user_unselect();
	group_unselect();
	mailgroup_unselect();
    Ext.Msg.alert('exit','Exit');
}

function west_region(w,width) {
    w.region = 'west';
    w.split = true;
    w.collapsible = true;
    w.collapseMode = 'mini';
    w.width = width;
    w.minSize = 50;
    return w;
}

function center_region(w) {
    w.region = 'center';
    return w;
}

function main() {
    hide_preloader();

    var users_tab = {
        title: _T(' Users '),
        layout: 'border',
        items: [
            west_region(create_user_list(), 300),
            center_region(create_user_desc())
        ],
        bbar: {
            xtype: 'toolbar',
            items: [
            new AjaxIndicator(), ' ',
            {
		        text: _T('Create'),
		        icon: 'images/add.png',
		        scale: 'medium',
		        handler: user_add,
		        id: 'btn_usr_add'
		    },{
		        text: _T('Delete'),
		        icon: 'images/delete.png',
		        scale: 'medium',
		        handler: user_delete,
		        id: 'btn_usr_delete'
		    },{
		        text: _T('Refresh'),
		        icon: 'images/refresh.png',
		        scale: 'medium',
		        handler: users_refresh,
		        id: 'btn_usr_refresh'
		    },'->',{
		        text: _T('Exit'),
		        icon: 'images/exit.png',
		        scale: 'medium',
		        handler: gui_exit
		    }]
        }
    };

    var groups_tab = {
        title: _T(' Groups '),
        layout: 'border',
        items: [
            west_region(create_group_list(), 150),
            center_region(create_group_desc())
        ],
        bbar: {
            xtype: 'toolbar',
            items: [
            new AjaxIndicator(), ' ',
            {
		        text: _T('Create'),
		        icon: 'images/add.png',
		        scale: 'medium',
		        handler: group_add,
		        id: 'btn_grp_add'
		    },{
		        text: _T('Delete'),
		        icon: 'images/delete.png',
		        scale: 'medium',
		        handler: group_delete,
		        id: 'btn_grp_delete'
		    },{
		        text: _T('Refresh'),
		        icon: 'images/refresh.png',
		        scale: 'medium',
		        handler: groups_refresh,
		        id: 'btn_grp_refresh'
		    },'->',{
		        text: _T('Exit'),
		        icon: 'images/exit.png',
		        scale: 'medium',
		        handler: gui_exit
		    }]
        }
    };

    var mailgroups_tab = {
        title: _T(' Mail groups '),
        layout: 'border',
        items: [
            west_region(create_mailgroup_list(), 150),
            center_region(create_mailgroup_desc())
        ],
        bbar: {
            xtype: 'toolbar',
            items: [
            new AjaxIndicator(), ' ',
            {
		        text: _T('Create'),
		        icon: 'images/add.png',
		        scale: 'medium',
		        handler: mailgroup_add,
		        id: 'btn_mgrp_add'
		    },{
		        text: _T('Delete'),
		        icon: 'images/delete.png',
		        scale: 'medium',
		        handler: mailgroup_delete,
		        id: 'btn_mgrp_delete'
		    },{
		        text: _T('Refresh'),
		        icon: 'images/refresh.png',
		        scale: 'medium',
		        handler: mailgroups_refresh,
		        id: 'btn_mgrp_refresh'
		    },'->',{
		        text: _T('Exit'),
		        icon: 'images/exit.png',
		        scale: 'medium',
		        handler: gui_exit
		    }]
        }
    };

    new Ext.Viewport({
        defaults: {
            bodyStyle: 'padding: 5px;',
        },
        layout: 'border',
        items: [{
            region: 'north',
            margins: '5 5 5 5',
            xtype: 'label',
            text: _T('Manage Users'),
            style: 'font-weight: bold; text-align: center'
        } , {
            region: 'center',
            margins: '0 0 0 0',
            xtype: 'tabpanel',
            activeTab: 0,
            items: [ users_tab, groups_tab, mailgroups_tab ]
        }]
    });

	user_unselect();
	group_unselect();
	mailgroup_unselect();
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

