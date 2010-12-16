// $Id$

/////////////////////////////////////////////////////////
// translations are loaded dynamically
//

function _T() {
	var args = arguments;
	var format = args[0];
	var message = translations && translations[format] ? translations[format] : format;
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
    user_store.reload();
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
                dataIndex: 'cn',
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
    group_store.reload();
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
    mailgroup_store.reload();
}

function mailgroup_unselect() {
}

function mailgroup_change(user_sm) {
    Ext.Msg.alert('hihi','mailgroup change');
}

function mailgroup_load(user_sm, row_idx, rec) {
    Ext.Msg.alert('hihi','group load');
}

function mailgroup_save() {
}

function mailgroup_revert() {
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

    items1 = [{
        xtype: 'textfield',
        name: 'cn',
        fieldLabel: _T('Mailgroup name')
    }];
    tab1 = {
        title: _T('Attributes'),
        autoScroll: true,
        defaults: { anchor: '-20' },
        items: items1
    };
    tabs = [ tab1 ];

    //for (var tabname in gui_attrs
/*
	for (@{$gui_attrs{mailgroup}}) {
		my ($tab_name, @tab_attrs) = @$_;
		my $scroll = Gtk2::ScrolledWindow->new(undef, undef);
		$tabs->append_page($scroll, _T($tab_name));
		$scroll->set_policy('automatic', 'automatic');
		$scroll->set_border_width(0);

		my $abox = Gtk2::Table->new($#tab_attrs + 1, 3);
		$scroll->add_with_viewport($abox);

		for my $r (0 .. $#tab_attrs) {
			next unless attribute_enabled('mailgroup', $tab_attrs[$r]);
			my $at = setup_attr($mgrp, $tab_attrs[$r], 1);
			$at->{tab_book} = $tabs;
			$at->{tab_page} = $tab_no;
			$abox->attach($at->{bulb}, 0, 1, $r, $r+1, [], [], 1, 1) if $at->{bulb};
			$abox->attach($at->{label}, 1, 2, $r, $r+1, [], [], 1, 1);
			my $right = 4;
			if ($at->{popup}) {
				$abox->attach($at->{popup}, 3, 4, $r, $r+1, [], [], 1, 1);
				$right = 3;
			}
			$abox->attach($at->{entry}, 2, $right, $r, $r+1, [ 'fill', 'expand' ], [], 1, 1);
			$at->{entry}->signal_connect(key_release_event => sub { mailgroup_entry_edited($at) });
		}

		$tab_no++;
	}
*/


    return {
        layout: 'border',
        items: [{
            region: 'north',
            margins: '5 5 5 5',
            xtype: 'label',
            text: '?',
            style: 'font-weight: bold; text-align: center',
            id: 'title_mailgroup_name'
        },{
            region: 'center',
            margins: '0 0 0 0',
            xtype: 'form',
            layout: 'fit',
            url: 'mailgroup-write.php',
            frame: true,
            items: [{
                xtype: 'tabpanel',
                activeItem: 0,
                anchor: '100% 100%',
                deferredRender: false,
                defaults: {
                    layout: 'form',
                    labelWidth: 160,
                    defaultType: 'textfield',
                    bodyStyle: 'padding:5px',
                    hideMode: 'offsets'
                },
                items: tabs
            }],
            buttons: [{
		        text: _T('Save'),
		        icon: 'images/apply.png',
		        scale: 'medium',
		        handler: mailgroup_save,
		        id: 'btn_mgrp_save'
		    },{
		        text: _T('Revert'),
		        icon: 'images/revert.png',
		        scale: 'medium',
		        handler: mailgroup_revert,
		        id: 'btn_mgrp_revert'
            }]
        }]
    };
}

/////////////////////////////////////////////////////////
// AJAX indicator
//

AjaxIndicator = Ext.extend(Ext.Button, {
    disabled: true,
    scale: 'medium',
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

    showProgress: function() { this.setIcon('images/throbber-24.gif'); },

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
            activeTab: 2,
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

