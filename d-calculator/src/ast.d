module ast;

import std.stdio;

class Expression {
    abstract double getValue();
}


class ParentheticalExpression : Expression {
    Expression _exp;

    this(Expression exp) {
        this._exp = exp;
    }

    override double getValue() {
        return _exp.getValue();
    }

}

class UnaryExpression : Expression {
    double delegate(Expression l) operator;
    Expression _exp;

    this(Expression exp) {
        this._exp = exp;
    }

    override double getValue() {
        return operator(_exp);
    }
}

abstract class BinaryExpression : Expression {
    double delegate(Expression l, Expression r) operator;

    Expression _left;
    Expression _right;

    this(Expression left, Expression right) {
        this._left  = left;
        this._right = right;
    }

    override double getValue() {
        return operator(_left, _right);
    }
}

class NumberExpression : Expression {
    double _value;

    this(double v) {
        _value = v;
    }

    override double getValue() {
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



