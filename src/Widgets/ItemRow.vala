public class Widgets.ItemRow : Gtk.ListBoxRow {
    public Objects.Item item { get; construct; }
    
    public bool _is_today = false;
    public bool is_today {
        get {
            return _is_today;
        }

        set {
            _is_today = value;
            date_label_revealer.reveal_child = !value;

            var datetime = new GLib.DateTime.from_iso8601 (item.due_date, new GLib.TimeZone.local ()); 
            if (Planner.utils.is_before_today (datetime)) {
                due_label.get_style_context ().add_class ("duedate-expired");
                date_label_revealer.reveal_child = true;
            }
        }
    }

    public GLib.DateTime? _upcoming = null;
    public GLib.DateTime? upcoming {
        get {
            return _upcoming;
        }

        set {
            _upcoming = value;
            date_label_revealer.reveal_child = false;

            project = Planner.database.get_project_by_id (item.project_id);
            project_name_label.label = "<small>%s</small>".printf (project.name);
            project_name_revealer.reveal_child = true;
        }
    }

    private Objects.Project project { get; set; }

    private Gtk.Button hidden_button;
    private Gtk.CheckButton checked_button;
    private Gtk.Entry content_entry;
    private Gtk.Label content_label;
    private Gtk.Stack content_stack;
    
    private Gtk.Box top_box;
    private Gtk.TextView note_textview;
    private Gtk.Label note_placeholder;
    private Gtk.Revealer note_revealer;
    private Gtk.Revealer bottom_revealer;
    private Gtk.Revealer main_revealer;
    private Gtk.Grid main_grid;
    private Gtk.Label due_label;
    private Gtk.Label project_name_label;
    private Gtk.Revealer project_name_revealer;

    private Gtk.Revealer motion_revealer;
    private Gtk.Revealer labels_box_revealer;
    private Gtk.Revealer date_label_revealer;
    private Gtk.Box labels_box;
    private Gtk.Box labels_edit_box;
    
    private Gtk.Label reminder_label;
    private Objects.Reminder? reminder = null;
    private Gtk.Revealer reminder_revealer;

    private Widgets.NewCheck new_checklist;
    private Gtk.Revealer checklist_revealer;
    private Gtk.ListBox check_listbox;
    private Gtk.Revealer separator_revealer;

    private Gtk.Menu projects_menu; 
    private Gtk.Menu sections_menu;
    private Widgets.ImageMenuItem undated_menu;
    private Widgets.DueButton due_button;
    private Widgets.ImageMenuItem move_section_menu;
    private Gtk.Menu menu = null;

    private uint checked_timeout = 0;
    private uint timeout_id = 0;
    private bool save_off = false;

    public Gee.HashMap<string, bool> labels_hashmap;
    
    private const Gtk.TargetEntry[] targetEntries = {
        {"ITEMROW", Gtk.TargetFlags.SAME_APP, 0}
    };

    private const Gtk.TargetEntry[] targetEntriesMagicButton = {
        {"MAGICBUTTON", Gtk.TargetFlags.SAME_APP, 0}
    };

    public signal void update_headers ();

    public bool reveal_child {
        set {
            if (value) {
                show_item ();
            }
        }
        get {
            return bottom_revealer.reveal_child;
        }
    }

    public bool reveal_drag_motion {
        set {   
            motion_revealer.reveal_child = value;
        }
        get {
            return motion_revealer.reveal_child;
        }
    }

    public ItemRow (Objects.Item item) {
        Object (
            item: item
        );
    }

    construct {
        can_focus = false;
        get_style_context ().add_class ("item-row");
        labels_hashmap = new Gee.HashMap<string, bool> ();

        hidden_button = new Gtk.Button.from_icon_name ("pan-end-symbolic", Gtk.IconSize.MENU);
        hidden_button.can_focus = false;
        hidden_button.margin_start = 6;
        hidden_button.tooltip_text = _("View Details");
        hidden_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        hidden_button.get_style_context ().add_class ("hidden-button");

        var hidden_revealer = new Gtk.Revealer ();
        hidden_revealer.valign = Gtk.Align.START;
        hidden_revealer.transition_type = Gtk.RevealerTransitionType.CROSSFADE;
        hidden_revealer.add (hidden_button);
        hidden_revealer.reveal_child = false;

        checked_button = new Gtk.CheckButton ();
        checked_button.can_focus = false;
        checked_button.margin_start = 6;
        checked_button.margin_top = 6;
        checked_button.valign = Gtk.Align.START;
        checked_button.halign = Gtk.Align.BASELINE;
        checked_button.get_style_context ().add_class ("checklist-button");

        if (item.checked == 1) {
            checked_button.active = true;
        } else {
            checked_button.active = false;
        }

        due_label = new Gtk.Label (null);
        due_label.halign = Gtk.Align.START;
        due_label.valign = Gtk.Align.CENTER;
        due_label.margin_end = 6;
        due_label.margin_bottom = 1;

        check_due_style ();
        
        var due_label_revealer = new Gtk.Revealer ();
        due_label_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_LEFT;
        due_label_revealer.add (due_label);

        date_label_revealer = new Gtk.Revealer ();
        date_label_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_LEFT;
        date_label_revealer.add (due_label_revealer);
        date_label_revealer.reveal_child = true;

        if (item.due_date != "") {
            due_label.label = Planner.utils.get_relative_date_from_string (item.due_date);
            due_label_revealer.reveal_child = true;
        }

        content_label = new Gtk.Label (item.content);
        content_label.tooltip_text = item.content;
        content_label.halign = Gtk.Align.START;
        content_label.valign = Gtk.Align.CENTER;
        content_label.xalign = 0;
        content_label.margin_bottom = 3;
        content_label.get_style_context ().add_class ("label");
        content_label.ellipsize = Pango.EllipsizeMode.END;

        var checklist_image = new Gtk.Image ();
        checklist_image.margin_start = 6;
        checklist_image.gicon = new ThemedIcon ("view-list-compact-symbolic");
        checklist_image.pixel_size = 16;
        checklist_image.get_style_context ().add_class ("dim-label");

        checklist_revealer = new Gtk.Revealer ();
        checklist_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_LEFT;
        checklist_revealer.add (checklist_image);

        var note_image = new Gtk.Image ();
        note_image.gicon = new ThemedIcon ("text-x-generic-symbolic");
        note_image.pixel_size = 13;
        note_image.margin_start = 6;
        note_image.get_style_context ().add_class ("dim-label");

        note_revealer = new Gtk.Revealer ();
        note_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_LEFT;
        note_revealer.add (note_image);

        if (item.note != "") {
            note_revealer.reveal_child = true;
        }

        project_name_label = new Gtk.Label (null);
        project_name_label.use_markup = true;

        project_name_revealer = new Gtk.Revealer ();
        project_name_revealer.transition_type = Gtk.RevealerTransitionType.CROSSFADE;
        project_name_revealer.add (project_name_label);

        reminder = Planner.database.get_first_reminders_by_item (item.id);

        var reminder_image = new Gtk.Image ();
        reminder_image.valign = Gtk.Align.CENTER;
        reminder_image.gicon = new ThemedIcon ("planner-alarm-symbolic");
        reminder_image.pixel_size = 16;

        reminder_label = new Gtk.Label (null);
        reminder_label.get_style_context ().add_class ("pane-item");
        reminder_label.margin_bottom = 1;
        reminder_label.use_markup = true;

        var reminder_grid = new Gtk.Grid ();
        reminder_grid.column_spacing = 6;
        reminder_grid.halign = Gtk.Align.CENTER;
        reminder_grid.valign = Gtk.Align.CENTER;
        reminder_grid.add (reminder_image);
        reminder_grid.add (reminder_label);

        reminder_revealer = new Gtk.Revealer ();
        reminder_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_LEFT;
        reminder_revealer.add (reminder_grid);

        Planner.utils.clock_format_changed.connect (() => {
            check_reminder_label (reminder);
        });

        labels_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        labels_box.margin_start = 6;
        
        var 1_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        1_box.margin_end = 32;
        1_box.pack_start (date_label_revealer, false, false, 0); 
        1_box.pack_start (content_label, false, false, 0);
        1_box.pack_start (checklist_revealer, false, false, 0);
        1_box.pack_start (note_revealer, false, false, 0);
        1_box.pack_start (labels_box, false, false, 0);
        1_box.pack_end (reminder_revealer, false, false, 0);
        
        var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        content_box.valign = Gtk.Align.CENTER;
        content_box.margin_top = 3;
        content_box.pack_start (1_box, false, false, 0);

        content_entry = new Gtk.Entry ();
        content_entry.margin_bottom = 1;
        content_entry.placeholder_text = _("Task name");
        content_entry.get_style_context ().add_class ("flat");
        content_entry.get_style_context ().add_class ("label");
        content_entry.get_style_context ().add_class ("content-entry");
        content_entry.text = item.content;
        content_entry.hexpand = true;

        content_stack = new Gtk.Stack ();
        content_stack.margin_start = 6;
        content_stack.hexpand = true;
        content_stack.transition_type = Gtk.StackTransitionType.NONE;
        content_stack.add_named (content_box, "content_label");
        content_stack.add_named (content_entry, "content_entry");

        top_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        top_box.hexpand = true;
        top_box.pack_start (hidden_revealer, false, false, 0);
        top_box.pack_start (checked_button, false, false, 0);
        top_box.pack_start (content_stack, false, true, 0);

        note_textview = new Gtk.TextView ();
        note_textview.margin_start = 65;
        note_textview.buffer.text = item.note;
        note_textview.wrap_mode = Gtk.WrapMode.WORD;
        note_textview.get_style_context ().add_class ("textview");
        note_textview.height_request = 42;

        note_placeholder = new Gtk.Label (_("Add note"));
        note_placeholder.opacity = 0.7;
        note_textview.add (note_placeholder);

        if (item.note != "") {
            note_placeholder.visible = false;
            note_placeholder.no_show_all = true;
        }

        check_listbox = new Gtk.ListBox  ();
        check_listbox.margin_top = 6;
        check_listbox.margin_start = 59;
        check_listbox.get_style_context ().add_class ("check-listbox");

        new_checklist = new Widgets.NewCheck (item.id, item.project_id, item.section_id, item.is_todoist);

        var separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
        separator.margin_start = 59;
        separator.margin_bottom = 6;

        separator_revealer = new Gtk.Revealer ();
        separator_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_UP;
        separator_revealer.add (separator);

        /*
            Actions
        */

        labels_edit_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);

        due_button = new Widgets.DueButton (item);

        var reminder_button = new Widgets.ReminderButton (item);

        var label_button = new Widgets.LabelButton (item.id);
        label_button.margin_start = 12;

        var checklist_icon = new Gtk.Image ();
        checklist_icon.gicon = new ThemedIcon ("view-list-compact-symbolic");
        checklist_icon.pixel_size = 18;

        var checklist_button = new Gtk.Button ();
        checklist_button.image = checklist_icon;
        checklist_button.margin_end = 12;
        checklist_button.tooltip_text = _("Add Checklist");
        checklist_button.get_style_context ().add_class ("flat");
        checklist_button.get_style_context ().add_class ("item-action-button");
        
        var delete_button = new Gtk.Button.from_icon_name ("user-trash-symbolic", Gtk.IconSize.MENU);
        delete_button.can_focus = false; 
        delete_button.valign = Gtk.Align.CENTER;
        delete_button.tooltip_text = _("Delete Task");
        delete_button.get_style_context ().add_class ("flat");
        delete_button.get_style_context ().add_class ("item-action-button");

        var settings_image = new Gtk.Image ();
        settings_image.gicon = new ThemedIcon ("view-more-symbolic");
        settings_image.pixel_size = 14;

        var settings_button = new Gtk.Button ();
        settings_button.image = settings_image;
        settings_button.valign = Gtk.Align.CENTER;
        settings_button.can_focus = false;
        settings_button.tooltip_text = _("Task Menu");
        settings_button.get_style_context ().add_class ("item-action-button");
        settings_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        var action_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        action_box.margin_top = 3;
        action_box.margin_start = 65;
        action_box.pack_start (labels_edit_box, false, true, 0);
        action_box.pack_end (settings_button, false, false, 0);
        action_box.pack_end (delete_button, false, false, 0);
        action_box.pack_end (checklist_button, false, true, 0);
        action_box.pack_end (label_button, false, true, 0);
        action_box.pack_end (reminder_button, false, true, 0);
        action_box.pack_end (due_button, false, true, 0);
        
        var bottom_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        bottom_box.pack_start (note_textview, false, true, 0);
        bottom_box.pack_start (check_listbox, false, false, 0);
        bottom_box.pack_start (separator_revealer, false, false, 0);
        bottom_box.pack_start (new_checklist, false, false, 0);
        bottom_box.pack_end (action_box, false, true, 0);

        bottom_revealer = new Gtk.Revealer ();
        bottom_revealer.valign = Gtk.Align.START;
        bottom_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_DOWN;
        bottom_revealer.add (bottom_box);

        checklist_button.clicked.connect (() => {
            new_checklist.reveal_child = true;
        });

        /*
            Motion Revealer
        */

        var motion_grid = new Gtk.Grid ();
        motion_grid.margin_start = 41;
        motion_grid.margin_end = 32;
        motion_grid.get_style_context ().add_class ("grid-motion");
        motion_grid.height_request = 24;
            
        motion_revealer = new Gtk.Revealer ();
        motion_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_DOWN;
        motion_revealer.add (motion_grid);
        
        main_grid = new Gtk.Grid ();
        main_grid.hexpand = true;
        main_grid.orientation = Gtk.Orientation.VERTICAL;
        main_grid.get_style_context ().add_class ("transition");
        main_grid.add (top_box);
        main_grid.add (bottom_revealer);

        var grid = new Gtk.Grid ();
        grid.margin_bottom = 3;
        grid.hexpand = true;
        grid.orientation = Gtk.Orientation.VERTICAL;

        grid.add (main_grid);
        grid.add (motion_revealer);

        var handle = new Gtk.EventBox ();
        handle.add_events (Gdk.EventMask.ENTER_NOTIFY_MASK | Gdk.EventMask.LEAVE_NOTIFY_MASK);
        handle.expand = true;
        handle.above_child = false;
        handle.add (grid);

        main_revealer = new Gtk.Revealer ();
        main_revealer.reveal_child = true;
        main_revealer.transition_duration = 125;
        main_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_DOWN;
        main_revealer.add (handle);

        add (main_revealer);

        Gtk.drag_source_set (this, Gdk.ModifierType.BUTTON1_MASK, targetEntries, Gdk.DragAction.MOVE);
        drag_begin.connect (on_drag_begin);
        drag_data_get.connect (on_drag_data_get);
        drag_end.connect (clear_indicator);

        build_drag_and_drop (false);

        add_all_checks ();
        add_all_labels ();
        
        content_entry.key_release_event.connect ((key) => {
            if (key.keyval == 65307) {
                hide_item ();
            }

            return false;
        });

        content_entry.activate.connect (() => {
            hide_item ();
        });

        content_entry.changed.connect (() => {
            save ();
        });

        note_textview.buffer.changed.connect (() => {
            save (false);

            if (note_textview.buffer.text == "") {
                note_revealer.reveal_child = false;
            } else {
                note_revealer.reveal_child = true;
            }
        });

        note_textview.focus_in_event.connect (() => {
            note_placeholder.visible = false;
            note_placeholder.no_show_all = true;

            return false;
        });

        note_textview.focus_out_event.connect (() => {
            if (note_textview.buffer.text == "") {
                note_placeholder.visible = true;
                note_placeholder.no_show_all = false;
            }

            return false;
        });

        note_textview.key_release_event.connect ((key) => {
            if (key.keyval == 65307) {
                hide_item ();
            }

            return false;
        });

        Planner.utils.drag_magic_button_activated.connect ((value) => {
            build_drag_and_drop (value);
        });

        handle.enter_notify_event.connect ((event) => {
            hidden_revealer.reveal_child = true;
            return true;
        });

        handle.leave_notify_event.connect ((event) => {
            if (event.detail == Gdk.NotifyType.INFERIOR) {
                return false;
            }

            if (bottom_revealer.reveal_child == false) {
                hidden_revealer.reveal_child = false;
            }

            return true;
        });

        hidden_button.clicked.connect (() => {
            if (reveal_child == false) {
                show_item ();
            } else {
                hide_item ();
            }
        });

        Planner.database.item_added.connect ((i) => {
            if (item.id == i.parent_id) {
                var row = new Widgets.CheckRow (i);
                
                row.hide_item.connect (hide_item);
   
                check_listbox.add (row);
                check_listbox.show_all ();

                check_checklist_separator ();
            }
        });
        
        Planner.database.item_label_added.connect ((id, item_id, label) => {
            if (item.id == item_id && labels_hashmap.has_key (label.id.to_string ()) == false) {
                var l = new Widgets.LabelPreview (id, item_id, label);
                var g = new Widgets.LabelItem (id, item.id, label);

                labels_box.add (l);
                labels_edit_box.add (g);
                
                labels_box.show_all ();
                labels_edit_box.show_all ();

                labels_box_revealer.reveal_child = true;
                labels_hashmap.set (label.id.to_string (), true);
            }
        });

        Planner.database.item_label_deleted.connect ((id, item_id, label) => {
            if (item.id == item_id) {
                labels_hashmap.unset (label.id.to_string ());
            }
        });

        delete_button.clicked.connect (() => {
            if (Planner.database.add_item_to_delete (item)) {
                get_style_context ().remove_class ("item-row-selected");
                main_revealer.reveal_child = false;
            }
        });

        Planner.database.item_deleted.connect ((i) => {
            Idle.add (() => {
                if (item.id == i.id) {
                    destroy ();
                }

                return false;
            });
        });

        Planner.database.show_undo_item.connect ((id) => {
            if (item.id == id) {
                hide_item ();
                hidden_revealer.reveal_child = false;
                main_revealer.reveal_child = true;
            }
        });

        button_press_event.connect ((sender, evt) => {
            if (evt.type == Gdk.EventType.BUTTON_PRESS && evt.button == 3) {
                if (bottom_revealer.reveal_child == false) {
                    activate_menu ();
                }

                return true;
            }

            return false;
        });

        settings_button.clicked.connect (() => {
            activate_menu ();
        });

        checked_button.toggled.connect (checked_toggled);

        check_listbox.remove.connect (() => {
            check_checklist_separator ();
        });

        Planner.todoist.item_completed_completed.connect ((i) => {
            if (item.id == i.id) {
                destroy ();
            }
        });

        Planner.database.update_due_item.connect ((i) => {
            if (item.id == i.id) {
                var datetime = new GLib.DateTime.from_iso8601 (i.due_date, new GLib.TimeZone.local ());

                due_label.label = Planner.utils.get_relative_date_from_date (datetime);
                due_label_revealer.reveal_child = true;
                
                check_due_style ();
                due_button.update_date_text (i.due_date);

                if (is_today) {
                    date_label_revealer.reveal_child = false;
                    
                    if (Planner.utils.is_today (datetime) == false && Planner.utils.is_before_today (datetime) == false) {
                        hide_item ();

                        Timeout.add (1000, () => {
                            destroy ();
                
                            return false;
                        });
                    }
                }

                if (upcoming != null) {
                    date_label_revealer.reveal_child = false;

                    if (Granite.DateTime.is_same_day (datetime, upcoming) == false) {
                        hide_item ();

                        Timeout.add (1000, () => {
                            print ("Se elimino update_due_item\n"); 
                            destroy ();
                
                            return false;
                        });
                    }
                }
            }
        });

        Planner.database.add_due_item.connect ((i) => {
            if (item.id == i.id) {
                due_label.label = Planner.utils.get_relative_date_from_date (
                    new GLib.DateTime.from_iso8601 (item.due_date, new GLib.TimeZone.local ())
                );
                due_label_revealer.reveal_child = true;

                check_due_style ();
                due_button.update_date_text (i.due_date);
            }
        });

        Planner.database.remove_due_item.connect ((i) => {
            if (item.id == i.id) {
                due_label.label = "";
                due_label_revealer.reveal_child = false;

                check_due_style ();
                due_button.update_date_text (i.due_date);

                if (is_today || upcoming != null) {
                    hide_item ();

                    Timeout.add (1500, () => {
                        print ("Se elimino update_due_item\n"); 
                        destroy ();
            
                        return false;
                    });
                }
            }
        });

        /*
        Planner.todoist.item_moved_started.connect ((id) => {
            if (item.id == id) {
                sensitive = false;
            }
        });

        Planner.todoist.item_moved_completed.connect ((id) => {
            if (item.id == id) {
                if (upcoming == null) {
                    destroy ();
                } else if (is_today) {
                    destroy ();
                } else {
                    sensitive = true;
                }
            }
        });

        Planner.todoist.item_moved_error.connect ((id, error_code, error_message) => {
            if (item.id == id) {
                sensitive = true;
            }
        });
        */

        Planner.database.item_updated.connect ((i) => {
            Idle.add (() => {
                if (item.id == i.id) {
                    save_off = true;

                    item.content = i.content;
                    item.note = i.note;

                    content_entry.text = item.content;
                    content_label.label = item.content;
                    note_textview.buffer.text = item.note;
                    
                    if (note_textview.buffer.text == "") {
                        note_placeholder.visible = true;
                        note_placeholder.no_show_all = false;
                    } else {
                        note_placeholder.visible = false;
                        note_placeholder.no_show_all = true;
                    }

                    Timeout.add (250, () => {
                        save_off = false;
        
                        return false;
                    });
                }

                return false;
            });
        });

        Planner.database.item_moved.connect ((i, project_id, old_project_id) => {
            if (item.id == i.id) {
                item.project_id = project_id;

                if (upcoming != null) {
                    project = Planner.database.get_project_by_id (item.project_id);
                    project_name_label.label = "<small>%s</small>".printf (project.name);
                    project_name_revealer.reveal_child = true;
                }
            }
        });

        Planner.database.reminder_deleted.connect ((id) => {
            if (reminder != null && reminder.id == id) {
                reminder = Planner.database.get_first_reminders_by_item (item.id);
                check_reminder_label (reminder);
            }
        });

        Planner.database.reminder_added.connect (() => {
            reminder = Planner.database.get_first_reminders_by_item (item.id);
            check_reminder_label (reminder);
        });

        /* 
        Planner.instance.go_view.connect ((type, id, id2) => {
            if (item.id == id) {
                bool b = false;
                int c = 0;

                Timeout.add (200, () => {
                    if (b) {
                        get_style_context ().add_class ("item-hover");

                        b = false;
                    } else {
                        get_style_context ().remove_class ("item-hover");

                        b = true;
                    }

                    c = c + 1;

                    if (c > 5) {
                        c = 0;
                        get_style_context ().remove_class ("item-hover");

                        return false;
                    }

                    return true;
                });
            }
        });
        */

        Planner.database.item_completed.connect ((i) => {
            Idle.add (() => {
                if (item.id == i.id) {
                    if (i.checked == 1) {
                        checked_button.active = true;
    
                        content_label.get_style_context ().add_class ("item-complete");
    
                        checked_timeout = Timeout.add (700, () => {
                            main_revealer.reveal_child = false;
                            return false;
                        });
                    } else {
                    }
                }

                return false;
            });
        });

        Planner.database.item_id_updated.connect ((current_id, new_id) => {
            Idle.add (() => {
                if (item.id == current_id) {
                    item.id = new_id;
                }

                return false;
            });
        });

        Planner.database.project_id_updated.connect ((current_id, new_id) => {
            Idle.add (() => {
                if (item.project_id == current_id) {
                    item.project_id = new_id;
                }

                return false;
            });
        });

        Planner.database.section_id_updated.connect ((current_id, new_id) => {
            Idle.add (() => {
                if (item.section_id == current_id) {
                    item.section_id = new_id;
                }

                return false;
            });
        });
    }

    private void checked_toggled () {
        if (checked_button.active) { 
            item.checked = 1;
            item.date_completed = new GLib.DateTime.now_local ().to_string ();

            checked_button.sensitive = false;
            new Thread<void*> ("todoist_item_complete", () => {
                Planner.database.update_item_completed (item);
                if (item.is_todoist == 1) {
                    Planner.todoist.item_complete (item);
                }

                return null;
            });
        }
    }

    private void show_item () {
        bottom_revealer.reveal_child = true;
        main_grid.get_style_context ().add_class ("item-row-selected");

        content_stack.visible_child_name = "content_entry";

        hidden_button.get_style_context ().add_class ("opened");
        hidden_button.tooltip_text = _("Hiding");

        activatable = false;
        selectable = false;
        
        content_entry.grab_focus_without_selecting ();

        if (content_entry.cursor_position < content_entry.text.length) {
            content_entry.move_cursor (Gtk.MovementStep.BUFFER_ENDS, 0, false);
        }
    }

    private void hide_item () {
        bottom_revealer.reveal_child = false;

        main_grid.get_style_context ().remove_class ("item-row-selected");
        content_stack.visible_child_name = "content_label";

        hidden_button.get_style_context ().remove_class ("opened");
        hidden_button.tooltip_text = _("View Details");

        timeout_id = Timeout.add (250, () => {
            activatable = true;
            selectable = true;
            
            Source.remove (timeout_id);
            
            return false;
        });
    }

    private void build_drag_and_drop (bool is_magic_button_active) {
        if (is_magic_button_active) {
            Gtk.drag_dest_set (this, Gtk.DestDefaults.ALL, targetEntriesMagicButton, Gdk.DragAction.MOVE);
            this.drag_data_received.connect (on_drag_magic_button_received);
        } else {
            this.drag_data_received.disconnect (on_drag_magic_button_received);
            Gtk.drag_dest_set (this, Gtk.DestDefaults.MOTION, targetEntries, Gdk.DragAction.MOVE);
        }

        drag_motion.connect (on_drag_motion);
        drag_leave.connect (on_drag_leave);        
    }

    private void on_drag_magic_button_received (Gdk.DragContext context, int x, int y, Gtk.SelectionData selection_data, uint target_type, uint time) {
        Planner.utils.magic_button_activated (
            item.project_id,
            item.section_id,
            item.is_todoist,
            false,
            this.get_index () + 1
        );
    }

    private void on_drag_begin (Gtk.Widget widget, Gdk.DragContext context) {
        var row = (ItemRow) widget;

        Gtk.Allocation alloc;
        row.get_allocation (out alloc);

        var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, alloc.width, alloc.height);
        var cr = new Cairo.Context (surface);
        cr.set_source_rgba (0, 0, 0, 0.3);
        cr.set_line_width (1);

        cr.move_to (0, 0);
        cr.line_to (alloc.width, 0);
        cr.line_to (alloc.width, alloc.height);
        cr.line_to (0, alloc.height);
        cr.line_to (0, 0);
        cr.stroke ();
  
        cr.set_source_rgba (255, 255, 255, 0.5);
        cr.rectangle (0, 0, alloc.width, alloc.height);
        cr.fill ();

        row.draw (cr);

        Gtk.drag_set_icon_surface (context, surface);
        main_revealer.reveal_child = false;
        Planner.utils.drag_item_activated (true);
    }

    private void on_drag_data_get (Gtk.Widget widget, Gdk.DragContext context, Gtk.SelectionData selection_data, uint target_type, uint time) {
        uchar[] data = new uchar[(sizeof (ItemRow))];
        ((Gtk.Widget[])data)[0] = widget;

        selection_data.set (
            Gdk.Atom.intern_static_string ("ITEMROW"), 32, data
        );
    }

    public void clear_indicator (Gdk.DragContext context) {
        reveal_drag_motion = false;
        
        main_revealer.reveal_child = true;

        Planner.utils.drag_item_activated (false);
    }

    public bool on_drag_motion (Gdk.DragContext context, int x, int y, uint time) {
        reveal_drag_motion = true;
        return true;
    }

    public void on_drag_leave (Gdk.DragContext context, uint time) {
        reveal_drag_motion = false;
    }

    private void save (bool online=true) {
        if (save_off == false) {
            content_label.label = content_entry.text;

            content_label.tooltip_text = item.content;
            item.content = content_entry.text;
            item.note = note_textview.buffer.text;

            if (online) {
                item.save ();
            } else {
                item.save_local ();
            }
        }   
    }
    
    private void add_all_checks () {
        foreach (var check in Planner.database.get_all_cheks_by_item (item.id)) {
            var row = new Widgets.CheckRow (check);

            row.hide_item.connect (hide_item);

            check_listbox.add (row);
            check_listbox.show_all ();
        }

        check_checklist_separator ();
    }

    private void add_all_labels () {
        foreach (var label in Planner.database.get_labels_by_item (item.id)) {
            var l = new Widgets.LabelPreview (label.item_label_id, item.id, label);
            var g = new Widgets.LabelItem (label.item_label_id, item.id, label);

            labels_box.add (l);
            labels_edit_box.add (g);

            labels_box.show_all ();
            labels_edit_box.show_all ();

            labels_box_revealer.reveal_child = true;
            labels_hashmap.set (label.id.to_string (), true);
        }
    }

    private void check_due_style () {
        if (item.due_date != "") {
            var datetime = new GLib.DateTime.from_iso8601 (item.due_date, new GLib.TimeZone.local ());            
            
            due_label.get_style_context ().remove_class ("duedate-today");
            due_label.get_style_context ().remove_class ("duedate-expired");
            due_label.get_style_context ().remove_class ("duedate-upcoming");
            
            if (Planner.utils.is_today (datetime)) {
                due_label.get_style_context ().add_class ("duedate-upcoming");
            } else if (Planner.utils.is_before_today (datetime)) {
                due_label.get_style_context ().add_class ("duedate-upcoming");
            } else {
                due_label.get_style_context ().add_class ("duedate-upcoming");
            }
        }
    }
    private void check_checklist_separator () {
        if (check_listbox.get_children ().length () > 0) {
            checklist_revealer.reveal_child = true;
            separator_revealer.reveal_child = true;
        } else {
            checklist_revealer.reveal_child = false;
            separator_revealer.reveal_child = false;
        }
    }

    private void activate_menu () {
        if (menu == null) {
            build_context_menu (item);
        } 

        foreach (var child in projects_menu.get_children ()) {
            child.destroy ();
        }

        foreach (var child in sections_menu.get_children ()) {
            child.destroy ();
        }

        Widgets.ImageMenuItem item_menu;

        item_menu = new Widgets.ImageMenuItem (_("Inbox"), "mail-mailbox-symbolic");
        item_menu.activate.connect (() => {
            int64 inbox_id = Planner.settings.get_int64 ("inbox-project");

            Planner.database.move_item (item, inbox_id);
            if (item.is_todoist == 1) {
                Planner.todoist.move_item (item, inbox_id);
            }
        });

        projects_menu.add (item_menu);
        
        foreach (var project in Planner.database.get_all_projects ()) {
            if (item.project_id != project.id && project.inbox_project == 0 && project.is_todoist == item.is_todoist) {
                item_menu = new Widgets.ImageMenuItem (project.name, "planner-project-symbolic");
                item_menu.activate.connect (() => {
                    Planner.database.move_item (item, project.id);
                    if (item.is_todoist == 1) {
                        Planner.todoist.move_item (item, project.id);
                    }
                });

                projects_menu.add (item_menu);
            }
        }

        if (item.section_id != 0) {
            item_menu = new Widgets.ImageMenuItem (_("No Section"), "window-close-symbolic");
            item_menu.activate.connect (() => {
                Planner.database.move_item_section (item, 0);
                if (item.is_todoist == 1) {
                    Planner.todoist.move_item_to_section (item, 0);
                }
            });

            sections_menu.add (item_menu);
        }
        
        int section_count = 0;
        foreach (var section in Planner.database.get_all_sections_by_project (item.project_id)) {
            if (item.section_id != section.id) {
                item_menu = new Widgets.ImageMenuItem (section.name, "planner-project-symbolic");
                item_menu.activate.connect (() => {
                    Planner.database.move_item_section (item, section.id);
                    if (item.is_todoist == 1) {
                        Planner.todoist.move_item_to_section (item, section.id);
                    }
                });

                sections_menu.add (item_menu);
            }

            section_count++;
        }

        if (section_count > 0) {
            move_section_menu.visible = true;
            move_section_menu.no_show_all = false;
        } else {
            move_section_menu.visible = false;
            move_section_menu.no_show_all = true;
        }

        if (item.due_date == "") {
            undated_menu.visible = false;
            undated_menu.no_show_all = true;
        } else {
            undated_menu.visible = true;
            undated_menu.no_show_all = false;
        }

        projects_menu.show_all ();
        sections_menu.show_all ();

        menu.popup_at_pointer (null);
    }

    private void build_context_menu (Objects.Item item) {
        menu = new Gtk.Menu ();
        menu.width_request = 235;

        var complete_menu = new Widgets.ImageMenuItem (_("Complete"), "emblem-default-symbolic");
        var edit_menu = new Widgets.ImageMenuItem (_("Edit"), "edit-symbolic");

        string today_icon = "planner-today-day-symbolic";
        string today_css = "today-day-icon";
        var hour = new GLib.DateTime.now_local ().get_hour ();
        if (hour >= 18 || hour <= 5) {
            today_icon = "planner-today-night-symbolic";
            today_css = "today-night-icon";
        }
        
        var today_menu = new Widgets.ImageMenuItem (_("Today"), today_icon);
        today_menu.item_image.get_style_context ().add_class (today_css);

        var tomorrow_menu = new Widgets.ImageMenuItem (_("Tomorrow"), "x-office-calendar-symbolic");
        tomorrow_menu.item_image.get_style_context ().add_class ("upcoming-icon");

        undated_menu = new Widgets.ImageMenuItem (_("Undated"), "window-close-symbolic");
        undated_menu.item_image.get_style_context ().add_class ("due-clear");
        
        var move_project_menu = new Widgets.ImageMenuItem (_("Move to Project"), "planner-project-symbolic");
        projects_menu = new Gtk.Menu ();
        move_project_menu.set_submenu (projects_menu);

        move_section_menu = new Widgets.ImageMenuItem (_("Move to Section"), "go-jump-symbolic");
        sections_menu = new Gtk.Menu ();
        move_section_menu.set_submenu (sections_menu);

        var share_menu = new Widgets.ImageMenuItem (_("Share"), "emblem-shared-symbolic");
        var share_list_menu = new Gtk.Menu ();
        share_menu.set_submenu (share_list_menu);

        var share_text_menu = new Widgets.ImageMenuItem (_("Text"), "text-x-generic-symbolic");
        var share_markdown_menu = new Widgets.ImageMenuItem (_("Markdown"), "planner-markdown-symbolic");

        share_list_menu.add (share_text_menu);
        share_list_menu.add (share_markdown_menu);
        share_list_menu.show_all ();

        var duplicate_menu = new Widgets.ImageMenuItem (_("Duplicate"), "edit-copy-symbolic");
        var delete_menu = new Widgets.ImageMenuItem (_("Delete"), "user-trash-symbolic");
        delete_menu.item_image.get_style_context ().add_class ("label-danger");

        menu.add (complete_menu);
        menu.add (edit_menu);
        menu.add (new Gtk.SeparatorMenuItem ());
        menu.add (today_menu);
        menu.add (tomorrow_menu);
        menu.add (undated_menu);
        menu.add (new Gtk.SeparatorMenuItem ());
        menu.add (move_project_menu);
        menu.add (move_section_menu);
        menu.add (share_menu);
        //menu.add (duplicate_menu);
        menu.add (new Gtk.SeparatorMenuItem ());
        menu.add (delete_menu);

        menu.show_all ();

        complete_menu.activate.connect (() => {
            checked_button.active = !checked_button.active;
        });

        edit_menu.activate.connect (() => {
            show_item ();
        });

        today_menu.activate.connect (() => {
            due_button.set_due (new GLib.DateTime.now_local ());
        });

        tomorrow_menu.activate.connect (() => {
            due_button.set_due (new GLib.DateTime.now_local ().add_days (1));
        });

        undated_menu.activate.connect (() => {
            due_button.set_due (null);
        });

        share_text_menu.activate.connect (() => {
            item.share_text ();
        });

        share_markdown_menu.activate.connect (() => {
            item.share_markdown ();
        });
        
        duplicate_menu.activate.connect (() => {
            Planner.database.insert_item (item.get_duplicate ());
        });

        delete_menu.activate.connect (() => {
            if (Planner.database.add_item_to_delete (item)) {
                get_style_context ().remove_class ("item-row-selected");
                main_revealer.reveal_child = false;
            }
        });
    }

    public void check_reminder_label (Objects.Reminder? reminder) {
        if (reminder != null) {
            reminder_label.label = "%s %s".printf (
                Planner.utils.get_relative_date_from_string (reminder.due_date),
                Planner.utils.get_relative_time_from_string (reminder.due_date)
            );
            reminder_revealer.reveal_child = true;
        } else {
            reminder_label.label = "";
            reminder_revealer.reveal_child = false;
        }
    }
}