import std.stdio;
import std.process;

import std.conv;
import std.string;
import std.format;

import std.algorithm.iteration;
import std.algorithm.comparison;
import std.algorithm.searching;

import arsd.simpledisplay;
import arsd.color;

pragma(lib, "X11");
pragma(lib, "Xmu");

// X11 bindings
extern (C) nothrow @nogc {
    int XAllowEvents(Display* display, int event_mode, Time time);
    int XWindowEvent(Display* display, Window w, arch_long event_mask, XEvent* event_return);

    enum XC_circle    = 24;
    enum XC_crosshair = 34;
    enum XC_hand1     = 58;
    enum XC_target    = 128;

    Cursor XCreateFontCursor(Display* display, uint shape);

    Window XmuClientWindow(Display *dpy, Window win);

}

pure nothrow Color createColor(ubyte r, ubyte g, ubyte b, ubyte a = 255) {
    Color c;
    c.asUint = (cast(uint)(a) << 24) | (cast(uint)(b) << 16) | (cast(uint)(g) << 8) | cast(uint)(r);
    return c;
}

enum clear_color      = createColor(0, 0, 0, 0);
enum text_shade_color = createColor(11, 11, 11);
enum bg_color         = createColor(41, 41, 41);
enum fg_color         = createColor(240 - 70, 235 - 70, 220 - 70);
enum fg_color2        = createColor(240 - 120, 235 - 120, 220 - 120);
enum comment_color    = createColor(255, 225, 46);
enum line_num_color   = createColor(100, 100, 100);

enum WinState {
    Iconic = "Iconic",
    Normal = "Normal",
}

void sendMoveResizeEvent(XID win, arch_ulong x, arch_ulong y, arch_ulong w, arch_ulong h) {

    auto display = XDisplayConnection.get();
    auto screen = DefaultScreen(display);
    auto root = RootWindow(display, screen);

    arch_ulong grflags = 0;
    if (x != -1) grflags |= (1 << 8);
    if (y != -1) grflags |= (1 << 9);
    if (w != -1) grflags |= (1 << 10);
    if (h != -1) grflags |= (1 << 11);

    XEvent e;
    e.xclient.type = EventType.ClientMessage;
    e.xclient.serial = 0;
    e.xclient.send_event = true;
    e.xclient.window = win;
    e.xclient.message_type = GetAtom!("_NET_MOVERESIZE_WINDOW", false)(display);
    e.xclient.format = 32;
    e.xclient.data.l[0] = grflags;
    e.xclient.data.l[1] = x;
    e.xclient.data.l[2] = y;
    e.xclient.data.l[3] = w;
    e.xclient.data.l[4] = h;

    auto res = XSendEvent(display, root, false, EventMask.SubstructureRedirectMask | EventMask.SubstructureNotifyMask, &e);
    //writefln("sendMoveResizeEvent: %s", res);
}

bool pickAndResizeWindow(double[][] windowDimensions) {

    foreach (ref wd; windowDimensions) {
        if (!pickAndResizeWindow(wd[0], wd[1], wd[2], wd[3])) return false;
    }

    return true;
}

// TODO: Ignore self window;
bool pickAndResizeWindow(double x, double y, double w, double h) {

    import std.algorithm.comparison;

    x = x.clamp(0.0, 0.9);
    y = y.clamp(0.0, 0.9);
    w = w.clamp(0.1, 1.0);
    h = h.clamp(0.1, 1.0);

    auto display = XDisplayConnection.get();
    auto screen = DefaultScreen(display);
    auto root = RootWindow(display, screen);

    auto screenWidth = DisplayWidth(XDisplayConnection.get(), 0);
    auto screenHeight = DisplayHeight(XDisplayConnection.get(), 0);

    XSync(display, 0);

    auto mask = EventMask.ButtonPressMask | EventMask.ButtonReleaseMask;

    auto cursor = XCreateFontCursor(display, XC_hand1);

    enum GrabSuccess = 0;
    auto res = XGrabPointer(display, root, false, mask, GrabMode.GrabModeSync, GrabMode.GrabModeAsync, None, cursor, CurrentTime) == GrabSuccess;

    if (!res) {
        // TODO: Exit with error.
        return false;
    }

    scope (exit) {
        XUngrabPointer(display, CurrentTime);
        XSync(display, 0);
    }

    XID targetWin = None;
    int pressed = 0; // count of number of buttons pressed
    int retbutton = -1; // button used to select window

    // TODO: Select with left button, cancel with other.
    while (targetWin == None || pressed != 0) {
        XEvent event;

        enum SyncPointer = 1;
        XAllowEvents(display, SyncPointer, CurrentTime);
        XWindowEvent(display, root, mask, &event);
        switch (event.type) {
        case EventType.ButtonPress:

            if (event.xbutton.button != 1) return false;
            if (targetWin == None) {
                retbutton = event.xbutton.button;
                targetWin = ((event.xbutton.subwindow != None) ? event.xbutton.subwindow : root);
            }
            pressed++;
            continue;
        case EventType.ButtonRelease:
            if (pressed > 0) pressed--;
            continue;
        default:
            break;
        }
    }

    if (targetWin && targetWin != root) {

        // I have no clue.
        int dummyi;
        uint dummy;
        if (XGetGeometry(display, targetWin, &root, &dummyi, &dummyi, &dummy, &dummy, &dummy, &dummy) && targetWin != root) {
            targetWin = XmuClientWindow(display, targetWin);
        }

        writefln("0x%.8x", cast(XID)targetWin);

        auto data =  cast(arch_ulong[]) getX11PropertyData(targetWin, GetAtom!("_NET_FRAME_EXTENTS", true)(display), XA_CARDINAL);
        writeln("_NET_FRAME_EXTENTS: ", data);

        arch_ulong titleHeight = 0;

        if (data.length == 4) {
            titleHeight = data[2];
        }

        writeln("titleHeight: ", titleHeight);

        arch_ulong wx = cast(arch_ulong)(screenWidth * x);
        arch_ulong wy = cast(arch_ulong)(screenHeight * y);

        arch_ulong ww = cast(arch_ulong)(screenWidth * w);
        arch_ulong wh = -titleHeight + cast(arch_ulong)(screenHeight * h);

        sendMoveResizeEvent(targetWin, wx, wy, ww, wh);
        XFlush(display);
    }

    return true;
}

