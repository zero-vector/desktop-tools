import std.stdio;
import std.process;

import std.string;
import std.format;

import std.algorithm.comparison;
import std.algorithm.searching;

import arsd.simpledisplay;
import arsd.color;

pragma(lib, "X11");

// X11 bindings
extern (C) nothrow @nogc {
    int XAllowEvents(Display* display, int event_mode, Time time);
    int XWindowEvent(Display* display, Window w, arch_long event_mask, XEvent* event_return);

    enum XC_circle    = 24;
    enum XC_crosshair = 34;
    enum XC_hand1     = 58;
    enum XC_target    = 128;

    Cursor XCreateFontCursor(Display* display, uint shape);

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

bool isWindowVisible(string windowId, out string className) {

    bool result = false;

    auto prcs = execute(["xprop", "-id", windowId]);

    auto lines = lineSplitter(prcs.output);

    foreach (l; lines) {
        if (canFind(l, "window state:")) {
            auto state = l[l.indexOf(":") + 1 .. $];
            state = strip(state);

            switch (state) {
            case WinState.Iconic:
                result = false;
                break;

            case WinState.Normal:
                result = true;
                break;

            default:
                // Ignore
                break;
            }

            //break;
        }

        if (canFind(l, "WM_CLASS")) {
            string s0, s1;
            formattedRead(l, `WM_CLASS(STRING) = "%s", "%s"`, &s0, &s1);
            className = s1;
        }

    }

    return result;
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

bool pickAndResizeWindow(float x, float y, float w, float h) {

    import std.algorithm.comparison;

    x = x.clamp(0.0, 0.9);
    y = y.clamp(0.0, 0.9);
    w = w.clamp(0.1, 1.0);
    h = w.clamp(0.1, 1.0);

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

    XID retwin = None;
    int pressed = 0; // count of number of buttons pressed
    int retbutton = -1; // button used to select window

    // TODO: Select with left button, cancel with other.
    loop: while (retwin == None || pressed != 0) {
        XEvent event;

        enum SyncPointer = 1;
        XAllowEvents(display, SyncPointer, CurrentTime);
        XWindowEvent(display, root, mask, &event);
        switch (event.type) {
        case EventType.ButtonPress:

            if (event.xbutton.button != 1) return false;
            if (retwin == None) {
                retbutton = event.xbutton.button;
                retwin = ((event.xbutton.subwindow != None) ? event.xbutton.subwindow : root);
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

    if (retwin && retwin != root) {
        sendMoveResizeEvent(retwin, cast(arch_ulong)(screenWidth * x), cast(arch_ulong)(screenHeight * y), cast(arch_ulong)(screenWidth * w), cast(arch_ulong)(screenHeight * h));
        XFlush(display);
    }

    return true;
}

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

    int currentDesktop;
    Window[] desktopWindows;
    int selectedWindowIdx = 0;

    void updateDesktopWindows() {

        selectedWindowIdx = 0;
        desktopWindows.length = 0;

        // 1. Check current desktop.
        {
            auto prcs = execute(["wmctrl", "-d"]);
            auto lines = lineSplitter(prcs.output);
            foreach (l; lines) {

                int desktop;
                string rest;
                formattedRead(l, "%d %s", &desktop, &rest);
                if (rest.startsWith("*")) currentDesktop = desktop;
            }

            //writeln("currentDesktop: ", currentDesktop);
        }

        // 2. Get only current desktopWindows.
        {

            auto prcs = execute(["wmctrl", "-l"]);
            auto lines = lineSplitter(prcs.output);
            foreach (l; lines) {

                string id;
                int desktop;
                string user;
                string name;
                string className;

                formattedRead(l, "%s %d %s %s", &id, &desktop, &user, &name);

                if (currentDesktop == desktop) {

                    auto isVisible = isWindowVisible(id, className);
                    if (isVisible) {
                        Window win = Window(id, name, className);
                        desktopWindows ~= win;
                    }
                }
            }

            //foreach (ref w; desktopWindows) writeln(w.id, " ", w.name);
        }
    }

    //updateDesktopWindows();

    // NOTE: Even 2 windows dont require a window?
    //if (desktopWindows.length < 2) return; // nothing to do

    // 3. Render & handle menu.

    auto window = new SimpleWindow(4, 4, "d-layout", OpenGlOptions.no, Resizability.allowResizing, WindowTypes.popupMenu, WindowFlags.dontAutoShow);

    auto screenWidth = DisplayWidth(XDisplayConnection.get(), 0);
    auto screenHeight = DisplayHeight(XDisplayConnection.get(), 0);

    auto glyphSize = window.draw().textSize("0");
    immutable winWidth = 800;

    updateDesktopWindows();
    auto winHeight = cast(int)(desktopWindows.length * (glyphSize.height + 5));
    window.moveResize((screenWidth - winWidth) / 2, (screenHeight - winHeight) / 2, winWidth, winHeight);
    window.show();
    window.focus();

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
        foreach (idx, ref w; desktopWindows) {

            painter.outlineColor = fg_color;

            if (selectedWindowIdx == idx) painter.outlineColor = comment_color;

            painter.drawText(Point(x, y), w.className ~ " | " ~ w.name, Point(window.width, window.height), TextAlignment.Left);

            y += glyphSize.height;
        }

    }

    window.windowResized = delegate(int w, int h) { redraw(); };

    redraw();

    immutable refreshRate = 100;
    bool cancelSelection = false;

    void focusSelectedWindow() {
        auto selectedWindowId = desktopWindows[selectedWindowIdx].id;
        auto prcs = execute(["wmctrl", "-i", "-a", selectedWindowId]);
    }

    window.eventLoop(refreshRate, delegate() { redraw(); }, delegate(KeyEvent ev) {

        if (ev.pressed) {

            if (ev.key == Key.Escape) {
                window.close();
                return;
            }
            else if (ev.key == Key.Enter) {

            }
            else if (ev.key == Key.Tab || ev.key == Key.Down) {
                selectedWindowIdx = cast(int)((selectedWindowIdx + 1) % desktopWindows.length);
            }
            else if (ev.key == Key.Up) {
                selectedWindowIdx -= 1;
                if (selectedWindowIdx < 0) selectedWindowIdx = (cast(int) desktopWindows.length) - 1;

            }
        }
        // Released
        else {
            if (ev.key == Key.Windows) {
                //focusSelectedWindow();
                if (!pickAndResizeWindow(0, 0, 0.5, 1.0)) return;
                if (!pickAndResizeWindow(0.5, 0, 0.5, 1.0)) return;
            }
        }

    }, delegate(MouseEvent ev) {
        //
        //writeln(ev);
    });

}
