import std.stdio;
import std.process;
import std.algorithm;

import arsd.simpledisplay;
import std.string;

//import std.file;
import std.algorithm.comparison;
import std.algorithm.searching;

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

    enum refreshRate     = 1000;

    auto window = new SimpleWindow(512, 96, "d-timer", OpenGlOptions.no, Resizability.fixedSize);

    auto screenWidth = DisplayWidth(XDisplayConnection.get(), 0);
    auto screenHeight = DisplayHeight(XDisplayConnection.get(), 0);

    Slider slider = Slider(0, 100);
    slider.area = Rectangle(Point(10, 40), Size(window.width - 20, 32));
    slider.value = 50;

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


        {
            immutable str = format("%.3f", slider.value);

            //painter.outlineColor = text_shade_color;
            //painter.drawText(Point(1 + ox, 1 + oy), str, Point(window.width + 1, window.height + 1), TextAlignment.Center);

            painter.outlineColor = fg_color;
            painter.drawText(Point(ox, oy), str, Point(window.width, window.height), TextAlignment.Center);
        }

        /+
        {
            immutable str = format("%02d %s %s", now.day, now.month, now.year);

            painter.outlineColor = text_shade_color;
            painter.drawText(Point(1 + ox, 1 + oy + 16), str, Point(window.width + 1, window.height + 1 + 16), TextAlignment.Center);

            painter.outlineColor = fg_color2;
            painter.drawText(Point(ox, oy + 16), str, Point(window.width, window.height + 16), TextAlignment.Center);
        }
        +/
    }

    redraw();
    window.eventLoop(refreshRate, delegate() {
        //

        if (!slider.isActive && slider.value > 0) slider.value = slider.value - refreshRate / 1000.0;

        if (slider.value <= 0) {

            window.close();
        }


        redraw();
    }, delegate(KeyEvent ev) {
        // Close on any key.
        if (ev.pressed) {
            if (ev.key == Key.Escape) window.close();
        }

    }, delegate(MouseEvent ev) {
        //
        auto mouseDown = (ev.type == MouseEventType.motion && (ev.modifierState & ModifierState.leftButtonDown));
        slider.update(Point(ev.x, ev.y), mouseDown);
        redraw();
    });



    //auto prcs = execute(["systemctl", "suspend"]);
    //auto lines = lineSplitter(prcs.output);
    //writeln(lines);


}
