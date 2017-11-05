module tokenizer;

import std.string;

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
