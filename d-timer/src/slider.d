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

    bool delegate(ref Slider, float) onValueChanged;

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

            new_value = new_value.clamp(min, max);

            if (step > 0 && new_value != min) {
                auto delta = (new_value - _value);
                if (abs(delta) >= step) {
                    _value += step * cast(int)(delta / step);
                }

                has_changed = (abs(delta) >= step);
            }
            else {
                if (_value != new_value) {
                    _value = new_value;
                    has_changed = true;
                }
            }

        }
        else {
            dragInProgress = false;
        }

        if (has_changed) {
            if (onValueChanged) onValueChanged(this, _value);
        }
    }

    void render(ref ScreenPainter painter) {

        enum c0 = Color(75, 75, 0);
        enum c1 = Color(215, 215, 0);
        enum shade = Color(33, 33, 33);

        int slider_half_w = 8;

        float frac       = (value - min) / (max - min);
        int slider_pos_x = cast(int)(area.left + area.width * frac);

        painter.outlineColor = Color.transparent;
        painter.fillColor = Color.transparent;

        // Slider
        {
            int w = cast(int)(area.width * frac);
            int h = 8;

            if (w < 2) w = 2;

            int x = area.upperLeft.x;
            int y = area.upperLeft.y + (area.height - h) / 2;

            // draw shade
            //painter.fillColor = shade;
            //painter.drawRectangle(Point(x, y + 1), area.width, h);

            // Draw rest
            painter.fillColor = c0;
            painter.drawRectangle(Point(x, y), area.width, h);

            // Draw value
            painter.fillColor = c1;
            painter.drawRectangle(Point(x, y), w, h);
        }

        // Knob
        {
            painter.fillColor = c1;

            int w = slider_half_w * 2;
            int h = slider_half_w * 2;

            int x = slider_pos_x - slider_half_w;
            int y = area.upperLeft.y + (area.height - h) / 2;

            // draw shade
            //painter.fillColor = shade;
            //painter.drawRectangle(Point(x, y + 1), w, h);

            painter.fillColor = c1;
            painter.drawRectangle(Point(x, y), w, h);
        }

    }

}
