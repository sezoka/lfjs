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

