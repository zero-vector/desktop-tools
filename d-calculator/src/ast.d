module ast;

import std.stdio;


alias FloatType = real;
alias IntType = long;

class Expression {
    abstract FloatType getValue();
}


class ParentheticalExpression : Expression {
    Expression _exp;

    this(Expression exp) {
        this._exp = exp;
    }

    override FloatType getValue() {
        return _exp.getValue();
    }

}

class UnaryExpression : Expression {
    FloatType delegate(Expression l) operator;
    Expression _exp;

    this(Expression exp) {
        this._exp = exp;
    }

    override FloatType getValue() {
        return operator(_exp);
    }
}

abstract class BinaryExpression : Expression {
    FloatType delegate(Expression l, Expression r) operator;

    Expression _left;
    Expression _right;

    this(Expression left, Expression right) {
        this._left  = left;
        this._right = right;
    }

    override FloatType getValue() {
        return operator(_left, _right);
    }
}

class NumberExpression : Expression {
    FloatType _value;

    this(FloatType v) {
        _value = v;
    }

    override FloatType getValue() {
        return _value;
    }
}

class NegExpression : UnaryExpression {
    this(Expression exp) {
        super(exp);
        operator = (Expression exp) => -(exp.getValue());
    }
}

class AddExpression : BinaryExpression {
    this(Expression left, Expression right) {
        super(left, right);
        operator = (Expression lhs, Expression rhs) => lhs.getValue() + rhs.getValue();
    }
}

class SubExpression : BinaryExpression {
    this(Expression left, Expression right) {
        super(left, right);
        operator = (Expression lhs, Expression rhs) => lhs.getValue() - rhs.getValue();
    }
}

class MulExpression : BinaryExpression {
    this(Expression left, Expression right) {
        super(left, right);
        operator = (Expression lhs, Expression rhs) => lhs.getValue() * rhs.getValue();
    }
}

class DivExpression : BinaryExpression {
    this(Expression left, Expression right) {
        super(left, right);
        operator = (Expression lhs, Expression rhs) => lhs.getValue() / rhs.getValue();
    }
}



