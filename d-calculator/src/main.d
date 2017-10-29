import std.stdio;
import std.string;
import std.conv;

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

auto getSymbol(string symbol) {
    struct SymbolAttr {
        bool right_associative;
        bool is_binary;
        bool is_unary;
        int precedence;
    }

    SymbolAttr atr;
    if (symbol == "*") {
        atr.is_binary = true;
        atr.right_associative = true;
        atr.precedence = 13;
    }
    else if (symbol == "/") {
        atr.is_binary = true;
        atr.right_associative = true;
        atr.precedence = 13;
    }
    else if (symbol == "+") {
        atr.is_binary = true;
        atr.right_associative = true;
        atr.precedence = 12;
    }
    else if (symbol == "-") {
        atr.is_binary = true;
        atr.right_associative = true;
        atr.precedence = 12;
    }

    // TODO: ^ (pow)

    return atr;
}

struct Tokenizer {

    string text;

    this(string text) {
        this.text = text; // Is a this copy? (prolly no)
    }

    void advance(ptrdiff_t size) {
        foreach (i; 0 .. size) {
            if (text.empty) break;
            text = text[1 .. $];
        }
    }

    Token peekNextToken() {
        string tmp = text;
        auto tok = getNextToken();
        text = tmp;
        return tok;
    }

    Token getNextToken() {

        if (text.empty) return Token(Token.Type.end_of_input);

        Token token;

        scope(exit) {
            //writeln(token);
        }

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

        return token;
    }
}

Expression parseExpression(ref Tokenizer tokenizer) {
    writeln("parseExpression");

    Expression e = parseTerm(tokenizer);

    while(true) {

        auto tok = tokenizer.peekNextToken();

        if (tok.type == Token.Type.symbol && (tok.str == "+")) {
            tokenizer.getNextToken();
            e = new AddExpression(e, parseExpression(tokenizer));
        }
        else if (tok.type == Token.Type.symbol && (tok.str == "-")) {
            tokenizer.getNextToken();
            e = new SubExpression(e, parseExpression(tokenizer));
        }
        else {
            return e;
        }
    }
}

Expression parseTerm(ref Tokenizer tokenizer) {
    writeln("parseTerm");

    Expression e = parseFactor(tokenizer);

    while(true) {

        auto tok = tokenizer.peekNextToken();

        if (tok.type == Token.Type.symbol && (tok.str == "*")) {
            tokenizer.getNextToken();
            e = new MulExpression(e, parseExpression(tokenizer));
        }
        else if (tok.type == Token.Type.symbol && (tok.str == "/")) {
            tokenizer.getNextToken();
            e = new DivExpression(e, parseExpression(tokenizer));
        }
        else {
            return e;
        }
    }

    assert(0);

}

Expression parseFactor(ref Tokenizer tokenizer) {
    writeln("parseFactor");

    auto tok = tokenizer.peekNextToken();

    if (tok.type == Token.Type.symbol && (tok.str == "+")) {
        tokenizer.getNextToken();
        return parseFactor(tokenizer);
    }

    if (tok.type == Token.Type.symbol && (tok.str == "-")) {
        tokenizer.getNextToken();
        return new NegExpression(parseFactor(tokenizer));
    }

    if (tok.type == Token.Type.symbol && (tok.str == "(")) {
        tokenizer.getNextToken();
        auto e = new ParentheticalExpression(parseExpression(tokenizer));
        // eat ')'
        tokenizer.getNextToken();

        return e;
    }

    if (tok.type == Token.Type.int_number) {
        tokenizer.getNextToken();
        auto v = to!int(tok.str);
        return new NumberExpression(v);
    }

    if (tok.type == Token.Type.float_number) {
        tokenizer.getNextToken();
        auto v = to!double(tok.str);
        return new NumberExpression(v);
    }

    // throw Exception

    assert(0);
}

/+
Expression parseExpression(ref Tokenizer tokenizer) {

    Expression ret = null;

    while (true) {
        auto tok = tokenizer.getNextToken();

        if (tok.type == Token.Type.identifier) {
            writeln("Identifier: ", tok.str);
        }
        else if (tok.type == Token.Type.symbol) {
            writeln("Symbol:    ", tok.str);

            if (tok.str == "(") {
                auto e = new ParentheticalExpression(parseExpression(tokenizer));
                ret = e;
            }
            else if (tok.str == ")") {
                break;
            }
            else if (tok.str == "+") {
                auto e = new AddExpression(ret, parseExpression(tokenizer));
                ret = e;
                break;
            }
            else if (tok.str == "-") {

                if (ret is null) {
                    auto e = new NegExpression(parseExpression(tokenizer));
                    ret = e;
                }
                else {
                    auto e = new SubExpression(ret, parseExpression(tokenizer));
                    ret = e;
                }

                break;
            }
            else if (tok.str == "*") {
                auto e = new MulExpression(ret, parseExpression(tokenizer));
                ret = e;
                break;
            }

        }
        else if (tok.type == Token.Type.int_number) {
            int v = to!int(tok.str);
            writeln("Integer:    ", v);
            auto e = new NumberExpression(v);
            ret = e;
        }
        else if (tok.type == Token.Type.float_number) {
            double v = to!double(tok.str);
            writeln("Float:      ", v);
            auto e = new NumberExpression(v);
            ret = e;
        }
        else if (tok.type == Token.Type.end_of_input) {
            break;
        }
        else {
            // Error/Exception?
            break;

        }
    }

    return ret;
}
+/

void main() {

    writeln("d-calculator");

    version (none) {
        Expression n0 = new NumberExpression(3);
        Expression n1 = new NumberExpression(4);
        Expression n2 = new NegExpression(n1);

        Expression e0 = new MulExpression(n0, n1);
        Expression e1 = new AddExpression(new NumberExpression(2), e0);

        {
            auto res = e1.getValue;
            writeln(res);
        }

        {
            auto res = n2.getValue;
            writeln(res);
        }
    }

    while (true) {
        string expression = readln();

        if (expression[0] == '\n') break;

        Tokenizer tokenizer = Tokenizer(expression);

        auto e = parseExpression(tokenizer);
        auto res = e.getValue;
        writeln(res);

    }

    writeln("bye");

}
