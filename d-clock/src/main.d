import std.stdio;
import std.process;
import std.algorithm;

import arsd.simpledisplay;
import std.string;

//import std.file;
import std.algorithm.comparison;
import std.algorithm.searching;

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

    enum refreshRate     = 250;
    int remainingTime    = 10000;
    int unfocusedTime    = 1500;

    auto window = new SimpleWindow(256, 64, "d-clock", OpenGlOptions.no, Resizability.fixedSize, WindowTypes.popupMenu, WindowFlags.alwaysOnTop | WindowFlags.dontAutoShow);

    auto screenWidth = DisplayWidth(XDisplayConnection.get(), 0);
    auto screenHeight = DisplayHeight(XDisplayConnection.get(), 0);

    window.move((screenWidth - window.width) / 2, 40);
    window.show();
    window.focus();

    void redraw() {
        if (window.closed) return;

        // Check for keyboard focus,
        version (none) {
            Window focuswin;
            int revertwin;
            auto dpy = XDisplayConnection.get();
            auto win = window.impl.window;

            XGetInputFocus(dpy, &focuswin, &revertwin);
            if (focuswin != win) {
                if (remainingTime > unfocusedTime) remainingTime = unfocusedTime;
            }

        }

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

        {
            immutable str = format("%02d:%02d:%02d", now.hour, now.minute, now.second);

            painter.outlineColor = text_shade_color;
            painter.drawText(Point(1 + ox, 1 + oy), str, Point(window.width + 1, window.height + 1), TextAlignment.Center);

            painter.outlineColor = fg_color;
            painter.drawText(Point(ox, oy), str, Point(window.width, window.height), TextAlignment.Center);
        }

        {
            immutable str = format("%02d %s %s", now.day, now.month, now.year);

            painter.outlineColor = text_shade_color;
            painter.drawText(Point(1 + ox, 1 + oy + 16), str, Point(window.width + 1, window.height + 1 + 16), TextAlignment.Center);

            painter.outlineColor = fg_color2;
            painter.drawText(Point(ox, oy + 16), str, Point(window.width, window.height + 16), TextAlignment.Center);
        }
    }

    /+
    auto grabFocus() {
        auto dpy = XDisplayConnection.get();

        Window focuswin;
        int revertwin;

        auto win = window.impl.window;

        for (int i = 0; i < 100; ++i) {
            XGetInputFocus(dpy, &focuswin, &revertwin);

            if (focuswin == win) return;

            XSetInputFocus(dpy, win, RevertToParent, CurrentTime);

            import core.thread;
            Thread.sleep(dur!"msecs"(50));
        }
    }
    +/

    redraw();

    window.eventLoop(refreshRate, delegate() {

        redraw();

        if (!window.focused) {
            if (remainingTime > unfocusedTime) remainingTime = unfocusedTime;
        }

        remainingTime -= refreshRate;

        if (remainingTime <= 0) {
            window.close();
            return;
        }
    }, delegate(KeyEvent ev) {

        // Close on any key.
        if (ev.pressed) window.close();

    });
}