immutable string[] layoutOptions =
[
"[1]|[1]             (Horizontal Split)",
"[1]-[1]             (Vertical Split)" ,
"[1]|[[1]-[1]]",
"[[1]-[1]]|[1]",
"[[1]-[1]]|[[1]-[1]] (Four windows)",
];

void main(string[] args) {

    void printHelp() {
        writeln("Simple window switcher.");
    }

    struct Window {
        string id;
        string name;
        string className;

        this(string id, string name, string className) {
            this.id        = id;
            this.name      = name;
            this.className = className;
        }
    }

    // NOTE: Even 2 windows dont require a window?
    //if (desktopWindows.length < 2) return; // nothing to do

    // 3. Render & handle menu.

    auto window = new SimpleWindow(4, 4, "d-layout", OpenGlOptions.no, Resizability.fixedSize, WindowTypes.normal, WindowFlags.dontAutoShow);

    auto screenWidth = DisplayWidth(XDisplayConnection.get(), 0);
    auto screenHeight = DisplayHeight(XDisplayConnection.get(), 0);

    auto maxStringIdx = layoutOptions.maxIndex!"a.length < b.length";
    auto maxString = layoutOptions[maxStringIdx];

    auto glyphSize = window.draw().textSize(maxString);

    enum fontFix = 1.5; // wtf

    int winWidth = cast(int)(glyphSize.width * fontFix);
    int winHeight = cast(int)(layoutOptions.length * (glyphSize.height + 5));

    window.show();
    //window.focus();

    window.moveResize((screenWidth - winWidth) / 2, (screenHeight - winHeight) / 2, winWidth, winHeight);

    // Hack: Normal window & centered.
    //sendMoveResizeEvent(window.impl.window, (screenWidth - winWidth) / 2, (screenHeight - winHeight) / 2, winWidth, winHeight);

    auto display = XDisplayConnection.get();

    int selectedOptionIdx = 0;

    void redraw() {
        if (window.closed) return;
        if (window.hidden) return;

        auto painter = window.draw();

        painter.clear();
        painter.outlineColor = bg_color;
        painter.fillColor    = bg_color;
        painter.drawRectangle(Point(0, 0), window.width, window.height);

        painter.outlineColor = line_num_color;
        painter.drawRectangle(Point(1, 1), window.width - 2, window.height - 2);

        int x = 4;
        int y = 4;
        foreach (idx, ref o; layoutOptions) {
            painter.outlineColor = fg_color;

            if (selectedOptionIdx == idx) painter.outlineColor = comment_color;

            painter.drawText(Point(x, y), to!string(idx) ~ ". " ~ o, Point(window.width, window.height), TextAlignment.Left);
            y += glyphSize.height;
        }

    }

    window.windowResized = delegate(int w, int h) { redraw(); };

    redraw();

    immutable refreshRate = 100;
    bool cancelSelection = false;

    window.eventLoop(refreshRate, delegate() { redraw(); }, delegate(KeyEvent ev) {

        if (ev.pressed) {

            if (ev.key == Key.Escape) {
                window.close();
                return;
            }
            else if (ev.key == Key.Enter) {

                // Do something that is actually manageable.
                if (selectedOptionIdx == 0) {
                    pickAndResizeWindow([[0, 0, 0.5, 1.0], [0.5, 0, 0.5, 1.0]]);
                }
                else if (selectedOptionIdx == 1) {
                    pickAndResizeWindow([[0, 0, 1.0, 0.5], [0, 0.5, 1.0, 0.5]]);
                }
                else if (selectedOptionIdx == 2) {
                    pickAndResizeWindow([[0, 0, 0.5, 1.0], [0.5, 0.0, 0.5, 0.5], [0.5, 0.5, 0.5, 0.5]]);
                }
                else if (selectedOptionIdx == 3) {
                    pickAndResizeWindow([[0.0, 0.0, 0.5, 0.5], [0.0, 0.5, 0.5, 0.5], [0.5, 0, 0.5, 1.0]]);
                }
                else if (selectedOptionIdx == 4) {
                    pickAndResizeWindow([[0.0, 0.0, 0.5, 0.5], [0.0, 0.5, 0.5, 0.5], [0.5, 0, 0.5, 0.5], [0.5, 0.5, 0.5, 0.5]]);
                }
            }
            else if (ev.key == Key.Down) {
                selectedOptionIdx = cast(int)((selectedOptionIdx + 1) % layoutOptions.length);
            }
            else if (ev.key == Key.Up) {
                selectedOptionIdx -= 1;
                if (selectedOptionIdx < 0) selectedOptionIdx = (cast(int) layoutOptions.length) - 1;
            }
        }
        // Released
        else {
            if (ev.key == Key.Windows) {
            }
        }

    }, delegate(MouseEvent ev) {
        //
        //writeln(ev);
    });

}
