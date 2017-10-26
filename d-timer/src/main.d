import std.stdio;
import std.process;
import std.algorithm;
import std.string;
import std.getopt;
import arsd.simpledisplay;
import slider;

pure nothrow Color createColor(ubyte r, ubyte g, ubyte b, ubyte a = 255) {
    Color c;
    c.asUint = (cast(uint)(a) << 24) | (cast(uint)(b) << 16) | (cast(uint)(g) << 8) | cast(uint)(r);
    return c;
}

enum clear_color      = createColor(0, 0, 0, 0);
enum bg_color         = createColor(41, 41, 41);
enum fg_color         = createColor(240 - 70, 235 - 70, 220 - 70);
enum fg_color2        = createColor(240 - 120, 235 - 120, 220 - 120);
enum fg_color3        = createColor(100, 100, 100);
enum text_shade_color = createColor(11, 11, 11);

void main(string[] args) {
    //immutable APP_NAME = args[0];

    string messageFormat = "%s";
    enum refreshRate     = 1000;
    int countdown        = 2 * 60 * 60;
    bool borderless      = false;

    void printHelp() {
        writeln("Simple timer to execute a provided command.");
        writeln("Usage:");
        writeln("d-timer [<option>...] <command> [<arg>]");
        writeln();

        writeln("Where:");
        writeln("  <command>      Command to execute.");
        writeln("  <arg>          Argument(s) of command.");
        writeln();

        writeln("<option>:");
        writeln("  -m             Message to display, use one %s place the coundown value.");
        writeln("  -c             Initial countdown in seconds.");
        writeln("  -b             Borderless window.");

        writeln("Example:");
        writeln("  d-timer -m 'In %s i will beep.' aplay beep.au");
    }

    if (args.length == 1) {
        writeln("Error: Too few arguments.");
        writeln();
        printHelp();
        return;
    }


    try {
        auto gres = getopt(args, std.getopt.config.passThrough, "message|m", &messageFormat, "countdown|c", &countdown, "borderless|b", &borderless);

        if (gres.helpWanted) {
            printHelp();
            return;
        }
    }
    catch (Exception ex) {
        writeln("Error: ", ex.msg);
        writeln();
        printHelp();
        return;
    }


    if (messageFormat.indexOf("%s") < 0) {
        writeln(messageFormat);
        writeln("Bad format of message text, must contain one %s.");
        return;
    }

    if (args.length == 1) {
        writeln("Missing command.");
        return;
    }

    const cmdWithArgs = args[1 .. $];
    writeln("Executing: ", cmdWithArgs, " after countdown.");


    //undecorated
    auto window = new SimpleWindow(512, 96, "d-timer: " ~ cmdWithArgs[0], OpenGlOptions.no, Resizability.fixedSize, ((borderless) ? WindowTypes.undecorated : WindowTypes.normal));


    Slider slider = Slider(60, 4 * 60 * 60, 60); // 1m - 4h
    slider.area = Rectangle(Point(30, 40), Size(window.width - 60, 32));
    slider.value = countdown;

    void redraw() {
        if (window.closed) return;

        auto painter = window.draw();
        //auto glyphSize = painter.textSize("0");

        painter.clear();
        painter.outlineColor = bg_color;
        painter.fillColor    = bg_color;
        painter.drawRectangle(Point(0, 0), window.width, window.height);

        painter.outlineColor = fg_color3;
        painter.drawRectangle(Point(1, 1), window.width - 1, window.height - 1);

        //painter.outlineColor = text_shade_color;
        //painter.drawRectangle(Point(2, 2), window.width - 3, window.height - 3);

        import std.format;
        import std.datetime;

        //auto dt = DateTime.now;
        immutable now = Clock.currTime();

        immutable ox = 0;
        immutable oy = 16;

        slider.render(painter);
        slider.onValueChanged = delegate(ref Slider s, float val) { countdown = cast(int) val; return true; };

        void drawText(string str, int x, int y, int w, int h, Color color, TextAlignment ta = TextAlignment.Left) {

            painter.outlineColor = text_shade_color;
            painter.drawText(Point(x + 1, y + 1), str, Point(w + 1, h + 1), ta);

            painter.outlineColor = color;
            painter.drawText(Point(x, y), str, Point(w, h), ta);
        }

        {
            int seconds = countdown;
            int mins    = cast(int)(seconds / 60);

            string str;

            if (mins >= 60) {
                int h = cast(int)(mins / 60);
                mins -= 60 * h;

                if (h > 1) {
                    str = format("%s hours %s minutes", h, mins);
                }
                else {
                    str = format("%s hour %s minutes", h, mins);
                }
            }
            else if (mins > 1) {
                str = format("%s minutes", mins);
            }
            else {
                str = format("%s seconds", seconds);
            }

            // TODO: Make the format more robust.
            try {
                str = format(messageFormat, str);
            }
            catch (Exception ex) {
                // hmmm?
            }

            drawText(str, ox, oy, window.width, window.height, fg_color, TextAlignment.Center);
        }

        drawText("Press [ESC] to cancel.", ox, window.height - 18, window.width - 8, window.height, fg_color3, TextAlignment.Right);

    }

    redraw();
    window.eventLoop(refreshRate, delegate() {
        //

        //if (!slider.isActive && slider.value > 0) slider.value = slider.value - refreshRate / 1000.0;
        countdown -= refreshRate / 1000.0;
        if (countdown >= slider.min && !slider.isActive) slider.value = countdown;

        if (countdown <= 0) {
            window.close();
        }

        redraw();
    }, delegate(KeyEvent ev) {
        // Close on any key.
        if (ev.pressed) {
            if (ev.key == Key.Escape) window.close();
        }

    }, delegate(MouseEvent ev) {

        // TODO: Redraw only if needed.

        auto mouseDown = (ev.type == MouseEventType.motion && (ev.modifierState & ModifierState.leftButtonDown));
        slider.update(Point(ev.x, ev.y), mouseDown);

        // FIXME
        if (ev.type == MouseEventType.buttonPressed) {
            enum wheelGain = 5 * 60;

            int t = countdown - (countdown % wheelGain);

            if (ev.button == MouseButton.wheelUp) {
                if (t + wheelGain < slider.max) {
                    countdown = t + wheelGain;
                }
                else {
                    countdown = cast(int)(slider.max);
                }
                slider.value = countdown;
            }
            if (ev.button == MouseButton.wheelDown) {
                if (t - wheelGain > slider.min) {
                    countdown = t - wheelGain;
                }
                else {
                    countdown = cast(int)(slider.min);
                }

                slider.value = countdown;
            }
        }

        redraw();
    });

    // If closed by countdown.
    if (countdown <= 0) {
        auto prcs = execute(cmdWithArgs);
        auto lines = lineSplitter(prcs.output);
        writeln(lines);
    }

}
