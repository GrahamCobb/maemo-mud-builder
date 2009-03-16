/* Hildon Vala Sample Code */
using GLib;
using Gtk;
using Hildon;

public class Sample : Hildon.Program {
        Hildon.Window window;
        Label label;
        Button button;
        
        construct {
                window = new Hildon.Window ();
                window.destroy += Gtk.main_quit;

                add_window (window);

                Environment.set_application_name ("Hildon Vala Sample");

                label = new Gtk.Label ("Vala for Hildon Desktop!");
                button = new Button.with_label ("Press Me!");

                button.clicked += btn => {
                    label.set_markup ("<big><b>Hello Vala!</b></big>");
                };

                var vbox = new Gtk.VBox (false, 2);

                vbox.pack_start (label, true, true, 2);
                vbox.pack_start (button, false, true, 2);

                window.add (vbox);
        }

        public void run () {
                window.show_all ();
                Gtk.main ();
        }

        static int main (string[] args) {
                Gtk.init (ref args);

                Sample app = new Sample ();
                app.run ();

                return 0;
        }
}
