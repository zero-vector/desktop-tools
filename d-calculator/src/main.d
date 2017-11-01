import std.stdio;
import std.string;
import std.format;
import std.conv;
import std.utf;
import arsd.simpledisplay;
import xft;
import ast;

struct Token {

    enum Type {
        unknown,
        identifier,
        symbol,
        int_number,
        float_number,
        end_of_input,
    }

    Type type;
    string str;
}

private enum string[] symbols = ["(", ")", "^", "+", "-", "*", "/", "=", "%"];

struct Tokenizer {

    string text;

    private Token _current;

    @property current() {
        return _current;
    }

    this(string text) {
        this.text = text; // Is a this copy? (prolly no)
    }

    void advance(ptrdiff_t size) {
        foreach (i; 0 .. size) {
            if (text.empty) break;
            text = text[1 .. $];
        }
    }

    bool eatIfEqual(Token.Type type, string str = null) {

        //if (current.type == Token.Type.end_of_input) return false;
        //if (current.type == Token.Type.unknown) return false;

        //writeln("searching for: ", type);

        auto tmpTok = _current;
        auto tmpTxt = text;
        next();

        if (current.type == type) {

            if (str is null) return true;

            if (str !is null && current.str == str) {
                return true;
            }
        }

        _current = tmpTok;
        text = tmpTxt;

        return false;
    }

    void next() {

        scope (exit) {
            //writeln(current);
        }

        if (text.empty) {
            _current = Token(Token.Type.end_of_input);
            return;
        }

        Token token;

        while (text.length) {

            auto ch = text[0];
            if (ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r') {
                advance(1);
                continue;
            }
            else if (ch >= '0' && ch <= '9') {
                int pos;
                bool sawDot;
                while (pos < text.length && ((text[pos] >= '0' && text[pos] <= '9') || text[pos] == '.')) {
                    if (text[pos] == '.') {
                        if (sawDot) break;
                        else sawDot = true;
                    }

                    pos++;
                }

                token.type = sawDot ? Token.Type.float_number : Token.Type.int_number;
                token.str = text[0 .. pos];
                advance(pos);
            }
            else if ((ch >= 'a' && ch <= 'z') || (ch == '_') || (ch >= 'A' && ch <= 'Z')) {
                token.type = Token.Type.identifier;
                int pos;
                while (pos < text.length && ((text[pos] >= 'a' && text[pos] <= 'z') || (text[pos] == '_') || (text[pos] >= 'A' && text[pos] <= 'Z') || (text[pos] >= '0' && text[pos] <= '9'))) {
                    pos++;
                }

                token.str = text[0 .. pos];
                advance(pos);

            }
            else {
                bool found = false;
                foreach (symbol; symbols) {
                    if (text.length >= symbol.length && text[0 .. symbol.length] == symbol) {
                        found = true;
                        token.type = Token.Type.symbol;
                        token.str = symbol;
                        advance(symbol.length);
                        break;
                    }
                }

                if (!found) {
                    throw new Exception("unknown token " ~ text[0]);
                }
            }

            break;
        }

        _current = token;

        //return token;
    }
}

Expression parseExpression(ref Tokenizer tok) {

    Expression e = parseTerm(tok);

    while (true) {

        if (tok.eatIfEqual(Token.Type.symbol, "+")) {
            e = new AddExpression(e, parseExpression(tok));
        }
        else if (tok.eatIfEqual(Token.Type.symbol, "-")) {
            e = new SubExpression(e, parseExpression(tok));
        }
        else {
            //tok.next();
            return e;
        }
    }
}

Expression parseTerm(ref Tokenizer tok) {

    Expression e = parseFactor(tok);

    while (true) {

        if (tok.eatIfEqual(Token.Type.symbol, "*")) {
            e = new MulExpression(e, parseExpression(tok));
        }
        else if (tok.eatIfEqual(Token.Type.symbol, "/")) {
            e = new DivExpression(e, parseExpression(tok));
        }
        else {
            //tok.next();
            return e;
        }
    }

    assert(0);

}

Expression parseFactor(ref Tokenizer tok) {

    if (tok.eatIfEqual(Token.Type.symbol, "+")) {
        return parseFactor(tok);
    }

    if (tok.eatIfEqual(Token.Type.symbol, "-")) {
        return new NegExpression(parseFactor(tok));
    }

    if (tok.eatIfEqual(Token.Type.symbol, "(")) {
        auto e = new ParentheticalExpression(parseExpression(tok));

        if (!tok.eatIfEqual(Token.Type.symbol, ")")) {
            assert(0); // TODO: Format exception.
        }

        return e;
    }

    if (tok.eatIfEqual(Token.Type.int_number)) {
        auto v = to!int(tok.current.str);
        return new NumberExpression(v);
    }

    if (tok.eatIfEqual(Token.Type.float_number)) {
        auto v = to!double(tok.current.str);
        return new NumberExpression(v);
    }

    // throw Exception

    assert(0);
}

