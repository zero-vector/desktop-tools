module xft;

import arsd.simpledisplay;

version (linux) {
    version = X11;
}

version (X11) {

    pragma(lib, "Xft");

    // TODO: Alias types!!!
    struct XRenderColor {
        ushort red;
        ushort green;
        ushort blue;
        ushort alpha;
    }

    struct XftColor {
        ulong pixel;
        XRenderColor color;
    }

    extern (C) nothrow @nogc {

        struct XftPattern;
        struct XftDraw;

        struct FcCharSet;
        struct FcPattern;

        struct XftFont {
            int ascent;
            int descent;
            int height;
            int max_advance_width;
            FcCharSet* charset;
            FcPattern* pattern;
        }

        struct XGlyphInfo {
            ushort width;
            ushort height;
            short x;
            short y;
            short xOff;
            short yOff;
        }

        alias XftChar8 = const(char);
        alias XftChar16 = const(wchar);

        XftPattern* XftNameParse(const(char)* name);

        XftDraw* XftDrawCreate(Display* dpy, Drawable drawable, Visual* visual, Colormap colormap);
        void XftDrawDestroy(XftDraw* draw);

        // Parses an XLFD name and opens a font.
        XftFont* XftFontOpenXlfd(Display* dpy, int screen, const(char)* xlfd);
        XftFont* XftFontOpenName(Display* dpy, int screen, const(char)* xlfd);

        bool XftColorAllocValue(Display* dpy, Visual* visual, Colormap colormap, XRenderColor* color, XftColor* result);
        void XftColorFree(Display* dpy, Visual* visual, Colormap cmap, XftColor* color);

        void XftDrawStringUtf8(XftDraw* d, XftColor* color, XftFont* font, int x, int y, XftChar8* string, int len);

        void XftDrawRect(XftDraw* d, XftColor* color, int x, int y, uint width, uint height);

        void XftDrawChange(XftDraw* d, Drawable drawable);

        void XftTextExtentsUtf8(Display* dpy, XftFont* font, XftChar8* string, int len, XGlyphInfo* extents);

        //XTextWidth  -> XftTextExtents8 (...); width = extents.xOff;
        //XTextExtents    -> XftTextExtents8

    }
}
