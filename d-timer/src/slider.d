module slider;
import arsd.color;
import arsd.simpledisplay;

private:
T clamp(T)(T v, T min, T max) {
    return ((v < min) ? min : ((v > max) ? max : v));
}

T abs(T)(T v) {
    return (v < 0) ? -v : v;
}

public:

struct Slider {

    Rectangle area;

    bool isHot;
    bool isActive;

    bool dragInProgress = false;
    Point lastMousePos;

    float _value;

    float _min;
    float _max;
    float _step;

    float _gripSize;

    @property {
        auto value() {
            return _value;
        }

        auto value(float v) {
            _value = clamp(v, _min, _max);
        }

        auto min() {
            return _min;
        }

        auto min(float v) {
            _min = v;
        }

        auto max() {
            return _max;
        }

        auto max(float v) {
            _max = v;
        }

        auto step() {
            return _step;
        }

        auto step(float v) {
            _step = v;
        }
    }

    this(float min, float max, float step = 0) {
        this.min  = min;
        this.max  = max;
        this.step = step;
        this.value = min;
    }

    void update(Point mousePos, bool buttonDown) {

        isHot = area.contains(mousePos);
        isActive = (isHot && buttonDown) || (dragInProgress && buttonDown);

        float _rawValue;
        bool has_changed = false;

        if (isActive) {

            if (!dragInProgress) dragInProgress = true;

            float new_value = 0f;

            float frac = ((mousePos.x) - area.left) / cast(float) area.width;
            new_value = min + frac * (max - min);

            if (new_value < min) new_value = min;
            if (new_value > max) new_value = max;

            if (_value != new_value) {
                _value = new_value;
                has_changed = true;
            }

        }
        else {
            dragInProgress = false;
        }
    }



    void render(ref ScreenPainter painter) {

        enum c0 = Color(75, 75, 0);
        enum c1 = Color(215, 215, 0);

        float slider_half_w = 10;

        float frac = (value - min) / (max - min);
        float slider_pos_x = area.left + area.width * frac;

        // Draw grip
        painter.outlineColor = Color.transparent;
        painter.fillColor = Color.transparent;



        {

            int w = cast(int)(area.width * frac);
            int h = 8;

            int x = area.upperLeft.x + cast(int)(slider_half_w);
            int y = area.upperLeft.y + (area.height - h) / 2;

            // Draw rest
            painter.fillColor = c0;
            painter.outlineColor = Color.transparent;
            painter.drawRectangle(Point(x, y), area.width - cast(int)(slider_half_w), h);

            // Draw value
            painter.fillColor = c1;
            painter.drawRectangle(Point(x, y), w, h);
        }

        // Knob
        {
            painter.fillColor = c1;
            painter.outlineColor = Color.transparent;

            int w = cast(int)(slider_half_w * 2.0);
            int h = cast(int)(slider_half_w * 2.0);

            int x = area.upperLeft.x + cast(int)(slider_pos_x - slider_half_w);
            int y = area.upperLeft.y + (area.height - h) / 2;
            //int w = cast(int)(2 * slider_half_w);

            painter.drawRectangle(Point(x, y), w, h);
        }

    }

}
