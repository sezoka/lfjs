const _else = true;
const nil = undefined;

function sub() {
    if (arguments.length < 1) {
        throw new Error("builtin function 'sub' requires at least 1 argument");
    }
    if (arguments.length === 1) {
        return -arguments[0];
    }
    var i = 0;
    var result = 0;
    while (i < arguments.length) {
        result -= arguments[i];
        i += 1;
    }
    return result + arguments[0] + arguments[0];
}

function sum() {
    if (arguments.length < 2) {
        throw new Error("builtin function 'sum' requires at least 2 arguments");
    }
    var result = 0;
    var i = 0;
    while (i < arguments.length) {
        result += arguments[i];
        i += 1;
    }
    return result;
}

function print() {
    console.log(...arguments);
}

const run451461461 = () => {console.log((137.000 + 349.000));
console.log((1000.000 - 334.000));
console.log((5.000 * 99.000));
console.log((10.000 / 5.000));
console.log((2.700 + 10.000));
console.log((21.000 + 35.000 + 12.000 + 7.000));
console.log((25.000 * 4.000 * 12.000));
console.log(((3.000 * 5.000) + (10.000 - 6.000)));
console.log(((3.000 * ((2.000 * 4.000) + (3.000 + 5.000))) + ((10.000 - 7.000) + 6.000)));
const size = 2.000;
print(size);
console.log((5.000 * size));
const pi = 3.142;
const radius = 10.000;
console.log((pi * (radius * radius)));
const circumference = (2.000 * pi * radius);
print(circumference);
};
const run451461465 = () => {const square = (x) => (x * x);
console.log(square(21.000));
console.log(square((2.000 + 5.000)));
console.log(square(square(3.000)));
const sum45of45squares = (x, y) => (square(x) + square(y));
console.log(sum45of45squares(3.000, 4.000));
const f = (a) => sum45of45squares((a + 1.000), (a * 2.000));
const ___tmp = f(5.000);
console.log(___tmp);
return ___tmp;};
const run451461466 = () => {const abs = (x) => ((x > 0.000)) ? x : ((x === 0.000)) ? 0.000 : ((x < 0.000)) ? -x : undefined;
console.log(abs(-123.000));
const abs45with45else = (x) => ((x >= 0.000)) ? x : _else ? -x : undefined;
const ___tmp = abs45with45else45123();
console.log(___tmp);
return ___tmp;};
const run451462 = () => {const factorial = (n) => (((n === 1.000)) ? 1.000 : (n * factorial((n - 1.000))));
console.log(factorial(10.000));
const fibb = (n) => ((n === 0.000)) ? 0.000 : ((n === 1.000)) ? 1.000 : _else ? (fibb((n - 1.000)) + fibb((n - 2.000))) : undefined;
const ___tmp = fibb(10.000);
console.log(___tmp);
return ___tmp;};
const run451463462 = () => {const square = (x) => (x * x);
const f = (x, y) => ((a, b) => ((x * square(a)) + (y * b) + (a * b)))((1.000 + (x * y)), (1.000 - y));
const ___tmp = f(5.000, 5.000);
console.log(___tmp);
return ___tmp;};
console.log(run451463462());
