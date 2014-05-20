/*
 * Frame.cpp
 *
 *  Created on: May 16, 2014
 *      Author: luigi
 */
#include "jnif.hpp"
#include "jnifex.hpp"

namespace jnif {

Type Frame::pop() {
	Error::check(stack.size() > 0, "Trying to pop in an empty stack.");

	Type t = stack.front();
	stack.pop_front();
	return t;
}

Type Frame::popOneWord() {
	Type t = pop();
	Error::check(t.isOneWord() || t.isTop(), "Type is not one word type: ", t,
			", frame: ", *this);
	return t;
}

Type Frame::popTwoWord() {
	Type t1 = pop();
	Type t2 = pop();

	Error::check(
			(t1.isOneWord() && t2.isOneWord())
					|| (t1.isTwoWord() && t2.isTop()),
			"Invalid types on top of the stack for pop2: ", t1, t2, *this);
	//Error::check(t2.isTop(), "Type is not Top type: ", t2, t1, *this);

	return t1;
}

Type Frame::popInt() {
	Type t = popOneWord();
	Error::assert(t.isInt(), "invalid int type on top of the stack: ", t);
	return t;
}

Type Frame::popFloat() {
	Type t = popOneWord();
	Error::assert(t.isFloat(), "invalid float type on top of the stack");
	return t;
}

Type Frame::popLong() {
	Type t = popTwoWord();
	Error::check(t.isLong(), "invalid long type on top of the stack");
	return t;
}

Type Frame::popDouble() {
	Type t = popTwoWord();
	Error::check(t.isDouble(), "Invalid double type on top of the stack: ", t);

	return t;
}

void Frame::popType(const Type& type) {
	if (type.isInt()) {
		popInt();
	} else if (type.isFloat()) {
		popFloat();
	} else if (type.isLong()) {
		popLong();
	} else if (type.isDouble()) {
		popDouble();
	} else if (type.isObject()) {
		popRef();
	} else {
		Error::raise("invalid pop type: ", type);
	}
}

void Frame::pushType(const Type& type) {
	if (type.isInt()) {
		pushInt();
	} else if (type.isFloat()) {
		pushFloat();
	} else if (type.isLong()) {
		pushLong();
	} else if (type.isDouble()) {
		pushDouble();
	} else if (type.isNull()) {
		pushNull();
	} else if (type.isObject()) {
		push(type);
	} else {
		Error::raise("invalid push type: ", type);
	}
}

void Frame::setVar(u4* lvindex, const Type& t) {
	Error::assert(t.isOneOrTwoWord(), "Setting var on non one-two word ");

	if (t.isOneWord()) {
		_setVar(*lvindex, t);
		(*lvindex)++;
	} else {
		_setVar(*lvindex, t);
		_setVar(*lvindex + 1, Type::topType());
		(*lvindex) += 2;
	}
}

void Frame::setRefVar(u4 lvindex, const Type& type) {
	Error::check(type.isObject() || type.isNull(), "Type must be object type: ",
			type);
	setVar(&lvindex, type);
}

void Frame::cleanTops() {
	for (u4 i = 0; i < lva.size(); i++) {
		Type t = lva[i];
		if (t.isTwoWord()) {
			Type top = lva[i + 1];
			Error::assert(top.isTop(), "Not top for two word: ", top);
			lva.erase(lva.begin() + i + 1);
		}
	}

	for (int i = lva.size() - 1; i >= 0; i--) {
		Type t = lva[i];
		if (t.isTop()) {

			lva.erase(lva.begin() + i);
		} else {
			return;
		}
	}
}

void Frame::_setVar(u4 lvindex, const Type& t) {
	Error::check(lvindex < 256, "");

	if (lvindex >= lva.size()) {
		lva.resize(lvindex + 1, Type::topType());
	}

	lva[lvindex] = t;
}

}