pure nothrow Color createColor(ubyte r, ubyte g, ubyte b, ubyte a = 255) {
    Color c;
    c.asUint = (cast(uint)(a) << 24) | (cast(uint)(b) << 16) | (cast(uint)(g) << 8) | cast(uint)(r);
    return c;
}

enum clear_color      = createColor(0, 0, 0, 0);
enum text_shade_color = createColor(211, 211, 211);
enum comment_color    = createColor(21, 21, 21);
enum line_num_color   = createColor(100, 100, 100);

enum bg_color         = createColor(33, 33, 33);
enum fg_color         = createColor(250, 200, 10);
enum fg_color2        = createColor(120, 120, 120);
enum fg_color3        = createColor(100, 100, 100);

void main() {

    string[] lines;

    int carret_pos        = 0;
    int input_text_length = 0;
    char[80] input_text   = '\0';

    auto window = new SimpleWindow(Size(800, 600), "d-calculator");

    auto display = XDisplayConnection.get;
    auto xftFont = XftFontOpenName(display, 0, "Source Code Pro:Bold:pixelsize=18");
    if (xftFont is null) {
        writeln("fuck");
    }

    writeln("XFT Metrics");
    writeln("XFT Ascent      : ", xftFont.ascent);
    writeln("XFT Descent     : ", xftFont.descent);
    writeln("XFT Height:     : ", xftFont.height);
    writeln("XFT Max_advance : ", xftFont.max_advance_width);

    //auto xftdraw = XftDrawCreate(XDisplayConnection.get, window.impl.window, DefaultVisual(display, 0), DefaultColormap(display, 0));

    //auto xftdraw = XftDrawCreate(display, window.impl.window, DefaultVisual(display, 0), DefaultColormap(display, 0));
    //scope(exit) {
    //    XftDrawDestroy(xftdraw);
    //}

    int padding = 8;
    auto input_area_height = xftFont.height + 2 * padding;
    auto text_area_height = window.height - input_area_height;

    void redrawInput(ref ScreenPainter painter) {

        if (window.closed) return;

        //version (none)

        painter.outlineColor = line_num_color;
        painter.fillColor    = bg_color;
        painter.drawRectangle(Point(0, text_area_height), window.width, input_area_height);

        // XFT
        {
            auto nativeDisplay = painter.impl.d;
            auto xftdraw = XftDrawCreate(display, nativeDisplay, DefaultVisual(display, 0), DefaultColormap(display, 0));
            scope (exit) XftDrawDestroy(xftdraw);

            XRenderColor renderColor;
            renderColor.red   = cast(ushort)((fg_color.r / 255.0) * 0xFFFF);
            renderColor.green = cast(ushort)((fg_color.g / 255.0) * 0xFFFF);
            renderColor.blue  = cast(ushort)((fg_color.b / 255.0) * 0xFFFF);
            renderColor.alpha = 0xFFFF;

            XftColor xftColor;
            XftColorAllocValue(display, DefaultVisual(display, 0), DefaultColormap(display, 0), &renderColor, &xftColor);
            scope (exit) XftColorFree(display, DefaultVisual(display, 0), DefaultColormap(display, 0), &xftColor);

            // Command text area.
            Point strPos = Point(padding, text_area_height + xftFont.ascent + padding);
            XftDrawStringUtf8(xftdraw, &xftColor, xftFont, strPos.x, strPos.y, input_text[0 .. input_text_length].ptr, input_text_length);

            // Previous results.
            {
                int y = text_area_height - padding;
                foreach_reverse (resultLine; lines) {
                    XftDrawStringUtf8(xftdraw, &xftColor, xftFont, strPos.x, y, resultLine.ptr, cast(int)resultLine.length);
                    y -= xftFont.height;

                    if (y < -xftFont.height ) break;
                }
            }

            // Carret
            {
                XGlyphInfo extents = void;
                XftTextExtentsUtf8(display, xftFont, input_text[0 .. input_text_length].ptr, carret_pos, &extents);

                //auto cp = Point((carret_pos + 1) * xftFont.max_advance_width, 280 - xftFont.ascent);
                auto cp = Point(strPos.x + extents.xOff, strPos.y - xftFont.ascent);
                auto cp2 = Point(cp.x, cp.y + xftFont.height);

                painter.outlineColor = fg_color;
                //painter.drawLine(Point(cp.x, cp.y), Point(cp2.x, cp2.y));
                painter.drawRectangle(cp, 2, xftFont.height);
            }

        }

        version (none) {
            auto glyphSize = painter.textSize("0");

            painter.outlineColor = line_num_color;
            painter.fillColor    = bg_color;
            painter.drawRectangle(Point(0, text_area_height), window.width, input_area_height);

            painter.outlineColor = fg_color;
            painter.drawText(Point(4, text_area_height + 2), input_text[0 .. input_text_length]);

            {
                auto cp = Point(4 + carret_pos * glyphSize.width, text_area_height + 3);
                auto cp2 = Point(cp.x, cp.y + glyphSize.height - 6);

                painter.outlineColor = fg_color;
                painter.drawLine(cp, cp2);
                painter.outlineColor = bg_color;
                painter.drawLine(Point(cp.x + 1, cp.y), Point(cp2.x + 1, cp2.y));
            }
        }
    }

    void redraw() {
        if (window.closed) return;

        auto painter = window.draw();

        painter.clear();

        painter.outlineColor = bg_color;
        painter.fillColor    = bg_color;
        painter.drawRectangle(Point(0, 0), window.width, window.height);

        painter.outlineColor = fg_color3;
        painter.drawRectangle(Point(1, 1), window.width - 1, window.height - 1);

        redrawInput(painter);
    }

    //redraw();

    // -------- TEXT INPUT

    // TODO: Handle Utf8!!!
    auto add_input_text_dch(dchar dch) {

        if (!isValidDchar(dch)) return;

        if (dch >= ' ' && dch <= '~') {
            if (input_text_length < input_text.length) {

                // Push rest right.
                if (carret_pos < input_text_length) {
                    // TODO: Optimize (add front & back buffer).
                    for (int idx = input_text_length; idx > carret_pos; idx--) {
                        input_text[idx] = input_text[idx - 1];
                    }
                }

                char ch = cast(char) dch;
                input_text[carret_pos] = ch;
                carret_pos += 1;
                input_text_length += 1;
            }
        }
    }

    auto delete_left_input_text() {

        if (!input_text_length) return;
        if (!carret_pos) return;

        if (carret_pos == input_text.length) {
            carret_pos -= 1;
            input_text_length -= 1;
            return;
        }

        // TODO: Optimize (add front & back buffer).
        for (int idx = carret_pos - 1; idx < input_text_length; idx++) {
            input_text[idx] = input_text[idx + 1];
        }

        carret_pos -= 1;
        input_text_length -= 1;
    }

    auto delete_input_text() {

        if (!input_text_length) return;
        if (input_text_length == carret_pos) return;

        // TODO: Optimize (add front & back buffer).
        for (int idx = carret_pos; idx < input_text_length; idx++) {
            input_text[idx] = input_text[idx + 1];
        }
        input_text_length -= 1;
    }

    auto add_input_text(in char[] p_txt) {

        writeln(p_txt);

        auto utf8 = toUTF8(p_txt);
        foreach (ch; utf8) add_input_text_dch(ch);
    }

    // dfmt off
    window.eventLoop(10,
        delegate() {
            redraw();
            },
        delegate(dchar c) {
            add_input_text_dch(c);
            redraw();
        },
        delegate(KeyEvent ev) {
            if (ev.pressed) {
                bool input_chaged = false;

                if (ev.key == Key.Escape) {
                    window.close();
                    return;
                }

                if (ev.key == Key.Home) {
                    carret_pos = 0;
                    input_chaged = true;
                }

                if (ev.key == Key.End) {
                    carret_pos = input_text_length;
                    input_chaged = true;
                }

                if (ev.key == Key.Right) {
                    carret_pos += 1;
                    if (carret_pos > input_text_length) carret_pos = input_text_length;
                    input_chaged = true;
                }

                if (ev.key == Key.Left) {
                    carret_pos -= 1;
                    if (carret_pos < 0) carret_pos = 0;
                    input_chaged = true;
                }

                if (ev.key == Key.V && (ev.modifierState & ModifierState.ctrl)) {

                    enum dlg = delegate(in char[] pasted_text) {
                        add_input_text(pasted_text);
                        redraw();
                    };

                    getClipboardText(window, dlg);
                }

                if (ev.key == Key.Enter || ev.key == Key.PadEnter) {

                    auto expression = cast(string) input_text[0 .. input_text_length];

                    Tokenizer tokenizer = Tokenizer(expression);
                    auto e = parseExpression(tokenizer);
                    auto res = e.getValue;
                    writeln(res);

                    char[256] buf;
                    sformat(buf[], "%s", res);

                    string s = buf.idup;

                    // TODO: Reformat expression from ast.
                    lines ~= expression.idup ~ " = " ~ buf.idup;

                    carret_pos        = 0;
                    input_text_length = 0;
                    input_chaged      = true;
                }

                if (ev.key == Key.Delete) {
                    if (ev.modifierState & ModifierState.shift) {
                        carret_pos        = 0;
                        input_text_length = 0;
                    }
                    else {
                        delete_input_text();
                    }

                    input_chaged      = true;
                }

                if (ev.key == Key.Backspace) {
                    delete_left_input_text();
                    input_chaged      = true;
                }

                if (input_chaged) redraw();
            }
        },
        delegate(MouseEvent ev) {
        //if (ev.type == MouseEventType.buttonPressed) {
        //    if (ev.button == MouseButton.wheelUp && yScroll > 0)
        //        yScroll--;
        //    if (ev.button == MouseButton.wheelDown && yScroll < lines.length)
        //        yScroll++;
        //    redraw();
        //}
        }
    );
    // dfmt on

    writeln("bye");
}
