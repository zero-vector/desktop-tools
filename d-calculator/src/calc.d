module calc;

import std.conv;
import tokenizer;
import ast;

auto eval(string expression) {
    Tokenizer tokenizer = Tokenizer(expression);
    auto res = parseExpression(tokenizer).getValue();
    return res;
}

private:

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
        auto v = to!long(tok.current.str);
        return new NumberExpression(v);
    }

    if (tok.eatIfEqual(Token.Type.float_number)) {
        auto v = to!real(tok.current.str);
        return new NumberExpression(v);
    }

    throw new Exception("Parser error.");

    //assert(0);
}
